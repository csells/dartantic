import 'package:dartantic_interface/dartantic_interface.dart';

import '../embeddings_models/openai_embeddings/openai_embeddings_model_options.dart';
import '../platform/platform.dart';
import 'openai_provider.dart';

/// Provider for xAI Grok via the OpenAI-compatible chat completions API.
class XAIProvider extends OpenAIProvider {
  /// Creates a new xAI provider instance.
  XAIProvider({String? apiKey, super.headers})
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
