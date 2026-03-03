import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:mistralai_dart/mistralai_dart.dart' as mistral;

import '../helpers/message_part_helpers.dart';

/// Logger for Mistral message mapping operations.
final Logger _logger = Logger('dartantic.chat.mappers.mistral');

/// Decodes tool call arguments from a JSON string, validating the result is a
/// JSON object.
Map<String, dynamic> _decodeToolArguments(
  String rawArguments, {
  required String callId,
}) {
  final decoded = json.decode(rawArguments);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      'Tool call `$callId` arguments must decode to a JSON object, '
      'got ${decoded.runtimeType}.',
      rawArguments,
    );
  }
  return decoded;
}

/// Extension on [List<Tool>] to convert to Mistral tools.
extension ToolListMapper on List<Tool> {
  /// Converts this list of [Tool]s to a list of Mistral [Tool]s.
  List<mistral.Tool> toMistralTools() {
    _logger.fine('Converting $length tools to Mistral format');
    return map(
      (tool) => mistral.Tool.function(
        name: tool.name,
        description: tool.description,
        parameters: Map<String, dynamic>.from(tool.inputSchema.value),
      ),
    ).toList(growable: false);
  }
}

/// Extension on [List<ChatMessage>] to convert messages to Mistral SDK
/// messages.
extension MessageListMapper on List<ChatMessage> {
  /// Converts this list of [ChatMessage]s to a list of Mistral SDK
  /// [mistral.ChatMessage]s.
  List<mistral.ChatMessage> toChatMessages() {
    _logger.fine('Converting $length messages to Mistral format');

    // Expand messages to handle multiple tool results
    final expandedMessages = <mistral.ChatMessage>[];
    for (final message in this) {
      if (message.role == ChatMessageRole.user) {
        // Check if this is a tool result message with multiple results
        final toolResults = message.parts.toolResults;
        if (toolResults.length > 1) {
          // Mistral requires separate tool messages for each result
          for (final toolResult in toolResults) {
            final content = ToolResultHelpers.serialize(toolResult.result);
            expandedMessages.add(
              mistral.ChatMessage.tool(
                toolCallId: toolResult.callId,
                content: content,
              ),
            );
          }
        } else {
          // Single result or regular message
          expandedMessages.add(_mapMessage(message));
        }
      } else {
        // Non-user messages are mapped normally
        expandedMessages.add(_mapMessage(message));
      }
    }

    return expandedMessages;
  }

  mistral.ChatMessage _mapMessage(ChatMessage message) {
    _logger.fine(
      'Mapping ${message.role.name} message with ${message.parts.length} parts',
    );
    switch (message.role) {
      case ChatMessageRole.system:
        return mistral.ChatMessage.system(_extractTextContent(message));
      case ChatMessageRole.user:
        // Check if this is a tool result message
        final toolResults = message.parts.toolResults;

        if (toolResults.isNotEmpty) {
          // Mistral expects separate tool messages for each result
          // This should be handled at a higher level, so here we just take
          // the first
          final toolResult = toolResults.first;
          final content = ToolResultHelpers.serialize(toolResult.result);
          return mistral.ChatMessage.tool(
            toolCallId: toolResult.callId,
            content: content,
          );
        }

        // Check if message has images
        final hasImages = message.parts.any(
          (p) =>
              (p is DataPart && p.mimeType.startsWith('image/')) ||
              (p is LinkPart && (p.mimeType?.startsWith('image/') ?? false)),
        );

        if (hasImages) {
          // Build multimodal content parts
          final contentParts = <mistral.ContentPart>[];
          for (final part in message.parts) {
            switch (part) {
              case TextPart(:final text):
                contentParts.add(mistral.ContentPart.text(text));
              case DataPart(:final bytes, :final mimeType)
                  when mimeType.startsWith('image/'):
                // Convert bytes to base64 data URL
                final base64Data = base64Encode(bytes);
                final dataUrl = 'data:$mimeType;base64,$base64Data';
                contentParts.add(mistral.ContentPart.imageUrl(dataUrl));
              case LinkPart(:final url, :final mimeType)
                  when mimeType?.startsWith('image/') ?? false:
                contentParts.add(mistral.ContentPart.imageUrl(url.toString()));
              default:
                // Skip non-text/non-image parts
                break;
            }
          }
          return mistral.ChatMessage.userMultimodal(contentParts);
        } else {
          // Text-only message
          return mistral.ChatMessage.user(_extractTextContent(message));
        }
      case ChatMessageRole.model:
        // Extract text content
        final textContent = _extractTextContent(message);

        // Extract tool calls
        final toolCalls = message.parts.toolCalls
            .map(
              (p) => mistral.ToolCall(
                id: p.callId,
                function: mistral.FunctionCall(
                  name: p.toolName,
                  arguments: json.encode(p.arguments ?? {}),
                ),
              ),
            )
            .toList();

        return mistral.ChatMessage.assistant(
          textContent.isEmpty ? null : textContent,
          toolCalls: toolCalls.isEmpty ? null : toolCalls,
        );
    }
  }

  String _extractTextContent(ChatMessage message) {
    final content = message.parts.text;
    if (content.isEmpty) {
      _logger.fine('No text parts found in message');
      return '';
    }
    _logger.fine('Extracted text content: ${content.length} characters');
    return content;
  }
}

/// Extension on [mistral.ChatCompletionResponse] to convert to [ChatResult].
extension ChatResultMapper on mistral.ChatCompletionResponse {
  /// Converts this [mistral.ChatCompletionResponse] to a [ChatResult].
  ChatResult<ChatMessage> toChatResult() {
    final choice = choices.first;
    final content = choice.message.content ?? '';
    _logger.fine(
      'Converting Mistral response to ChatResult: id=$id, '
      'content=${content.length} characters',
    );

    // Extract tool calls from the response
    final toolCallParts =
        choice.message.toolCalls
            ?.map(
              (tc) => ToolPart.call(
                callId: tc.id,
                toolName: tc.function.name,
                arguments: tc.function.arguments.isNotEmpty
                    ? _decodeToolArguments(tc.function.arguments, callId: tc.id)
                    : {},
              ),
            )
            .toList() ??
        [];

    final parts = <Part>[
      if (content.isNotEmpty) TextPart(content),
      ...toolCallParts,
    ];

    final message = ChatMessage(role: ChatMessageRole.model, parts: parts);

    final responseUsage = usage;
    return ChatResult<ChatMessage>(
      id: id,
      output: message,
      messages: [message],
      finishReason: _mapFinishReason(choice.finishReason),
      metadata: {'model': model, 'created': created},
      usage: responseUsage != null ? _mapUsage(responseUsage) : null,
    );
  }

  LanguageModelUsage _mapUsage(mistral.UsageInfo usage) {
    _logger.fine(
      'Mapping usage: prompt=${usage.promptTokens}, '
      'response=${usage.completionTokens}, total=${usage.totalTokens}',
    );
    return LanguageModelUsage(
      promptTokens: usage.promptTokens,
      responseTokens: usage.completionTokens,
      totalTokens: usage.totalTokens,
    );
  }
}

/// Mapper for [mistral.ChatCompletionStreamResponse].
extension CreateChatCompletionStreamResponseMapper
    on mistral.ChatCompletionStreamResponse {
  /// Converts a [mistral.ChatCompletionStreamResponse] to a [ChatResult].
  ChatResult<ChatMessage> toChatResult() {
    final choice = choices.first;
    final content = choice.delta.content ?? '';
    _logger.fine(
      'Converting Mistral stream response to ChatResult: id=$id, '
      'content=${content.length} characters',
    );

    // Extract tool calls from streaming delta
    // Note: Mistral sends complete tool calls, not incremental deltas
    final toolCallParts =
        choice.delta.toolCalls
            ?.map(
              (tc) => ToolPart.call(
                callId: tc.id,
                toolName: tc.function.name,
                arguments: tc.function.arguments.isNotEmpty
                    ? _decodeToolArguments(tc.function.arguments, callId: tc.id)
                    : {},
              ),
            )
            .toList() ??
        [];

    final parts = <Part>[
      if (content.isNotEmpty) TextPart(content),
      ...toolCallParts,
    ];

    final message = ChatMessage(role: ChatMessageRole.model, parts: parts);

    final streamUsage = usage;
    return ChatResult<ChatMessage>(
      id: id,
      output: message,
      messages: [message],
      finishReason: _mapFinishReason(choice.finishReason),
      metadata: {'model': model, 'created': created},
      usage: streamUsage != null ? _mapStreamUsage(streamUsage) : null,
    );
  }

  LanguageModelUsage _mapStreamUsage(mistral.UsageInfo usage) {
    _logger.fine(
      'Mapping stream usage: prompt=${usage.promptTokens}, '
      'response=${usage.completionTokens}, total=${usage.totalTokens}',
    );
    return LanguageModelUsage(
      promptTokens: usage.promptTokens,
      responseTokens: usage.completionTokens,
      totalTokens: usage.totalTokens,
    );
  }
}

FinishReason _mapFinishReason(mistral.FinishReason? reason) {
  final mapped = switch (reason) {
    mistral.FinishReason.stop => FinishReason.stop,
    mistral.FinishReason.length => FinishReason.length,
    mistral.FinishReason.modelLength => FinishReason.length,
    mistral.FinishReason.error => FinishReason.unspecified,
    mistral.FinishReason.toolCalls => FinishReason.toolCalls,
    mistral.FinishReason.unknown => FinishReason.unspecified,
    null => FinishReason.unspecified,
  };
  _logger.fine('Mapped finish reason: $reason -> $mapped');
  return mapped;
}
