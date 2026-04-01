import 'dart:typed_data';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:googleai_dart/googleai_dart.dart' as ga;
import 'package:logging/logging.dart';

import '../../shared/google_thinking_metadata.dart';
import '../helpers/message_part_helpers.dart';
import '../helpers/tool_id_helpers.dart';
import 'google_chat.dart'
    show
        ChatGoogleGenerativeAISafetySetting,
        ChatGoogleGenerativeAISafetySettingCategory,
        ChatGoogleGenerativeAISafetySettingThreshold;

/// Logger for Google message mapping operations.
final Logger _logger = Logger('dartantic.chat.mappers.google');

ga.Schema? _parametersSchemaFromTool(Tool tool) {
  try {
    return ga.Schema.fromJson(
      Map<String, dynamic>.from(tool.inputSchema.value),
    );
  } on Object catch (e, st) {
    _logger.warning(
      'Could not convert tool "${tool.name}" input schema to Google Schema: $e',
      e,
      st,
    );
    return null;
  }
}

/// Maps Dartantic Parts to Google [ga.Part]s (public helper for reuse).
///
/// The [messageMetadata] parameter should contain thought signatures when
/// available, stored via [GoogleThinkingMetadata].
List<ga.Part> mapPartsToGoogle(
  Iterable<Part> parts, {
  bool includeToolCalls = false,
  bool includeToolResults = false,
  Map<String, dynamic> messageMetadata = const {},
}) {
  final mappedParts = <ga.Part>[];
  final thoughtSignatures = GoogleThinkingMetadata.getSignatures(
    messageMetadata,
  );

  for (final part in parts) {
    switch (part) {
      case TextPart(:final text):
        if (text.isNotEmpty) mappedParts.add(ga.TextPart(text));
      case DataPart(:final bytes, :final mimeType):
        mappedParts.add(ga.InlineDataPart(ga.Blob.fromBytes(mimeType, bytes)));
      case LinkPart(:final url, :final mimeType):
        mappedParts.add(
          ga.FileDataPart(
            ga.FileData(
              fileUri: url.toString(),
              mimeType: mimeType ?? 'application/octet-stream',
            ),
          ),
        );
      case ToolPart(:final kind):
        if (includeToolCalls && kind == ToolPartKind.call) {
          mappedParts.add(_mapToolCallPart(part, thoughtSignatures));
        } else if (includeToolResults && kind == ToolPartKind.result) {
          mappedParts.add(_mapToolResultPart(part));
        }
      case ThinkingPart():
        // Google maintains reasoning context via thought signatures, not
        // thinking text - signatures alone preserve continuity across turns
        break;
    }
  }

  return mappedParts;
}

ga.Part _mapToolCallPart(
  ToolPart part,
  Map<String, dynamic> thoughtSignatures,
) {
  final arguments = part.arguments ?? const <String, dynamic>{};
  final callId = part.callId.isNotEmpty
      ? part.callId
      : ToolIdHelpers.generateToolCallId(
          toolName: part.toolName,
          providerHint: 'google',
          arguments: arguments,
        );

  return ga.FunctionCallPart(
    ga.FunctionCall(id: callId, name: part.toolName, args: arguments),
    // Attach signature to preserve reasoning context across tool calls
    thoughtSignature: GoogleThinkingMetadata.getSignatureBytes(
      thoughtSignatures,
      callId,
    ),
  );
}

ga.Part _mapToolResultPart(ToolPart part) {
  final responseMap = ToolResultHelpers.ensureMap(part.result);
  _logger.fine('Creating function response for tool: ${part.toolName}');

  return ga.FunctionResponsePart(
    ga.FunctionResponse(
      id: part.callId.isNotEmpty ? part.callId : null,
      name: part.toolName,
      response: responseMap,
    ),
  );
}

/// Extension on [List<ChatMessage>] to convert messages to Gemini content.
extension MessageListMapper on List<ChatMessage> {
  /// Converts this list of [ChatMessage]s to a list of [ga.Content]s.
  ///
  /// Groups consecutive tool result messages into a single `Content` so we can
  /// attach all function response parts in one payload.
  ///
  /// ThinkingPart is skipped since Google uses thought signatures (not text)
  /// to maintain reasoning continuity across conversation turns.
  List<ga.Content> toContentList() {
    final nonSystemMessages = where(
      (message) => message.role != ChatMessageRole.system,
    ).toList();
    _logger.fine(
      'Converting ${nonSystemMessages.length} non-system messages to Google '
      'format',
    );

    final result = <ga.Content>[];

    for (var i = 0; i < nonSystemMessages.length; i++) {
      final message = nonSystemMessages[i];
      final hasToolResults = message.parts.whereType<ToolPart>().any(
        (p) => p.kind == ToolPartKind.result,
      );

      if (hasToolResults) {
        final toolMessages = <ChatMessage>[message];
        var j = i + 1;
        while (j < nonSystemMessages.length) {
          final next = nonSystemMessages[j];
          final nextHasToolResults = next.parts.whereType<ToolPart>().any(
            (p) => p.kind == ToolPartKind.result,
          );
          if (!nextHasToolResults) break;
          toolMessages.add(next);
          j++;
        }
        result.add(_mapToolResultMessages(toolMessages));
        i = j - 1;
      } else {
        result.add(_mapMessage(message));
      }
    }

    return result;
  }

  ga.Content _mapMessage(ChatMessage message) {
    switch (message.role) {
      case ChatMessageRole.system:
        throw AssertionError('System messages should already be filtered out');
      case ChatMessageRole.user:
        return _mapUserMessage(message);
      case ChatMessageRole.model:
        return _mapModelMessage(message);
    }
  }

  ga.Content _mapUserMessage(ChatMessage message) {
    _logger.fine('Mapping user message with ${message.parts.length} parts');
    return ga.Content(
      parts: _mapParts(
        message.parts,
        includeToolCalls: false,
        includeToolResults: true,
        messageMetadata: message.metadata,
      ),
      role: 'user',
    );
  }

  ga.Content _mapModelMessage(ChatMessage message) {
    _logger.fine('Mapping model message with ${message.parts.length} parts');
    return ga.Content(
      parts: _mapParts(
        message.parts,
        includeToolCalls: true,
        includeToolResults: false,
        messageMetadata: message.metadata,
      ),
      role: 'model',
    );
  }

  ga.Content _mapToolResultMessages(List<ChatMessage> messages) {
    final parts = <ga.Part>[];
    _logger.fine(
      'Creating function responses for ${messages.length} tool result '
      'messages',
    );

    for (final message in messages) {
      parts.addAll(
        _mapParts(
          message.parts,
          includeToolCalls: false,
          includeToolResults: true,
          messageMetadata: message.metadata,
        ),
      );
    }

    return ga.Content(parts: parts, role: 'user');
  }

  List<ga.Part> _mapParts(
    Iterable<Part> parts, {
    required bool includeToolCalls,
    required bool includeToolResults,
    Map<String, dynamic> messageMetadata = const {},
  }) => mapPartsToGoogle(
    parts,
    includeToolCalls: includeToolCalls,
    includeToolResults: includeToolResults,
    messageMetadata: messageMetadata,
  );
}

/// Extension on [ga.GenerateContentResponse] to convert to [ChatResult].
extension GenerateContentResponseMapper on ga.GenerateContentResponse {
  /// Converts this response to a [ChatResult].
  ChatResult<ChatMessage> toChatResult(String model) {
    final candidateList = candidates;
    if (candidateList == null || candidateList.isEmpty) {
      throw StateError('Google response did not contain any candidates.');
    }

    final candidate = candidateList.first;
    final parts = <Part>[];
    final executableCodeParts = <ga.ExecutableCode>[];
    final executionResults = <ga.CodeExecutionResult>[];
    final thoughtSignatures = <String, dynamic>{};

    final contentParts = candidate.content?.parts ?? const <ga.Part>[];
    _logger.fine(
      'Processing ${contentParts.length} parts from Google response',
    );

    for (final part in contentParts) {
      switch (part) {
        case ga.TextPart(:final text, :final thought):
          if (text.isNotEmpty) {
            if (thought ?? false) {
              parts.add(ThinkingPart(text));
              _logger.fine(
                'Added thinking text as ThinkingPart: ${text.length} chars',
              );
            } else {
              parts.add(TextPart(text));
            }
          }
        case ga.InlineDataPart(:final inlineData):
          parts.add(
            DataPart(
              Uint8List.fromList(inlineData.toBytes()),
              mimeType: inlineData.mimeType,
            ),
          );
        case ga.FileDataPart(:final fileData):
          parts.add(
            LinkPart(Uri.parse(fileData.fileUri), mimeType: fileData.mimeType),
          );
        case ga.FunctionCallPart(:final functionCall, :final thoughtSignature):
          final args = functionCall.args ?? const <String, dynamic>{};
          final callId =
              (functionCall.id != null && functionCall.id!.isNotEmpty)
              ? functionCall.id!
              : ToolIdHelpers.generateToolCallId(
                  toolName: functionCall.name,
                  providerHint: 'google',
                  arguments: args,
                );
          parts.add(
            ToolPart.call(
              callId: callId,
              toolName: functionCall.name,
              arguments: args,
            ),
          );
          if (thoughtSignature != null && thoughtSignature.isNotEmpty) {
            GoogleThinkingMetadata.setSignatureBytes(
              thoughtSignatures,
              callId,
              Uint8List.fromList(thoughtSignature),
            );
          }
        case ga.FunctionResponsePart(:final functionResponse):
          final responseMap = Map<String, dynamic>.from(
            functionResponse.response,
          );
          final responseId =
              (functionResponse.id != null && functionResponse.id!.isNotEmpty)
              ? functionResponse.id!
              : ToolIdHelpers.generateToolCallId(
                  toolName: functionResponse.name,
                  providerHint: 'google',
                  arguments: responseMap,
                );
          parts.add(
            ToolPart.result(
              callId: responseId,
              toolName: functionResponse.name,
              result: responseMap,
            ),
          );
        case ga.ExecutableCodePart(:final executableCode):
          executableCodeParts.add(executableCode);
        case ga.CodeExecutionResultPart(:final codeExecutionResult):
          executionResults.add(codeExecutionResult);
        case ga.ThoughtPart():
        case ga.ThoughtSignaturePart():
        case ga.ToolCallPart():
        case ga.ToolResponsePart():
        case ga.VideoMetadataPart():
        case ga.PartMetadataPart():
          break;
      }
    }

    // Build message metadata with thought signatures for multi-turn continuity
    final messageMetadata = GoogleThinkingMetadata.buildMetadata(
      signatures: thoughtSignatures,
    );

    final message = ChatMessage(
      role: ChatMessageRole.model,
      parts: parts,
      metadata: messageMetadata,
    );

    final metadata = <String, dynamic>{
      'model': model,
      'model_version': ?modelVersion,
    };

    final blockReason = promptFeedback?.blockReason;
    if (blockReason != null) {
      metadata['block_reason'] = ga.finishReasonToString(blockReason);
    }

    final safetyRatings = candidate.safetyRatings;
    if (safetyRatings != null && safetyRatings.isNotEmpty) {
      metadata['safety_ratings'] = safetyRatings
          .map(
            (rating) => {
              'category': ga.harmCategoryToString(rating.category),
              'probability': ga.harmProbabilityToString(rating.probability),
            },
          )
          .toList(growable: false);
    }

    final citationSources = candidate.citationMetadata?.citationSources;
    if (citationSources != null && citationSources.isNotEmpty) {
      metadata['citation_metadata'] = citationSources
          .map(
            (s) => {
              'start_index': s.startIndex,
              'end_index': s.endIndex,
              'uri': s.uri,
              'license': s.license,
            },
          )
          .toList(growable: false);
    }

    if (executableCodeParts.isNotEmpty) {
      metadata['executable_code'] = executableCodeParts
          .map((code) => code.toJson())
          .toList(growable: false);
    }
    if (executionResults.isNotEmpty) {
      metadata['code_execution_result'] = executionResults
          .map((result) => result.toJson())
          .toList(growable: false);
    }

    metadata.removeWhere(
      (_, value) => value == null || (value is List && value.isEmpty),
    );

    final usage = usageMetadata;
    return ChatResult<ChatMessage>(
      output: message,
      messages: [message],
      finishReason: _mapFinishReason(candidate.finishReason),
      metadata: metadata,
      usage: usage != null
          ? LanguageModelUsage(
              promptTokens: usage.promptTokenCount,
              responseTokens: usage.candidatesTokenCount,
              totalTokens: usage.totalTokenCount,
            )
          : null,
    );
  }

  FinishReason _mapFinishReason(ga.FinishReason? reason) => switch (reason) {
    ga.FinishReason.stop => FinishReason.stop,
    ga.FinishReason.maxTokens => FinishReason.length,
    ga.FinishReason.safety ||
    ga.FinishReason.blocklist ||
    ga.FinishReason.prohibitedContent ||
    ga.FinishReason.imageSafety ||
    ga.FinishReason.imageProhibitedContent ||
    ga.FinishReason.spii => FinishReason.contentFilter,
    ga.FinishReason.recitation ||
    ga.FinishReason.imageRecitation => FinishReason.recitation,
    ga.FinishReason.malformedFunctionCall => FinishReason.unspecified,
    null => FinishReason.unspecified,
    _ => FinishReason.unspecified,
  };
}

/// Extension on [List<ChatGoogleGenerativeAISafetySetting>] to convert to
/// Gemini safety settings.
extension SafetySettingsMapper on List<ChatGoogleGenerativeAISafetySetting> {
  /// Converts this list of safety settings to [ga.SafetySetting]s.
  List<ga.SafetySetting> toSafetySettings() {
    _logger.fine('Converting $length safety settings to Google format');
    return map(
      (setting) => ga.SafetySetting(
        category: switch (setting.category) {
          ChatGoogleGenerativeAISafetySettingCategory.unspecified =>
            ga.HarmCategory.unspecified,
          ChatGoogleGenerativeAISafetySettingCategory.harassment =>
            ga.HarmCategory.harassment,
          ChatGoogleGenerativeAISafetySettingCategory.hateSpeech =>
            ga.HarmCategory.hateSpeech,
          ChatGoogleGenerativeAISafetySettingCategory.sexuallyExplicit =>
            ga.HarmCategory.sexuallyExplicit,
          ChatGoogleGenerativeAISafetySettingCategory.dangerousContent =>
            ga.HarmCategory.dangerousContent,
        },
        threshold: switch (setting.threshold) {
          ChatGoogleGenerativeAISafetySettingThreshold.unspecified =>
            ga.HarmBlockThreshold.unspecified,
          ChatGoogleGenerativeAISafetySettingThreshold.blockLowAndAbove =>
            ga.HarmBlockThreshold.blockLowAndAbove,
          ChatGoogleGenerativeAISafetySettingThreshold.blockMediumAndAbove =>
            ga.HarmBlockThreshold.blockMediumAndAbove,
          ChatGoogleGenerativeAISafetySettingThreshold.blockOnlyHigh =>
            ga.HarmBlockThreshold.blockOnlyHigh,
          ChatGoogleGenerativeAISafetySettingThreshold.blockNone =>
            ga.HarmBlockThreshold.blockNone,
        },
      ),
    ).toList(growable: false);
  }
}

/// Extension on [List<Tool>?] to convert to Gemini tools.
extension ChatToolListMapper on List<Tool>? {
  /// Converts this list of [Tool]s to a list of [ga.Tool]s, optionally enabling
  /// code execution and Google Search.
  List<ga.Tool>? toToolList({
    required bool enableCodeExecution,
    required bool enableGoogleSearch,
    required bool enableUrlContext,
  }) {
    final hasTools = this != null && this!.isNotEmpty;
    _logger.fine(
      'Converting tools to Google format: hasTools=$hasTools, '
      'enableCodeExecution=$enableCodeExecution, '
      'enableGoogleSearch=$enableGoogleSearch, '
      'enableUrlContext=$enableUrlContext, '
      'toolCount=${this?.length ?? 0}',
    );

    final functionDeclarations = hasTools
        ? this!
              .map(
                (tool) => ga.FunctionDeclaration(
                  name: tool.name,
                  description: tool.description,
                  parameters: _parametersSchemaFromTool(tool),
                ),
              )
              .toList(growable: false)
        : null;

    final codeExecution = enableCodeExecution ? const ga.CodeExecution() : null;
    final googleSearch = enableGoogleSearch ? const ga.GoogleSearch() : null;
    final urlContext = enableUrlContext ? const ga.UrlContext() : null;

    if ((functionDeclarations == null || functionDeclarations.isEmpty) &&
        codeExecution == null &&
        googleSearch == null &&
        urlContext == null) {
      return null;
    }

    return [
      ga.Tool(
        functionDeclarations: functionDeclarations ?? const [],
        codeExecution: codeExecution,
        googleSearch: googleSearch,
        urlContext: urlContext,
      ),
    ];
  }
}
