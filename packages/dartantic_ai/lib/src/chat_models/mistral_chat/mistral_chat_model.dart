import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mistralai_dart/mistralai_dart.dart'
    hide ChatMessage, FinishReason, Tool;

import 'mistral_chat_options.dart';
import 'mistral_message_mappers.dart';

/// Wrapper around [Mistral AI](https://docs.mistral.ai) Chat Completions API.
class MistralChatModel extends ChatModel<MistralChatModelOptions> {
  /// Creates a [MistralChatModel] instance.
  MistralChatModel({
    required String name,
    required String apiKey,
    super.tools,
    super.temperature,
    MistralChatModelOptions? defaultOptions,
    Uri? baseUrl,
    http.Client? client,
    Map<String, String>? headers,
  }) : _client = MistralClient(
         config: MistralConfig(
           authProvider: ApiKeyProvider(apiKey),
           baseUrl: baseUrl?.toString() ?? 'https://api.mistral.ai',
           defaultHeaders: headers ?? const {},
         ),
         httpClient: client,
       ),
       super(
         name: name,
         defaultOptions: defaultOptions ?? const MistralChatModelOptions(),
       ) {
    _logger.info(
      'Creating Mistral model: $name '
      'with ${tools?.length ?? 0} tools, temp: $temperature',
    );
  }

  static final Logger _logger = Logger('dartantic.chat.models.mistral');

  final MistralClient _client;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    MistralChatModelOptions? options,
    Schema? outputSchema,
  }) {
    _logger.info(
      'Starting Mistral chat stream with ${messages.length} messages for '
      'model: $name',
    );
    var chunkCount = 0;

    final request = createChatCompletionRequest(
      messages,
      modelName: name,
      tools: tools,
      temperature: temperature,
      options: options,
      defaultOptions: defaultOptions,
      outputSchema: outputSchema,
    );

    return _client.chat.createStream(request: request).map((completion) {
      chunkCount++;
      _logger.fine('Received Mistral stream chunk $chunkCount');
      final result = completion.toChatResult();
      return ChatResult<ChatMessage>(
        id: result.id,
        output: result.output,
        messages: result.messages,
        finishReason: result.finishReason,
        metadata: result.metadata,
        usage: result.usage,
      );
    });
  }

  /// Creates a GenerateCompletionRequest from the given input.
  ChatCompletionRequest createChatCompletionRequest(
    List<ChatMessage> messages, {
    required String modelName,
    required MistralChatModelOptions defaultOptions,
    List<Tool>? tools,
    double? temperature,
    MistralChatModelOptions? options,
    Schema? outputSchema,
  }) => ChatCompletionRequest(
    model: modelName,
    messages: messages.toChatMessages(),
    temperature: temperature,
    topP: options?.topP ?? defaultOptions.topP,
    maxTokens: options?.maxTokens ?? defaultOptions.maxTokens,
    safePrompt: options?.safePrompt ?? defaultOptions.safePrompt,
    randomSeed: options?.randomSeed ?? defaultOptions.randomSeed,
    tools: tools?.toMistralTools(),
    stream: true,
    presencePenalty: options?.presencePenalty ?? defaultOptions.presencePenalty,
    frequencyPenalty:
        options?.frequencyPenalty ?? defaultOptions.frequencyPenalty,
    stop: options?.stop ?? defaultOptions.stop,
    n: options?.n ?? defaultOptions.n,
    parallelToolCalls:
        options?.parallelToolCalls ?? defaultOptions.parallelToolCalls,
    prediction: options?.prediction ?? defaultOptions.prediction,
    promptMode: options?.promptMode ?? defaultOptions.promptMode,
    responseFormat: outputSchema != null
        ? ResponseFormat.jsonSchema(
            name: 'output',
            schema: Map<String, dynamic>.from(outputSchema.value),
            strict: true,
          )
        : null,
  );

  @override
  void dispose() => _client.close();
}
