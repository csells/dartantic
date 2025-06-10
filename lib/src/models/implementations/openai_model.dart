import 'dart:convert';
import 'dart:developer' as dev;

import 'package:json_schema/json_schema.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../../../dartantic_ai.dart';
import '../interface/model.dart';
import '../message.dart';

/// Implementation of [Model] that uses OpenAI's API.
///
/// This model handles interaction with OpenAI models, supporting both
/// standard text responses and structured JSON schema responses.
class OpenAiModel extends Model {
  /// Creates a new [OpenAiModel] with the given parameters.
  ///
  /// The [apiKey] is the API key to use for authentication.
  /// The [modelName] is the name of the OpenAI model to use.
  /// The [outputType] is an optional JSON schema for structured outputs.
  /// The [systemPrompt] is an optional system prompt to use.
  OpenAiModel({
    required String apiKey,
    required String modelName,
    JsonSchema? outputType,
    String? systemPrompt,
    Iterable<Tool>? tools,
  }) : _tools = tools,
       _systemPrompt = systemPrompt,
       _modelName = modelName,
       _client = openai.OpenAIClient(apiKey: apiKey),
       _responseFormat =
           outputType != null
               ? openai.ResponseFormat.jsonSchema(
                 jsonSchema: _openaiSchemaFrom(outputType),
               )
               : null;

  final openai.OpenAIClient _client;
  final String _modelName;
  final openai.ResponseFormat? _responseFormat;
  final String? _systemPrompt;
  final Iterable<Tool>? _tools;

  @override
  Stream<AgentResponse> runStream({
    required String prompt,
    required List<Message> messages,
  }) async* {
    final oiaMessages = <openai.ChatCompletionMessage>[
      if (_systemPrompt != null && _systemPrompt.isNotEmpty && messages.isEmpty)
        openai.ChatCompletionMessage.system(content: _systemPrompt),
      ..._openaiMessagesFrom(messages),
      openai.ChatCompletionMessage.user(
        content: openai.ChatCompletionUserMessageContent.string(prompt),
      ),
    ];

    // Track the last assistant message with tool_calls
    var lastToolCallIds = <String>[];

    while (true) {
      final stream = _client.createChatCompletionStream(
        request: openai.CreateChatCompletionRequest(
          model: openai.ChatCompletionModel.modelId(_modelName),
          responseFormat: _responseFormat,
          messages: oiaMessages,
          tools:
              _tools
                  ?.map(
                    (tool) => openai.ChatCompletionTool(
                      type: openai.ChatCompletionToolType.function,
                      function: openai.FunctionObject(
                        name: tool.name,
                        description: tool.description,
                        parameters: tool.inputType?.toMap(),
                      ),
                    ),
                  )
                  .toList(),
        ),
      );

      // Accumulate tool call arguments by tool call index and ID
      final toolCallIdByIndex = <int, String?>{};
      final toolCallBuffers = <String, ({String name, StringBuffer args})>{};
      var isFinished = false;

      // Accumulate the assistant/model response as it streams in
      final assistantBuffer = StringBuffer();

      await for (final chunk in stream) {
        final choice = chunk.choices.first;
        final delta = choice.delta;

        if (choice.finishReason != null) {
          isFinished = true;
        }

        dev.log(
          '[OpenAiModel] Raw delta: $delta, '
          'finishReason: ${choice.finishReason}',
        );

        // Handle content streaming
        if (delta.content != null) {
          dev.log('[OpenAiModel] Yielding content: ${delta.content!}');
          assistantBuffer.write(delta.content);
          yield AgentResponse(
            output: delta.content!,
            messages: _messagesFrom(oiaMessages),
          );
        }

        // Handle tool calls
        if (delta.toolCalls != null && delta.toolCalls!.isNotEmpty) {
          for (final toolCall in delta.toolCalls!) {
            final index = toolCall.index;
            final id = toolCall.id;
            final name = toolCall.function?.name;
            final args = toolCall.function?.arguments;

            // If this chunk starts a new tool call, record its id and name
            if (id != null && name != null) {
              toolCallIdByIndex[index] = id;
              toolCallBuffers.putIfAbsent(
                id,
                () => (name: name, args: StringBuffer()),
              );
            }
            // Use the most recent id for this index
            final currentId = toolCallIdByIndex[index];
            if (currentId != null && args != null) {
              toolCallBuffers[currentId]!.args.write(args);
              dev.log(
                '[OpenAiModel] Tool call received: index=$index, '
                'id=$currentId, name=${toolCallBuffers[currentId]!.name}, '
                'args=$args',
              );
            }
          }
        }
      }

      // After streaming, append the assistant message to the conversation
      if (assistantBuffer.isNotEmpty) {
        oiaMessages.add(
          openai.ChatCompletionMessage.assistant(
            content: assistantBuffer.toString(),
          ),
        );
      }
      // Yield the full message list including the model's response
      yield AgentResponse(output: '', messages: _messagesFrom(oiaMessages));

      // Remove incomplete tool call buffers (empty or invalid JSON)
      toolCallBuffers.removeWhere((_, v) {
        final argsStr = v.args.toString().trim();
        if (argsStr.isEmpty) return true;
        try {
          jsonDecode(argsStr);
          return false;
        } on Exception catch (_) {
          return true;
        }
      });

      // If the model has finished its turn and there are no tool calls, break.
      if (isFinished && toolCallBuffers.isEmpty) {
        dev.log('[OpenAiModel] Finished and no tool calls, breaking loop.');
        break;
      }

      // Add the assistant message with tool_calls before tool responses
      if (toolCallBuffers.isNotEmpty) {
        final toolCalls =
            toolCallBuffers.entries
                .map(
                  (entry) => openai.ChatCompletionMessageToolCall(
                    id: entry.key,
                    type: openai.ChatCompletionMessageToolCallType.function,
                    function: openai.ChatCompletionMessageFunctionCall(
                      name: entry.value.name,
                      arguments: entry.value.args.toString(),
                    ),
                  ),
                )
                .toList();
        oiaMessages.add(
          openai.ChatCompletionMessage.assistant(
            content: null,
            toolCalls: toolCalls,
          ),
        );
        lastToolCallIds = toolCalls.map((tc) => tc.id).toList();
      }

      // Only respond to tool calls present in the last assistant message
      final validToolCallIds = lastToolCallIds.toSet();

      for (final entry in toolCallBuffers.entries) {
        final toolCallId = entry.key;
        if (!validToolCallIds.contains(toolCallId)) {
          continue; // Only respond to valid tool calls
        }
        final toolCallName = entry.value.name;
        final toolCallArgs = entry.value.args.toString();
        if (toolCallArgs.trim().isEmpty) continue; // skip empty args
        dev.log(
          '[OpenAiModel] Calling tool: id=$toolCallId, name=$toolCallName, '
          'args=$toolCallArgs',
        );
        final args = jsonDecode(toolCallArgs) as Map<String, dynamic>;
        final result = await _callTool(toolCallName, args);

        // Add the tool response to the messages
        dev.log(
          '[OpenAiModel] Adding tool response to messages: id=$toolCallId, '
          'result=${jsonEncode(result)}',
        );
        oiaMessages.add(
          openai.ChatCompletionMessage.tool(
            toolCallId: toolCallId,
            content: jsonEncode(result),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _callTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    Map<String, dynamic>? result;
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

  static openai.JsonSchemaObject _openaiSchemaFrom(
    JsonSchema rawJsonSchema, {
    String name = 'response',
    bool strict = true,
  }) {
    // Ensure additionalProperties: false is set at every object level
    final jsonSchema = rawJsonSchema.toMap();
    final schema = _ensureAdditionalPropertiesFalse(jsonSchema);

    return openai.JsonSchemaObject(
      name: name,
      description: schema['description'] as String?,
      schema: schema,
      strict: strict,
    );
  }

  static Map<String, Object> _ensureAdditionalPropertiesFalse(
    Map<String, dynamic> schema,
  ) {
    final result = Map<String, Object>.from(schema);

    // Skip adding additionalProperties if $ref is present
    if (!result.containsKey(r'$ref')) {
      // Set additionalProperties: false for this object
      result['additionalProperties'] = false;
    }

    // Remove format field if it exists
    result.remove('format');

    // Handle properties of objects
    if (result['properties'] is Map) {
      final properties = Map<String, Object>.from(result['properties']! as Map);
      for (final entry in properties.entries) {
        if (entry.value is Map) {
          properties[entry.key] = _ensureAdditionalPropertiesFalse(
            entry.value as Map<String, dynamic>,
          );
        }
      }
      result['properties'] = properties;
    }

    // Handle items of arrays
    if (result['items'] is Map) {
      result['items'] = _ensureAdditionalPropertiesFalse(
        result['items']! as Map<String, dynamic>,
      );
    }

    // Handle definitions
    if (result[r'$defs'] is Map) {
      final definitions = Map<String, Object>.from(result[r'$defs']! as Map);
      for (final entry in definitions.entries) {
        if (entry.value is Map) {
          definitions[entry.key] = _ensureAdditionalPropertiesFalse(
            entry.value as Map<String, dynamic>,
          );
        }
      }
      result[r'$defs'] = definitions;
    }

    return result;
  }

  static List<openai.ChatCompletionMessage> _openaiMessagesFrom(
    List<Message> messages,
  ) {
    final result = <openai.ChatCompletionMessage>[];
    for (final message in messages) {
      // Gather tool calls and tool results
      final toolCalls = <openai.ChatCompletionMessageToolCall>[];
      ToolPart? toolResult;
      final textParts = <String>[];
      for (final part in message.content) {
        if (part is TextPart) {
          textParts.add(part.text);
        } else if (part is MediaPart) {
          textParts.add('[media: ${part.contentType}] ${part.url}');
        } else if (part is ToolPart) {
          if (part.kind == ToolPartKind.call) {
            toolCalls.add(
              openai.ChatCompletionMessageToolCall(
                id: part.id,
                type: openai.ChatCompletionMessageToolCallType.function,
                function: openai.ChatCompletionMessageFunctionCall(
                  name: part.name,
                  arguments: jsonEncode(part.arguments),
                ),
              ),
            );
          } else if (part.kind == ToolPartKind.result) {
            toolResult = part;
          }
        }
      }
      final contentString = textParts.join(' ');
      if (toolResult != null) {
        // Tool result: emit a tool role message
        result.add(
          openai.ChatCompletionMessage.tool(
            toolCallId: toolResult.id,
            content: jsonEncode(toolResult.result),
          ),
        );
      } else if (toolCalls.isNotEmpty) {
        // Tool call: emit an assistant message with toolCalls
        result.add(
          openai.ChatCompletionMessage.assistant(
            content: contentString.isNotEmpty ? contentString : null,
            toolCalls: toolCalls,
          ),
        );
      } else {
        // Regular message
        switch (message.role) {
          case MessageRole.system:
            result.add(
              openai.ChatCompletionMessage.system(content: contentString),
            );
          case MessageRole.user:
            result.add(
              openai.ChatCompletionMessage.user(
                content: openai.ChatCompletionUserMessageContent.string(
                  contentString,
                ),
              ),
            );
          case MessageRole.model:
            result.add(
              openai.ChatCompletionMessage.assistant(content: contentString),
            );
        }
      }
    }
    return result;
  }

  static List<Message> _messagesFrom(
    List<openai.ChatCompletionMessage> openMessages,
  ) {
    // Map tool call IDs to tool names
    final toolCallIdToName = <String, String>{};
    final result = <Message>[];
    for (final message in openMessages) {
      final parts = <Part>[];
      if (message.role == openai.ChatCompletionMessageRole.tool) {
        // Tool result: parse content as JSON and create ToolPart(kind: result)
        final content = message.content;
        if (content is String && content.isNotEmpty) {
          try {
            final resultJson = jsonDecode(content);
            final toolCallId =
                message is openai.ChatCompletionToolMessage
                    ? message.toolCallId
                    : '';
            final toolName = toolCallIdToName[toolCallId] ?? '';
            parts.add(
              ToolPart(
                kind: ToolPartKind.result,
                id: toolCallId,
                name: toolName,
                result:
                    resultJson is Map<String, dynamic>
                        ? resultJson
                        : <String, dynamic>{},
              ),
            );
          } on Exception catch (_) {
            parts.add(TextPart(content));
          }
        }
      } else {
        if (message.content is String) {
          parts.add(TextPart(message.content! as String));
        } else if (message.content is List) {
          for (final c in message.content! as List) {
            if (c is String) {
              parts.add(TextPart(c));
            }
          }
        } else if (message.content is openai.ChatCompletionUserMessageContent) {
          final userContent =
              message.content! as openai.ChatCompletionUserMessageContent;
          parts.add(TextPart(userContent.value as String));
        }
        if (message.role == openai.ChatCompletionMessageRole.assistant &&
            message is openai.ChatCompletionAssistantMessage) {
          final assistantMsg = message;
          final toolCalls = assistantMsg.toolCalls;
          if (toolCalls != null) {
            for (final call in toolCalls) {
              toolCallIdToName[call.id] = call.function.name;
              parts.add(
                ToolPart(
                  kind: ToolPartKind.call,
                  id: call.id,
                  name: call.function.name,
                  arguments: () {
                    try {
                      final decoded = jsonDecode(call.function.arguments);
                      return decoded is Map<String, dynamic>
                          ? decoded
                          : <String, dynamic>{};
                    } on Exception catch (_) {
                      return <String, dynamic>{};
                    }
                  }(),
                ),
              );
            }
          }
        }
      }
      result.add(Message(role: message.role.messageRole, content: parts));
    }

    assert(
      result.length == openMessages.length,
      r'Output message list length (${result.length}) does not match input '
      'message list length (${openMessages.length})',
    );

    return result;
  }
}

extension on openai.ChatCompletionMessageRole {
  MessageRole get messageRole => switch (this) {
    openai.ChatCompletionMessageRole.system => MessageRole.system,
    openai.ChatCompletionMessageRole.user => MessageRole.user,
    openai.ChatCompletionMessageRole.assistant => MessageRole.model,
    openai.ChatCompletionMessageRole.tool => MessageRole.model,
    _ => MessageRole.model,
  };
}
