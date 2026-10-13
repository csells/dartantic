import 'package:dartantic_interface/dartantic_interface.dart';

import '../chat_models/openai_chat/openai_chat_options.dart';
import '../embeddings_models/openai_embeddings/openai_embeddings_model_options.dart';
import '../platform/platform.dart';
import 'openai_provider.dart';

/// Provider for xAI Grok via the OpenAI-compatible chat completions API.
class XAIProvider extends OpenAIProvider {
  /// Creates a new xAI provider instance.
  XAIProvider({String? apiKey, super.headers, super.httpClient})
    : super(
        apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
        apiKeyName: defaultApiKeyName,
        name: providerName,
        displayName: providerDisplayName,
        defaultModelNames: const {ModelKind.chat: defaultChatModel},
        baseUrl: defaultBaseUrl,
        aliases: const ['grok'],
      );

  /// Canonical provider name.
  static const providerName = 'xai';

  /// Human-friendly provider name.
  static const providerDisplayName = 'xAI';

  /// Default chat model identifier.
  static const defaultChatModel = 'grok-4-1-fast-non-reasoning';

  /// Environment variable used to read the API key.
  static const defaultApiKeyName = 'XAI_API_KEY';

  /// Default base URL for the xAI API.
  static final defaultBaseUrl = Uri.parse('https://api.x.ai/v1');

  @override
  ChatModel<OpenAIChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OpenAIChatOptions? options,
  }) {
    if (temperature != null || options?.temperature != null) {
      throw UnsupportedError(
        '$providerDisplayName provider does not support temperature. '
        'Remove temperature and rely on model defaults.',
      );
    }
    return super.createChatModel(
      name: name,
      tools: tools,
      temperature: temperature,
      enableThinking: enableThinking,
      options: options,
    );
  }

  @override
  EmbeddingsModel<OpenAIEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    OpenAIEmbeddingsModelOptions? options,
  }) {
    throw UnsupportedError(
      '$providerDisplayName provider does not currently support embeddings in '
      'dartantic.',
    );
  }
}
