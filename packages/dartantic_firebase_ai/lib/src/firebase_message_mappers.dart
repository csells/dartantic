import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'firebase_ai_safety_options.dart';

final Logger _logger = Logger('dartantic.chat.mappers.firebase_ai');

const _uuid = Uuid();

/// Extension on [List<ChatMessage>] to convert messages to Firebase AI content.
extension MessageListMapper on List<ChatMessage> {
  /// Converts this list of [ChatMessage]s to a list of [fai.Content]s.
  ///
  /// System messages are filtered out (handled separately via
  /// `systemInstruction`). Consecutive tool result messages are grouped into a
  /// single [fai.Content.functionResponses] as required by Firebase AI's API.
  List<fai.Content> toContentList() {
    final nonSystemMessages = where(
      (message) => message.role != ChatMessageRole.system,
    ).toList();
    final result = <fai.Content>[];

    for (var i = 0; i < nonSystemMessages.length; i++) {
      final message = nonSystemMessages[i];

      final hasToolResults = message.parts.whereType<ToolPart>().any(
        (p) => p.result != null,
      );

      if (hasToolResults) {
        final toolMessages = [message];
        var j = i + 1;
        while (j < nonSystemMessages.length) {
          final nextMsg = nonSystemMessages[j];
          final nextHasToolResults = nextMsg.parts.whereType<ToolPart>().any(
            (p) => p.result != null,
          );
          if (nextHasToolResults) {
            toolMessages.add(nextMsg);
            j++;
          } else {
            break;
          }
        }

        result.add(_mapToolResultMessages(toolMessages));
        i = j - 1;
      } else {
        result.add(_mapMessage(message));
      }
    }

    return result;
  }

  fai.Content _mapMessage(ChatMessage message) {
    switch (message.role) {
      case ChatMessageRole.system:
        throw AssertionError('System messages should be filtered out');
      case ChatMessageRole.user:
        return _mapUserMessage(message);
      case ChatMessageRole.model:
        return _mapModelMessage(message);
    }
  }

  fai.Content _mapUserMessage(ChatMessage message) {
    final contentParts = <fai.Part>[];

    for (final part in message.parts) {
      switch (part) {
        case TextPart(:final text):
          contentParts.add(fai.TextPart(text));
        case DataPart(:final bytes, :final mimeType):
          contentParts.add(fai.InlineDataPart(mimeType, bytes));
        case LinkPart(:final url, :final mimeType):
          contentParts.add(
            fai.FileData(
              mimeType ?? 'application/octet-stream',
              url.toString(),
            ),
          );
        case ToolPart():
          break;
        default:
          _logger.warning(
            'Skipping unsupported part type: ${part.runtimeType}',
          );
      }
    }

    return fai.Content.multi(contentParts);
  }

  fai.Content _mapModelMessage(ChatMessage message) {
    final contentParts = <fai.Part>[];

    for (final part in message.parts) {
      switch (part) {
        case TextPart(:final text):
          if (text.isNotEmpty) {
            contentParts.add(fai.TextPart(text));
          }
        case ThinkingPart(:final text):
          if (text.isNotEmpty) {
            contentParts.add(fai.TextPart(text, isThought: true));
          }
        case ToolPart() when part.kind == ToolPartKind.call:
          contentParts.add(
            fai.FunctionCall(
              part.toolName,
              part.arguments ?? {},
              id: part.callId.isNotEmpty ? part.callId : null,
            ),
          );
        default:
          break;
      }
    }

    return fai.Content.model(contentParts);
  }

  /// Maps multiple tool result messages to a single
  /// [fai.Content.functionResponses].
  ///
  /// Firebase AI requires all function responses to be grouped together.
  fai.Content _mapToolResultMessages(List<ChatMessage> messages) {
    final functionResponses = <fai.FunctionResponse>[];

    for (final message in messages) {
      for (final part in message.parts) {
        if (part is ToolPart && part.kind == ToolPartKind.result) {
          final result = part.result;
          final response = switch (result) {
            final Map<String, Object?> map => map,
            _ => <String, Object?>{'result': result},
          };

          functionResponses.add(
            fai.FunctionResponse(
              part.toolName,
              response,
              id: part.callId.isNotEmpty ? part.callId : null,
            ),
          );
        }
      }
    }

    return fai.Content.functionResponses(functionResponses);
  }
}

/// Extension on [fai.GenerateContentResponse] to convert to [ChatResult].
extension GenerateContentResponseMapper on fai.GenerateContentResponse {
  /// Converts this [fai.GenerateContentResponse] to a streaming [ChatResult].
  ///
  /// Each streaming chunk sets `messages: const []`. The caller is responsible
  /// for accumulating parts and producing the final consolidated message.
  ChatResult<ChatMessage> toChatResult(String model) {
    if (candidates.isEmpty) {
      final blockReason = promptFeedback?.blockReason?.name;
      final blockMessage = promptFeedback?.blockReasonMessage;
      throw StateError(
        'Firebase AI returned no candidates. '
        '${blockReason != null ? 'Block reason: $blockReason. ' : ''}'
        '${blockMessage != null ? 'Message: $blockMessage' : ''}',
      );
    }

    final candidate = candidates.first;
    final parts = <Part>[];
    String? thinkingDelta;

    for (final part in candidate.content.parts) {
      switch (part) {
        case fai.TextPart(:final text):
          if (text.isEmpty) break;
          if (part.isThought ?? false) {
            parts.add(ThinkingPart(text));
            thinkingDelta = text;
          } else {
            parts.add(TextPart(text));
          }
        case fai.InlineDataPart(:final mimeType, :final bytes):
          parts.add(DataPart(bytes, mimeType: mimeType));
        case fai.FunctionCall(:final name, :final args, :final id):
          final callId = (id != null && id.isNotEmpty) ? id : _uuid.v4();
          parts.add(
            ToolPart.call(callId: callId, toolName: name, arguments: args),
          );
        case fai.ExecutableCodePart(:final language, :final code):
          parts.add(TextPart('```$language\n$code\n```'));
        case fai.CodeExecutionResultPart(:final output):
          if (output.isNotEmpty) {
            parts.add(TextPart('Code execution output:\n$output'));
          }
        case fai.FunctionResponse():
        case fai.FileData():
        case fai.UnknownPart():
          break;
      }
    }

    final message = ChatMessage(role: ChatMessageRole.model, parts: parts);

    return ChatResult<ChatMessage>(
      output: message,
      messages: const [],
      thinking: thinkingDelta,
      finishReason: mapFinishReason(candidate.finishReason),
      metadata: <String, Object?>{
        'model': model,
        'block_reason': promptFeedback?.blockReason?.name,
        'block_reason_message': promptFeedback?.blockReasonMessage,
        'safety_ratings': candidate.safetyRatings
            ?.map(
              (r) => <String, Object?>{
                'category': r.category.name,
                'probability': r.probability.name,
              },
            )
            .toList(growable: false),
        'citation_metadata': candidate.citationMetadata?.toString(),
        'finish_message': candidate.finishMessage,
      },
      usage: LanguageModelUsage(
        promptTokens: usageMetadata?.promptTokenCount,
        responseTokens: usageMetadata?.candidatesTokenCount,
        totalTokens: usageMetadata?.totalTokenCount,
      ),
    );
  }
}

/// Maps a Firebase AI [fai.FinishReason] to a Dartantic [FinishReason].
FinishReason mapFinishReason(fai.FinishReason? reason) => switch (reason) {
  fai.FinishReason.stop => FinishReason.stop,
  fai.FinishReason.maxTokens => FinishReason.length,
  fai.FinishReason.safety => FinishReason.contentFilter,
  fai.FinishReason.recitation => FinishReason.recitation,
  fai.FinishReason.malformedFunctionCall => FinishReason.unspecified,
  fai.FinishReason.other => FinishReason.unspecified,
  fai.FinishReason.unknown => FinishReason.unspecified,
  null => FinishReason.unspecified,
};

/// Extension on [List<FirebaseAISafetySetting>] to convert to Firebase SDK
/// safety settings.
extension SafetySettingsMapper on List<FirebaseAISafetySetting> {
  /// Converts this list of [FirebaseAISafetySetting]s to a list of
  /// [fai.SafetySetting]s.
  List<fai.SafetySetting> toSafetySettings() => map(
    (setting) => fai.SafetySetting(
      switch (setting.category) {
        FirebaseAISafetySettingCategory.harassment =>
          fai.HarmCategory.harassment,
        FirebaseAISafetySettingCategory.hateSpeech =>
          fai.HarmCategory.hateSpeech,
        FirebaseAISafetySettingCategory.sexuallyExplicit =>
          fai.HarmCategory.sexuallyExplicit,
        FirebaseAISafetySettingCategory.dangerousContent =>
          fai.HarmCategory.dangerousContent,
      },
      switch (setting.threshold) {
        FirebaseAISafetySettingThreshold.blockLowAndAbove =>
          fai.HarmBlockThreshold.low,
        FirebaseAISafetySettingThreshold.blockMediumAndAbove =>
          fai.HarmBlockThreshold.medium,
        FirebaseAISafetySettingThreshold.blockOnlyHigh =>
          fai.HarmBlockThreshold.high,
        FirebaseAISafetySettingThreshold.blockNone =>
          fai.HarmBlockThreshold.none,
      },
      null,
    ),
  ).toList(growable: false);
}

/// Extension on [List<Tool>?] to convert to Firebase SDK tool list.
extension ChatToolListMapper on List<Tool>? {
  /// Converts this list of [Tool]s to a list of [fai.Tool]s, optionally
  /// enabling code execution.
  List<fai.Tool>? toToolList({required bool enableCodeExecution}) {
    final hasTools = this != null && this!.isNotEmpty;
    if (!hasTools && !enableCodeExecution) {
      return null;
    }
    final functionDeclarations = hasTools
        ? this!.map(_toolToFunctionDeclaration).toList(growable: false)
        : null;
    final codeExecution = enableCodeExecution
        ? const fai.CodeExecution()
        : null;
    if ((functionDeclarations == null || functionDeclarations.isEmpty) &&
        codeExecution == null) {
      return null;
    }
    return <fai.Tool>[
      fai.Tool.functionDeclarations(functionDeclarations ?? []),
    ];
  }

  static fai.FunctionDeclaration _toolToFunctionDeclaration(Tool tool) {
    final schema = Map<String, dynamic>.from(tool.inputSchema.value);
    final rawProperties = schema['properties'] as Map<String, dynamic>?;
    final requiredList =
        (schema['required'] as List?)?.cast<String>() ?? const <String>[];

    final parameters = <String, fai.Schema>{};
    if (rawProperties != null) {
      for (final entry in rawProperties.entries) {
        parameters[entry.key] = Map<String, dynamic>.from(
          entry.value as Map,
        ).toSchema();
      }
    }

    final allPropertyNames = parameters.keys.toSet();
    final optionalParameters = allPropertyNames
        .difference(requiredList.toSet())
        .toList();

    return fai.FunctionDeclaration(
      tool.name,
      tool.description,
      parameters: parameters,
      optionalParameters: optionalParameters,
    );
  }
}

/// Extension on [Map<String, dynamic>] to convert to Firebase SDK schema.
extension SchemaMapper on Map<String, dynamic> {
  /// Converts this map to a [fai.Schema].
  fai.Schema toSchema() {
    final jsonSchema = this;
    final type = jsonSchema['type'] as String;
    final description = jsonSchema['description'] as String?;
    final nullable = jsonSchema['nullable'] as bool?;
    final enumValues = (jsonSchema['enum'] as List?)?.cast<String>();
    final format = jsonSchema['format'] as String?;
    final items = jsonSchema['items'] != null
        ? Map<String, dynamic>.from(jsonSchema['items'] as Map)
        : null;
    final properties = jsonSchema['properties'] != null
        ? Map<String, dynamic>.from(jsonSchema['properties'] as Map)
        : null;
    final requiredProperties = (jsonSchema['required'] as List?)
        ?.cast<String>();

    switch (type) {
      case 'string':
        if (enumValues != null) {
          return fai.Schema.enumString(
            enumValues: enumValues,
            description: description,
            nullable: nullable,
          );
        } else {
          return fai.Schema.string(
            description: description,
            nullable: nullable,
          );
        }
      case 'number':
        return fai.Schema.number(
          description: description,
          nullable: nullable,
          format: format,
        );
      case 'integer':
        return fai.Schema.integer(
          description: description,
          nullable: nullable,
          format: format,
        );
      case 'boolean':
        return fai.Schema.boolean(description: description, nullable: nullable);
      case 'array':
        if (items != null) {
          return fai.Schema.array(
            items: items.toSchema(),
            description: description,
            nullable: nullable,
          );
        }
        throw ArgumentError('Array schema must have "items" property');
      case 'object':
        if (properties != null) {
          final propertiesSchema = properties.map(
            (key, value) => MapEntry(
              key,
              Map<String, dynamic>.from(value as Map).toSchema(),
            ),
          );
          final allKeys = propertiesSchema.keys.toSet();
          final requiredSet = requiredProperties?.toSet() ?? const <String>{};
          final optionalProperties = allKeys.difference(requiredSet).toList();
          return fai.Schema.object(
            properties: propertiesSchema,
            optionalProperties: optionalProperties.isEmpty
                ? null
                : optionalProperties,
            description: description,
            nullable: nullable,
          );
        }
        throw ArgumentError('Object schema must have "properties" property');
      default:
        throw ArgumentError('Invalid schema type: $type');
    }
  }
}
