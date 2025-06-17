import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:json_schema/json_schema.dart';
import 'package:uuid/uuid.dart';

import '../../agent/agent_response.dart';
import '../../agent/embedding_type.dart';
import '../../agent/tool.dart';
import '../../json_schema_extension.dart';
import '../../utils.dart';
import '../interface/model.dart';
import '../message.dart';

/// Implementation of [Model] that uses Google's Gemini API.
///
/// This model handles interaction with Gemini models, supporting both
/// standard text responses and structured JSON schema responses.
class GeminiModel extends Model {
  /// Creates a new [GeminiModel] with the given parameters.
  ///
  /// The [modelName] is the name of the Gemini model to use.
  /// The [embeddingModelName] is the name of the Gemini embedding model to use.
  /// The [apiKey] is the API key to use for authentication.
  /// The [outputSchema] is an optional JSON schema for structured outputs.
  /// The [systemPrompt] is an optional system prompt to use.
  GeminiModel({
    required String modelName,
    required String embeddingModelName,
    required String apiKey,
    JsonSchema? outputSchema,
    String? systemPrompt,
    Iterable<Tool>? tools,
    double? temperature,
  }) : _modelName = modelName,
       _embeddingModelName = embeddingModelName,
       _apiKey = apiKey,
       _tools = tools,
       _model = gemini.GenerativeModel(
         apiKey: apiKey,
         model: modelName,
         generationConfig:
             outputSchema == null
                 ? null
                 : gemini.GenerationConfig(
                   responseMimeType: 'application/json',
                   responseSchema: _geminiSchemaFrom(outputSchema),
                   temperature: temperature,
                 ),
         systemInstruction:
             systemPrompt != null ? gemini.Content.text(systemPrompt) : null,
         tools: tools != null ? _toolsFrom(tools) : null,
       );

  @override
  String get displayName => 'google:$_modelName;$_embeddingModelName';

  late final gemini.GenerativeModel _model;
  final String _modelName;
  final String _embeddingModelName;
  final String _apiKey;
  final Iterable<Tool>? _tools;

  @override
  Stream<AgentResponse> runStream({
    required String prompt,
    required List<Message> messages,
  }) async* {
    log.fine(
      '[GeminiModel] Starting stream with ${messages.length} messages, '
      'prompt length: ${prompt.length}',
    );

    final history = _geminiHistoryFrom(messages);
    final chat = _model.startChat(history: history.isEmpty ? null : history);
    final stream = chat.sendMessageStream(gemini.Content.text(prompt));

    final chunks = <String>[];
    final functionCalls = <gemini.FunctionCall>[];

    await for (final chunk in stream) {
      final text = chunk.text ?? '';
      if (text.isNotEmpty) {
        chunks.add(text);
        log.finest('[GeminiModel] Yielding content: $text');
        yield AgentResponse(output: text, messages: []);
      }

      // Collect function calls
      if (chunk.functionCalls.isNotEmpty) {
        final callsDesc = chunk.functionCalls
            .map((fc) => '${fc.name}(${fc.args})')
            .join(', ');
        log.finest('[GeminiModel] Function calls received: $callsDesc');
      }
      functionCalls.addAll(chunk.functionCalls);
    }

    // output a blank response to include the final history, as the history
    // won't be updated until after the stream is done
    yield AgentResponse(output: '', messages: _messagesFrom(chat.history));

    // If there are function calls, handle them
    if (functionCalls.isNotEmpty) {
      log.finest(
        '[GeminiModel] Processing ${functionCalls.length} function calls',
      );
      final responses = <gemini.FunctionResponse>[];

      for (final functionCall in functionCalls) {
        log.fine(
          '[GeminiModel] Calling tool: '
          '${functionCall.name}(${functionCall.args})',
        );

        try {
          final result = await _callTool(functionCall.name, functionCall.args);
          responses.add(gemini.FunctionResponse(functionCall.name, result));
          log.fine(
            '[GeminiModel] Tool response: ${functionCall.name} = $result',
          );
        } on Exception catch (ex) {
          log.severe('[GeminiModel] Error calling tool: $ex');
          responses.add(
            gemini.FunctionResponse(functionCall.name, {
              'error': ex.toString(),
            }),
          );
        }
      }

      // Send function responses back to the model
      log.fine('[GeminiModel] Sending function responses back to model');
      final result = await chat.sendMessage(
        gemini.Content.functionResponses(responses),
      );

      if (result.text != null && result.text!.isNotEmpty) {
        log.fine('[GeminiModel] Final response after tools: ${result.text!}');
        yield AgentResponse(
          output: result.text!,
          messages: _messagesFrom(chat.history),
        );
      }
    }
  }

  @override
  Future<Float64List> createEmbedding(
    String text, {
    EmbeddingType type = EmbeddingType.document,
  }) async {
    log.fine(
      '[GeminiModel] Creating embedding for text (length: ${text.length}, '
      'type: $type)',
    );

    final taskType = switch (type) {
      EmbeddingType.document => gemini.TaskType.retrievalDocument,
      EmbeddingType.query => gemini.TaskType.retrievalQuery,
    };

    // Create a model instance specifically for embeddings
    final embeddingModel = gemini.GenerativeModel(
      apiKey: _apiKey,
      model: _embeddingModelName,
    );

    final response = await embeddingModel.embedContent(
      gemini.Content.text(text),
      taskType: taskType,
    );

    final embedding = Float64List.fromList(response.embedding.values);
    log.fine(
      '[GeminiModel] Created embedding with ${embedding.length} dimensions',
    );

    return embedding;
  }

  Future<Map<String, dynamic>?> _callTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    Map<String, dynamic> result;
    try {
      // if the tool isn't found, return an error
      final tool = _tools?.where((t) => t.name == name).singleOrNull;
      result =
          tool == null
              ? {'error': 'Tool $name not found'}
              : await tool.onCall.call(args);
    } on Exception catch (ex) {
      // if the tool call throws an error, return the exception message
      result = {'error': ex.toString()};
    }

    log.fine('Tool: $name($args)= $result');
    return result;
  }

  static gemini.Schema _geminiSchemaFrom(JsonSchema jsonSchema) {
    final map = jsonSchema.toMap();
    return _schemaObjectFrom(map, map);
  }

  static gemini.Schema _schemaObjectFrom(
    Map<String, dynamic> jsonSchema,
    Map<String, dynamic> rootSchema,
  ) {
    // Handle $ref references
    if (jsonSchema.containsKey(r'$ref')) {
      final ref = jsonSchema[r'$ref'] as String;
      if (ref.startsWith(r'#/$defs/')) {
        final defName = ref.substring(8); // Remove '#/$defs/'
        final defs = rootSchema[r'$defs'] as Map<String, dynamic>?;
        if (defs != null && defs.containsKey(defName)) {
          return _schemaObjectFrom(defs[defName], rootSchema);
        }
      }
    }

    final type = _getSchemaType(jsonSchema['type']);

    return switch (type) {
      gemini.SchemaType.object => gemini.Schema.object(
        properties: _extractProperties(
          jsonSchema['properties'] ?? {},
          rootSchema,
        ),
        requiredProperties: _extractRequiredProperties(jsonSchema['required']),
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
      ),
      gemini.SchemaType.array => gemini.Schema.array(
        items: _schemaObjectFrom(jsonSchema['items'] ?? {}, rootSchema),
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
      ),
      gemini.SchemaType.string when jsonSchema['enum'] != null => gemini
          .Schema.enumString(
        enumValues: List<String>.from(jsonSchema['enum']),
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
      ),
      gemini.SchemaType.string => gemini.Schema.string(
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
      ),
      gemini.SchemaType.number => gemini.Schema.number(
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
        format: jsonSchema['format'],
      ),
      gemini.SchemaType.integer => gemini.Schema.integer(
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
        format: jsonSchema['format'],
      ),
      gemini.SchemaType.boolean => gemini.Schema.boolean(
        description: jsonSchema['description'],
        nullable: jsonSchema['nullable'],
      ),
    };
  }

  static Map<String, gemini.Schema> _extractProperties(
    Map<String, dynamic> properties,
    Map<String, dynamic> rootSchema,
  ) {
    final result = <String, gemini.Schema>{};
    for (final entry in properties.entries) {
      result[entry.key] = _schemaObjectFrom(entry.value, rootSchema);
    }
    return result;
  }

  static List<String>? _extractRequiredProperties(dynamic required) {
    if (required == null) return null;
    return List<String>.from(required);
  }

  static gemini.SchemaType _getSchemaType(
    String? typeString,
  ) => switch (typeString?.toLowerCase()) {
    'string' => gemini.SchemaType.string,
    'number' => gemini.SchemaType.number,
    'integer' => gemini.SchemaType.integer,
    'boolean' => gemini.SchemaType.boolean,
    'array' => gemini.SchemaType.array,
    'object' => gemini.SchemaType.object,
    _ => gemini.SchemaType.object, // Default to object if type is not specified
  };

  static List<gemini.Tool> _toolsFrom(Iterable<Tool> tools) {
    final result = <gemini.Tool>[];

    for (final tool in tools) {
      // Convert inputSchema to a Schema object using the existing method
      final parameters =
          tool.inputSchema != null
              ? _geminiSchemaFrom(tool.inputSchema!)
              : gemini.Schema.object(properties: {});

      // Create a function declaration for the tool
      final functionDeclaration = gemini.FunctionDeclaration(
        tool.name,
        tool.description ?? '',
        parameters,
      );

      // Add the tool with its function declaration
      result.add(gemini.Tool(functionDeclarations: [functionDeclaration]));
    }

    return result;
  }

  static List<gemini.Content> _geminiHistoryFrom(List<Message> messages) {
    // Gemini Content with system role is not supported; remove initial system
    // message if present.
    final filtered =
        messages.isNotEmpty && messages.first.role == MessageRole.system
            ? messages.sublist(1)
            : messages;
    final history = [for (final m in filtered) m.geminiContent];

    assert(
      history.length == filtered.length,
      'Output Content list length (${history.length}) does not match input '
      'Message list length (${filtered.length})',
    );

    return history;
  }

  static List<Message> _messagesFrom(Iterable<gemini.Content> history) {
    final toolCallIdQueue = <String, List<String>>{};
    final messages = [
      for (final content in history)
        content.toMessageWithToolIdQueue(toolCallIdQueue),
    ];
    assert(
      messages.length == history.length,
      'Output Message list length (${messages.length}) does not match input '
      'Content list length (${history.length})',
    );
    return messages;
  }
}

extension on String? {
  MessageRole get messageRole => switch (this) {
    'user' || null => MessageRole.user,
    'model' => MessageRole.model,
    'system' => MessageRole.system,
    _ => MessageRole.user,
  };
}

extension on MessageRole {
  String get geminiRole => switch (this) {
    MessageRole.user => 'user',
    MessageRole.model => 'model',
    MessageRole.system => 'system',
  };
}

extension on gemini.Content {
  /// Converts Gemini content to a Message, ensuring each FunctionCall gets a
  /// unique ID, and the corresponding FunctionResponse uses the same ID. IDs
  /// are not reused.
  Message toMessageWithToolIdQueue(Map<String, List<String>> toolCallIdQueue) {
    final role = this.role.messageRole;
    final parts = <Part>[];
    const uuid = Uuid();
    for (final part in this.parts) {
      if (part is gemini.FunctionCall) {
        final callKey = part.name; // Use only the function name
        // Always generate a new unique ID for each call
        final id = uuid.v4();
        toolCallIdQueue.putIfAbsent(callKey, () => <String>[]).add(id);
        final argsMap = Map<String, dynamic>.from(
          (part.args as Map).map((k, v) => MapEntry(k as String, v)),
        );
        parts.add(
          ToolPart(
            kind: ToolPartKind.call,
            id: id,
            name: part.name,
            arguments: argsMap,
          ),
        );
      } else if (part is gemini.FunctionResponse) {
        // Match to the oldest outstanding call with the same name (FIFO)
        var id = '';
        final callKey = part.name; // Use only the function name
        final queue = toolCallIdQueue[callKey];
        if (queue != null && queue.isNotEmpty) {
          id = queue.removeAt(0);
        } else {
          throw StateError(
            'No outstanding tool call to match FunctionResponse for function: '
            '$callKey',
          );
        }
        Map<String, dynamic> resultMap;
        if (part.response == null) {
          resultMap = <String, dynamic>{};
        } else if (part.response is Map) {
          resultMap = Map<String, dynamic>.from(
            (part.response! as Map).map((k, v) => MapEntry(k as String, v)),
          );
        } else {
          resultMap = <String, dynamic>{};
        }
        parts.add(
          ToolPart(
            kind: ToolPartKind.result,
            id: id,
            name: part.name,
            result: resultMap,
          ),
        );
      } else if (part is gemini.TextPart) {
        parts.add(TextPart(part.text));
      } else if (part is gemini.DataPart) {
        final base64 = base64Encode(part.bytes);
        final dataUri = 'data:${part.mimeType};base64,$base64';
        parts.add(MediaPart(contentType: part.mimeType, url: dataUri));
      } else {
        assert(false, 'Unhandled part type: ${part.runtimeType}, value: $part');
      }
    }

    assert(
      parts.length == this.parts.length,
      'Output parts length (${parts.length}) does not match input '
      'Content parts length (${this.parts.length})',
    );

    return Message(role: role, content: parts);
  }
}

extension on Message {
  gemini.Content get geminiContent {
    final parts = [
      for (final p in content)
        if (p is TextPart)
          gemini.TextPart(p.text)
        else if (p is MediaPart)
          ...() {
            final url = p.url;
            final contentType = p.contentType;
            Uint8List bytes;
            if (url.startsWith('data:')) {
              final base64Str = url.split(',').last;
              bytes = Uint8List.fromList(
                const Base64Decoder().convert(base64Str),
              );
            } else {
              bytes = Uint8List(0);
            }
            return [gemini.DataPart(contentType, bytes)];
          }()
        else if (p is ToolPart && p.kind == ToolPartKind.call)
          gemini.FunctionCall(p.name, p.arguments)
        else if (p is ToolPart && p.kind == ToolPartKind.result)
          gemini.FunctionResponse(p.name, p.result)
        else
          throw UnsupportedError('Unknown part type: \\${p.runtimeType}'),
    ];

    assert(
      parts.length == content.length,
      'Output gemini parts length (${parts.length}) does not match input '
      'Message content length (${content.length})',
    );

    return gemini.Content(role.geminiRole, parts);
  }
}
