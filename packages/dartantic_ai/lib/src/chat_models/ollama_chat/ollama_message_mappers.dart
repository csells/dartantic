import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart' as o;

import '../helpers/message_part_helpers.dart';
import '../helpers/tool_id_helpers.dart';
import 'ollama_chat_options.dart';

/// Logger for chat.mappers.ollama operations.
final Logger _logger = Logger('dartantic.chat.mappers.ollama');

/// Creates a [o.ChatRequest] from the given input.
o.ChatRequest generateChatCompletionRequest(
  List<ChatMessage> messages, {
  required String modelName,
  required OllamaChatOptions? options,
  required OllamaChatOptions defaultOptions,
  List<Tool>? tools,
  double? temperature,
  Schema? outputSchema,
  bool enableThinking = false,
}) {
  _logger.fine(
    'Creating Ollama chat completion request for model: $modelName '
    'with ${messages.length} messages',
  );

  // Use native Ollama format parameter for structured output
  final format = outputSchema != null
      ? o.SchemaFormat(Map<String, dynamic>.from(outputSchema.value))
      : options?.format ?? defaultOptions.format;

  return o.ChatRequest(
    model: modelName,
    messages: messages.toMessages(),
    format: format,
    keepAlive: options?.keepAlive ?? defaultOptions.keepAlive,
    tools: tools?.toOllamaTools(),
    stream: true,
    think: enableThinking ? const o.ThinkEnabled(true) : null,
    logprobs: options?.logprobs ?? defaultOptions.logprobs,
    topLogprobs: options?.topLogprobs ?? defaultOptions.topLogprobs,
    options: o.ModelOptions(
      numKeep: options?.numKeep ?? defaultOptions.numKeep,
      seed: options?.seed ?? defaultOptions.seed,
      numPredict: options?.numPredict ?? defaultOptions.numPredict,
      topK: options?.topK ?? defaultOptions.topK,
      topP: options?.topP ?? defaultOptions.topP,
      minP: options?.minP ?? defaultOptions.minP,
      tfsZ: options?.tfsZ ?? defaultOptions.tfsZ,
      typicalP: options?.typicalP ?? defaultOptions.typicalP,
      repeatLastN: options?.repeatLastN ?? defaultOptions.repeatLastN,
      temperature: temperature,
      repeatPenalty: options?.repeatPenalty ?? defaultOptions.repeatPenalty,
      presencePenalty:
          options?.presencePenalty ?? defaultOptions.presencePenalty,
      frequencyPenalty:
          options?.frequencyPenalty ?? defaultOptions.frequencyPenalty,
      mirostat: options?.mirostat ?? defaultOptions.mirostat,
      mirostatTau: options?.mirostatTau ?? defaultOptions.mirostatTau,
      mirostatEta: options?.mirostatEta ?? defaultOptions.mirostatEta,
      penalizeNewline:
          options?.penalizeNewline ?? defaultOptions.penalizeNewline,
      stop: options?.stop ?? defaultOptions.stop,
      numa: options?.numa ?? defaultOptions.numa,
      numCtx: options?.numCtx ?? defaultOptions.numCtx,
      numBatch: options?.numBatch ?? defaultOptions.numBatch,
      numGpu: options?.numGpu ?? defaultOptions.numGpu,
      mainGpu: options?.mainGpu ?? defaultOptions.mainGpu,
      lowVram: options?.lowVram ?? defaultOptions.lowVram,
      f16Kv: options?.f16KV ?? defaultOptions.f16KV,
      logitsAll: options?.logitsAll ?? defaultOptions.logitsAll,
      vocabOnly: options?.vocabOnly ?? defaultOptions.vocabOnly,
      useMmap: options?.useMmap ?? defaultOptions.useMmap,
      useMlock: options?.useMlock ?? defaultOptions.useMlock,
      numThread: options?.numThread ?? defaultOptions.numThread,
    ),
  );
}

/// Extension on [List<Tool>] to convert to Ollama SDK tool list.
extension OllamaToolListMapper on List<Tool> {
  /// Converts this list of [Tool]s to a list of Ollama SDK [o.ToolDefinition]s.
  List<o.ToolDefinition> toOllamaTools() => map(
    (tool) => o.ToolDefinition(
      type: o.ToolType.function,
      function: o.ToolFunction(
        name: tool.name,
        description: tool.description,
        parameters: Map<String, dynamic>.from(tool.inputSchema.value),
      ),
    ),
  ).toList(growable: false);
}

/// Extension on [List<Message>] to convert messages to Ollama SDK messages.
extension MessageListMapper on List<ChatMessage> {
  /// Converts this list of [ChatMessage]s to a list of Ollama SDK
  /// [o.ChatMessage]s.
  ///
  /// ThinkingPart is implicitly filtered out since only TextPart content
  /// is extracted for the message text.
  List<o.ChatMessage> toMessages() {
    _logger.fine('Converting $length messages to Ollama format');

    return map(_mapMessage).expand((msg) => msg).toList(growable: false);
  }

  List<o.ChatMessage> _mapMessage(ChatMessage message) {
    switch (message.role) {
      case ChatMessageRole.system:
        return [o.ChatMessage.system(_extractTextContent(message))];
      case ChatMessageRole.user:
        // Check if this is a tool result message
        final toolResults = message.parts.toolResults;
        if (toolResults.isNotEmpty) {
          // Tool result message
          return toolResults
              .map(
                (p) => o.ChatMessage.tool(
                  // ignore: avoid_dynamic_calls
                  ToolResultHelpers.serialize(p.result),
                ),
              )
              .toList();
        } else {
          return _mapUserMessage(message);
        }
      case ChatMessageRole.model:
        return _mapModelMessage(message);
    }
  }

  List<o.ChatMessage> _mapUserMessage(ChatMessage message) {
    final textParts = message.parts.whereType<TextPart>().toList();
    final dataParts = message.parts.whereType<DataPart>().toList();

    if (dataParts.isEmpty) {
      // Text-only message
      final text = message.parts.text;
      return [o.ChatMessage.user(text)];
    } else if (textParts.length == 1 && dataParts.isNotEmpty) {
      // Single text with images (Ollama's preferred format)
      return [
        o.ChatMessage.user(
          textParts.first.text,
          images: dataParts
              .map((p) => base64Encode(p.bytes))
              .toList(growable: false),
        ),
      ];
    } else {
      // Multiple parts - map each separately
      return message.parts
          .map((part) {
            if (part is TextPart) {
              return o.ChatMessage.user(part.text);
            } else if (part is DataPart) {
              return o.ChatMessage.user(base64Encode(part.bytes));
            }
            return null;
          })
          .nonNulls
          .toList(growable: false);
    }
  }

  List<o.ChatMessage> _mapModelMessage(ChatMessage message) {
    final textContent = _extractTextContent(message);
    final toolCalls = message.parts.toolCalls;

    return [
      o.ChatMessage.assistant(
        textContent,
        toolCalls: toolCalls.isNotEmpty
            ? toolCalls
                  .map(
                    (p) => o.ToolCall(
                      function: o.ToolCallFunction(
                        name: p.toolName,
                        arguments: p.arguments ?? {},
                      ),
                    ),
                  )
                  .toList(growable: false)
            : null,
      ),
    ];
  }

  String _extractTextContent(ChatMessage message) => message.parts.text;
}

/// Converts an [o.ChatResponse] to a [ChatResult].
///
/// Uses [o.ChatResponse] instead of [o.ChatStreamEvent] because
/// [o.ChatResponse] preserves usage fields (`promptEvalCount`, `evalCount`)
/// that the Ollama API includes in the final streaming chunk but
/// [o.ChatStreamEvent] drops.
ChatResult<ChatMessage> chatResponseToChatResult(o.ChatResponse response) {
  _logger.fine('Converting Ollama chat response to ChatResult');
  final parts = <Part>[];

  final messageContent = response.message?.content ?? '';
  final messageThinking = response.message?.thinking;
  final messageToolCalls = response.message?.toolCalls;

  // Add text content
  if (messageContent.isNotEmpty) {
    parts.add(TextPart(messageContent));
  }

  // Add tool calls
  if (messageToolCalls != null) {
    for (var i = 0; i < messageToolCalls.length; i++) {
      final toolCall = messageToolCalls[i];
      if (toolCall.function != null) {
        // Generate a unique ID for this tool call
        final toolId = ToolIdHelpers.generateToolCallId(
          toolName: toolCall.function!.name,
          providerHint: 'ollama',
          arguments: toolCall.function!.arguments,
          index: i,
        );
        _logger.fine(
          'Generated tool ID: $toolId for tool: ${toolCall.function!.name}',
        );
        parts.add(
          ToolPart.call(
            callId: toolId,
            toolName: toolCall.function!.name,
            arguments: toolCall.function!.arguments,
          ),
        );
      }
    }
  }

  final responseMessage = ChatMessage(
    role: ChatMessageRole.model,
    parts: parts,
  );

  // Thinking content is passed via the thinking field on ChatResult
  final thinking = messageThinking != null && messageThinking.isNotEmpty
      ? messageThinking
      : null;

  // Convert Ollama token counts to usage
  // Only provide usage when done=true (final chunk)
  final isDone = response.done ?? false;
  final promptEvalCount = response.promptEvalCount;
  final evalCount = response.evalCount;
  final usage = isDone && (promptEvalCount != null || evalCount != null)
      ? LanguageModelUsage(
          promptTokens: promptEvalCount,
          responseTokens: evalCount,
          totalTokens: promptEvalCount != null && evalCount != null
              ? promptEvalCount + evalCount
              : promptEvalCount ?? evalCount,
        )
      : null;

  if (usage != null) {
    _logger.fine(
      'Ollama usage: ${usage.promptTokens}/${usage.responseTokens}'
      '/${usage.totalTokens}',
    );
  }

  return ChatResult<ChatMessage>(
    output: responseMessage,
    messages: [responseMessage],
    finishReason: isDone ? FinishReason.stop : FinishReason.unspecified,
    thinking: thinking,
    metadata: {
      'model': response.model,
      'created_at': response.createdAt,
      'done': response.done,
      'total_duration': response.totalDuration,
      'load_duration': response.loadDuration,
      'prompt_eval_count': promptEvalCount,
      'prompt_eval_duration': response.promptEvalDuration,
      'eval_count': evalCount,
      'eval_duration': response.evalDuration,
    },
    usage: usage,
  );
}
