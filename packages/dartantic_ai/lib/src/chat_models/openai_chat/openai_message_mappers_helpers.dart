import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:openai_dart/openai_dart.dart'
    hide ChatMessage, FinishReason, Tool;
import 'package:openai_dart/openai_dart.dart' as oai show FinishReason, Tool;

import '../../shared/openai_utils.dart';
import 'openai_chat_options.dart';
import 'openai_message_mappers.dart';

/// Maps OpenAI finish reason to our FinishReason enum
FinishReason mapFinishReason(oai.FinishReason? reason) {
  if (reason == null) return FinishReason.unspecified;

  return switch (reason) {
    oai.FinishReason.stop => FinishReason.stop,
    oai.FinishReason.length => FinishReason.length,
    oai.FinishReason.toolCalls => FinishReason.toolCalls,
    oai.FinishReason.contentFilter => FinishReason.contentFilter,
    oai.FinishReason.functionCall => FinishReason.toolCalls,
  };
}

/// Maps OpenAI usage to our LanguageModelUsage
LanguageModelUsage mapUsage(Usage? usage) {
  if (usage == null) return const LanguageModelUsage();

  return LanguageModelUsage(
    promptTokens: usage.promptTokens,
    responseTokens: usage.completionTokens,
    totalTokens: usage.totalTokens,
  );
}

/// Creates OpenAI ResponseFormat from Schema
ResponseFormat? _createResponseFormat(
  Schema? outputSchema, {
  bool strictSchema = true,
}) {
  if (outputSchema == null) return null;

  return ResponseFormat.jsonSchema(
    name: 'output_schema',
    description: 'Generated response following the provided schema',
    schema: OpenAIUtils.prepareSchemaForOpenAI(
      Map<String, dynamic>.from(outputSchema.value),
      strict: strictSchema,
    ),
    strict: strictSchema,
  );
}

/// Creates a ChatCompletionRequest from the given input
ChatCompletionCreateRequest createChatCompletionRequest(
  List<ChatMessage> messages, {
  required String modelName,
  required OpenAIChatOptions defaultOptions,
  List<Tool>? tools,
  double? temperature,
  OpenAIChatOptions? options,
  Schema? outputSchema,
  bool strictSchema = true,
}) => ChatCompletionCreateRequest(
  model: modelName,
  messages: messages.toOpenAIMessages(),
  tools: tools
      ?.map(
        (tool) => oai.Tool.function(
          name: tool.name,
          description: tool.description,
          // OpenAI requires 'properties' field on object schemas, even if
          // empty
          parameters: OpenAIUtils.prepareSchemaForOpenAI(
            Map<String, dynamic>.from(tool.inputSchema.value),
          ),
        ),
      )
      .toList(),
  toolChoice: null,
  responseFormat:
      _createResponseFormat(outputSchema, strictSchema: strictSchema) ??
      options?.responseFormat ??
      defaultOptions.responseFormat,
  maxCompletionTokens: options?.maxTokens ?? defaultOptions.maxTokens,
  n: options?.n ?? defaultOptions.n,
  temperature:
      temperature ?? options?.temperature ?? defaultOptions.temperature,
  topP: options?.topP ?? defaultOptions.topP,
  stop: options?.stop ?? defaultOptions.stop,
  streamOptions: options?.streamOptions ?? defaultOptions.streamOptions,
  user: options?.user ?? defaultOptions.user,
  frequencyPenalty:
      options?.frequencyPenalty ?? defaultOptions.frequencyPenalty,
  logitBias: options?.logitBias ?? defaultOptions.logitBias,
  logprobs: options?.logprobs ?? defaultOptions.logprobs,
  presencePenalty: options?.presencePenalty ?? defaultOptions.presencePenalty,
  seed: options?.seed ?? defaultOptions.seed,
  topLogprobs: options?.topLogprobs ?? defaultOptions.topLogprobs,
  reasoningEffort: options?.reasoningEffort ?? defaultOptions.reasoningEffort,
  verbosity: options?.verbosity ?? defaultOptions.verbosity,
  prediction: options?.prediction ?? defaultOptions.prediction,
  modalities: options?.modalities ?? defaultOptions.modalities,
  audio: options?.audio ?? defaultOptions.audio,
  webSearchOptions:
      options?.webSearchOptions ?? defaultOptions.webSearchOptions,
  store: options?.store ?? defaultOptions.store,
  metadata: options?.metadata ?? defaultOptions.metadata,
  promptCacheKey: options?.promptCacheKey ?? defaultOptions.promptCacheKey,
  promptCacheRetention:
      options?.promptCacheRetention ?? defaultOptions.promptCacheRetention,
  safetyIdentifier:
      options?.safetyIdentifier ?? defaultOptions.safetyIdentifier,
);

/// Helper class to track streaming tool call state
class StreamingToolCall {
  /// Creates a new streaming tool call.
  StreamingToolCall({
    required this.id,
    required this.name,
    this.argumentsJson = '',
  });

  /// The ID of the tool call.
  String id;

  /// The name of the tool.
  String name;

  /// The arguments of the tool call.
  String argumentsJson;
}
