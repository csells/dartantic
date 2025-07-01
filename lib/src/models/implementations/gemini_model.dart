import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:json_schema/json_schema.dart';
import 'package:uuid/uuid.dart';

import '../../agent/agent_response.dart';
import '../../agent/embedding_type.dart';
import '../../agent/tool.dart';
import '../../json_schema_extension.dart';
import '../../message.dart';
import '../../providers/interface/provider_caps.dart';
import '../../utils.dart';
import '../interface/model.dart';

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
    required String apiKey,
    String? modelName,
    String? embeddingModelName,
    JsonSchema? outputSchema,
    String? systemPrompt,
    Iterable<Tool>? tools,
    double? temperature,
  }) : generativeModelName = modelName ?? defaultModelName,
       embeddingModelName = embeddingModelName ?? defaultEmbeddingModelName,
       _apiKey = apiKey,
       _tools = tools?.toList(),
       _model = gemini.GenerativeModel(
         apiKey: apiKey,
         model: modelName ?? defaultModelName,
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
         tools: tools != null ? toolsFrom(tools).toList() : null,
       );

  /// The default model name to use if none is provided.
  static const defaultModelName = 'gemini-2.0-flash';

  /// The default embedding model name to use if none is provided.
  static const defaultEmbeddingModelName = 'text-embedding-004';

  late final gemini.GenerativeModel _model;
  final String _apiKey;
  final List<Tool>? _tools;

  @override
  final String generativeModelName;

  @override
  final String embeddingModelName;

  @override
  Stream<AgentResponse> runStream({
    required String prompt,
    required Iterable<Message> messages,
    required Iterable<Part> attachments,
  }) async* {
    // # Implementation Notes:
    // ## Goal: Multi-Step Tool Calling for Gemini
    // To enable Gemini models to perform multi-step tool calling isn't
    // difficult, but it requires a loop.
    //
    // ## The Loop
    // The loop is simple:
    // - Send history + messages + tools to Gemini
    // - Process streaming response, collecting tool calls
    // - If tool calls found → execute them, add results to conversation,
    //   continue loop
    // - If no tool calls found -> return the final text message and we're done
    //
    // This is much simpler than the OpenAI approach, which requires a probe,
    // since while we're processing the tool calls result(s) response from the
    // model, it will return with the very next tool call. It doesn't just sit
    // there waiting for another prompt to continue what it was doing.
    log.finer(
      '[GeminiModel] Starting stream with ${messages.length} messages, '
      'prompt length: ${prompt.length}',
    );

    final history = _geminiHistoryFrom(messages).toList();
    final chat = _model.startChat(history: history.isEmpty ? null : history);
    final message = Message.user([TextPart(prompt), ...attachments]);
    final stream = chat.sendMessageStream(message.geminiContent);

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

    // Process function calls in a loop to handle multi-step tool calling
    while (functionCalls.isNotEmpty) {
      log.finest(
        '[GeminiModel] Processing [0m${functionCalls.length} function calls',
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
          log.finer(
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

      // Send function responses back to the model using streaming
      log.finest('[GeminiModel] Sending function responses back to model');
      final stream = chat.sendMessageStream(
        gemini.Content.functionResponses(responses),
      );

      // Clear old function calls and collect new response
      functionCalls.clear();

      // Stream the response as it comes in
      await for (final chunk in stream) {
        final text = chunk.text ?? '';
        if (text.isNotEmpty) {
          log.finest('[GeminiModel] Streaming after tools: $text');
          yield AgentResponse(output: text, messages: []);
        }

        // Collect any new function calls from this response
        if (chunk.functionCalls.isNotEmpty) {
          final newCalls = chunk.functionCalls
              .map((fc) => '${fc.name}(${fc.args})')
              .join(', ');
          log.finest('[GeminiModel] New function calls: $newCalls');
          functionCalls.addAll(chunk.functionCalls);
        }
      }

      if (functionCalls.isNotEmpty) {
        final additionalCalls = functionCalls
            .map((fc) => '${fc.name}(${fc.args})')
            .join(', ');
        log.finest('[GeminiModel] Additional function calls: $additionalCalls');
      }
    }

    // Yield final response with complete message history
    yield AgentResponse(output: '', messages: _messagesFrom(chat.history));
  }

  @override
  Future<Float64List> createEmbedding(
    String text, {
    EmbeddingType type = EmbeddingType.document,
    int? dimensions,
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
      model: embeddingModelName,
    );

    final response = await embeddingModel.embedContent(
      gemini.Content.text(text),
      taskType: taskType,
      outputDimensionality: dimensions,
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
    final schema = _schemaObjectFrom(map, map);
    return schema;
  }

  static gemini.Schema _schemaObjectFrom(
    Map<String, dynamic> jsonSchema,
    Map<String, dynamic> rootSchema, {
    bool isRequired = false,
  }) {
    // Handle $ref references
    if (jsonSchema.containsKey(r'$ref')) {
      final ref = jsonSchema[r'$ref'] as String;
      if (ref.startsWith(r'#/$defs/')) {
        final defName = ref.substring(8); // Remove '#/$defs/'
        final defs = rootSchema[r'$defs'] as Map<String, dynamic>?;
        if (defs != null && defs.containsKey(defName)) {
          return _schemaObjectFrom(
            defs[defName],
            rootSchema,
            isRequired: isRequired,
          );
        }
      }
    }

    final type = _getSchemaType(jsonSchema['type']);

    return switch (type) {
      gemini.SchemaType.object => gemini.Schema.object(
        properties: _extractProperties(
          jsonSchema['properties'] ?? {},
          rootSchema,
          requiredProperties:
              _extractRequiredProperties(jsonSchema['required'])?.toSet(),
        ),
        requiredProperties:
            _extractRequiredProperties(jsonSchema['required'])?.toList(),
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
      ),
      gemini.SchemaType.array => gemini.Schema.array(
        items: _schemaObjectFrom(jsonSchema['items'] ?? {}, rootSchema),
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
      ),
      gemini.SchemaType.string when jsonSchema['enum'] != null => gemini
          .Schema.enumString(
        enumValues: List<String>.from(jsonSchema['enum']),
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
      ),
      gemini.SchemaType.string => gemini.Schema.string(
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
      ),
      gemini.SchemaType.number => gemini.Schema.number(
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
        format: jsonSchema['format'],
      ),
      gemini.SchemaType.integer => gemini.Schema.integer(
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
        format: jsonSchema['format'],
      ),
      gemini.SchemaType.boolean => gemini.Schema.boolean(
        description: jsonSchema['description'],
        nullable: _getNullable(jsonSchema, isRequired),
      ),
    };
  }

  static Map<String, gemini.Schema> _extractProperties(
    Map<String, dynamic> properties,
    Map<String, dynamic> rootSchema, {
    Set<String>? requiredProperties,
  }) {
    final result = <String, gemini.Schema>{};
    for (final entry in properties.entries) {
      final isRequired = requiredProperties?.contains(entry.key) ?? false;
      result[entry.key] = _schemaObjectFrom(
        entry.value,
        rootSchema,
        isRequired: isRequired,
      );
    }
    return result;
  }

  static Iterable<String>? _extractRequiredProperties(dynamic required) {
    if (required == null) return null;
    return List<String>.from(required);
  }

  static bool? _getNullable(Map<String, dynamic> jsonSchema, bool isRequired) {
    // If explicitly set in schema, use that value
    if (jsonSchema.containsKey('nullable')) {
      return jsonSchema['nullable'] as bool?;
    }
    // If property is required, it cannot be null
    if (isRequired) {
      return false;
    }
    // Otherwise, let Gemini use its default
    return null;
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

  /// for use by tests only
  static Iterable<gemini.Tool> toolsFrom(Iterable<Tool> tools) {
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

  static Iterable<gemini.Content> _geminiHistoryFrom(
    Iterable<Message> messages,
  ) {
    // Gemini Content with system role is not supported; remove initial system
    // message if present.
    final filtered =
        messages.isNotEmpty && messages.first.role == MessageRole.system
            ? messages.skip(1)
            : messages;
    final history = [for (final m in filtered) m.geminiContent];

    assert(
      history.length == filtered.length,
      'Output Content list length (${history.length}) does not match input '
      'Message list length (${filtered.length})',
    );

    return history;
  }

  static Iterable<Message> _messagesFrom(Iterable<gemini.Content> history) {
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

  @override
  final Set<ProviderCaps> caps = ProviderCaps.all;
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
    for (final part in this.parts) {
      if (part is gemini.FunctionCall) {
        final callKey = part.name; // Use only the function name
        // Always generate a new unique ID for each call
        final id = const Uuid().v4();
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
        parts.add(DataPart(part.bytes, mimeType: part.mimeType));
      } else if (part is gemini.FilePart) {
        parts.add(LinkPart(part.uri));
      } else {
        assert(false, 'Unhandled part type: ${part.runtimeType}, value: $part');
      }
    }

    assert(
      parts.length == this.parts.length,
      'Output parts length (${parts.length}) does not match input '
      'Content parts length (${this.parts.length})',
    );

    return Message(role: role, parts: parts);
  }
}

extension on Message {
  gemini.Content get geminiContent {
    final parts = [
      for (final p in this.parts)
        switch (p) {
          TextPart() => gemini.TextPart(p.text),
          DataPart() => gemini.DataPart(p.mimeType, p.bytes),
          ToolPart() => switch (p.kind) {
            ToolPartKind.call => gemini.FunctionCall(p.name, p.arguments),
            ToolPartKind.result => gemini.FunctionResponse(p.name, p.result),
          },
          LinkPart() => gemini.FilePart(p.url),
        },
    ];

    assert(
      parts.length == this.parts.length,
      'Output gemini parts length (${parts.length}) does not match input '
      'Message content length (${this.parts.length})',
    );

    return gemini.Content(role.geminiRole, parts);
  }
}
