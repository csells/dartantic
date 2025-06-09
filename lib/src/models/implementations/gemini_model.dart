import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:json_schema/json_schema.dart';

import '../../agent/agent_response.dart';
import '../../agent/tool.dart';
import '../../json_schema_extension.dart';
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
  /// The [apiKey] is the API key to use for authentication.
  /// The [outputType] is an optional JSON schema for structured outputs.
  /// The [systemPrompt] is an optional system prompt to use.
  GeminiModel({
    required String modelName,
    required String apiKey,
    JsonSchema? outputType,
    String? systemPrompt,
    Iterable<Tool>? tools,
  }) : _tools = tools,
       _model = gemini.GenerativeModel(
         apiKey: apiKey,
         model: modelName,
         generationConfig:
             outputType == null
                 ? null
                 : gemini.GenerationConfig(
                   responseMimeType: 'application/json',
                   responseSchema: _schemaObjectFromJsonSchema(outputType),
                 ),
         systemInstruction:
             systemPrompt != null ? gemini.Content.text(systemPrompt) : null,
         tools: tools != null ? _toolsFrom(tools) : null,
       );

  late final gemini.GenerativeModel _model;
  final Iterable<Tool>? _tools;

  @override
  Stream<AgentResponse> runStream({
    required String prompt,
    required List<Message> messages,
  }) async* {
    final history = _geminiHistoryFrom(messages);
    final chat = _model.startChat(history: history.isEmpty ? null : history);
    final stream = chat.sendMessageStream(gemini.Content.text(prompt));

    final chunks = <String>[];
    final functionCalls = <gemini.FunctionCall>[];

    await for (final chunk in stream) {
      final text = chunk.text ?? '';
      if (text.isNotEmpty) {
        chunks.add(text);
        yield AgentResponse(output: text, messages: []);
      }

      // Collect function calls
      functionCalls.addAll(chunk.functionCalls);
    }

    // output a blank response to include the final history, as the history
    // won't be updated until after the stream is done
    yield AgentResponse(output: '', messages: _messagesFrom(chat.history));

    // If there are function calls, handle them
    if (functionCalls.isNotEmpty) {
      final responses = <gemini.FunctionResponse>[];

      for (final functionCall in functionCalls) {
        final result = await _callTool(functionCall.name, functionCall.args);
        responses.add(gemini.FunctionResponse(functionCall.name, result));
      }

      // Send function responses back to the model
      final result = await chat.sendMessage(
        gemini.Content.multi([
          gemini.TextPart(''), // Gemini requires a text part
          ...responses,
        ]),
      );

      if (result.text != null && result.text!.isNotEmpty) {
        yield AgentResponse(
          output: result.text!,
          messages: _messagesFrom(chat.history),
        );
      }
    }
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

    dev.log('Tool: $name($args)= $result');
    return result;
  }

  static gemini.Schema _schemaObjectFromJsonSchema(JsonSchema jsonSchema) {
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
      // Convert inputType to a Schema object using the existing method
      final parameters =
          tool.inputType != null
              ? _schemaObjectFromJsonSchema(tool.inputType!)
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

  static List<gemini.Content> _geminiHistoryFrom(List<Message> messages) =>
      messages
          .map(
            (m) => gemini.Content.multi(
              m.content.map((p) {
                if (p is TextPart) {
                  return gemini.TextPart(p.text);
                } else if (p is MediaPart) {
                  final url = p.url ?? '';
                  Uint8List? bytes;
                  if (url.startsWith('data:')) {
                    final base64Str = url.split(',').last;
                    bytes = Uint8List.fromList(
                      const Base64Decoder().convert(base64Str),
                    );
                  } else {
                    bytes = Uint8List(0);
                  }
                  return gemini.DataPart(p.contentType ?? '', bytes);
                } else if (p is ToolPart) {
                  return gemini.FunctionCall(
                    p.name ?? '',
                    p.arguments is Map<String, dynamic> ? p.arguments : {},
                  );
                } else {
                  throw UnsupportedError(
                    'Unknown part type: \\${p.runtimeType}',
                  );
                }
              }).toList(),
            ),
          )
          .toList();

  static List<Message> _messagesFrom(Iterable<gemini.Content> history) {
    final messages = <Message>[];
    for (final content in history) {
      final role = switch (content.role) {
        'user' => MessageRole.user,
        'model' => MessageRole.model,
        'system' => MessageRole.system,
        _ => MessageRole.model,
      };

      final parts = <Part>[];
      for (final part in content.parts) {
        if (part is gemini.TextPart) {
          parts.add(TextPart(part.text));
        } else if (part is gemini.DataPart) {
          final base64 = base64Encode(part.bytes);
          final dataUri = 'data:${part.mimeType};base64,$base64';
          parts.add(MediaPart(contentType: part.mimeType, url: dataUri));
        } else if (part is gemini.FunctionCall) {
          parts.add(ToolPart(name: part.name, arguments: part.args));
        } else {
          dev.log('Unhandled part type: ${part.runtimeType}, value: $part');
        }
      }
      if (parts.isEmpty) {
        dev.log(
          'Skipped content (no parts extracted) for type: '
          '${content.runtimeType}, value: $content',
        );
        continue;
      }
      messages.add(Message(role: role, content: parts));
    }
    assert(
      messages.length == history.length,
      'Output message list length (${messages.length}) does not match input '
      'history list length (${history.length})',
    );
    return messages;
  }

  // static String _textFromGeminiContent(gemini.Content content) =>
  //     content.parts.map((p) => p is gemini.TextPart ? p.text : '').join();

  // static String _textFromMessage(Message message) =>
  //     message.content.map((p) => p is TextPart ? p.text : '').join();
}
