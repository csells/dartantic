import '../../platform/platform.dart' as platform;
import '../providers.dart';

/// Manages the mapping between provider family names and provider factories.
///
/// Provides a registry of available AI model providers and methods to create
/// provider instances based on settings.
class ProviderTable {
  /// Map of provider family names to provider factory functions.
  ///
  /// Used to look up the appropriate provider factory when creating providers.
  static final primaryProviders = <String, ProviderFactory>{
    'openai':
        (settings) => OpenAiProvider(
          alias: settings.providerAlias,
          modelName: settings.modelName,
          embeddingModelName: settings.embeddingModelName,
          apiKey: settings.apiKey,
          baseUrl: settings.baseUrl,
          temperature: settings.temperature,
          caps: ProviderCaps.all,
        ),
    'openrouter':
        (settings) => OpenAiProvider(
          alias: settings.providerAlias ?? 'openrouter',
          modelName: settings.modelName,
          embeddingModelName: settings.embeddingModelName,
          apiKey: settings.apiKey ?? platform.getEnv('OPENROUTER_API_KEY'),
          baseUrl:
              settings.baseUrl ?? Uri.parse('https://openrouter.ai/api/v1'),
          temperature: settings.temperature,
          caps: ProviderCaps.allExcept([ProviderCaps.embeddings]),
        ),
    // waiting on https://github.com/davidmigloz/langchain_dart/issues/726
    // 'gemini-compat':
    //     // we're using the OpenAI-compatible Gemini API, but we still have to
    //     // use Google model names and API keys
    //     (settings) => OpenAiProvider(
    //       alias: settings.providerAlias,
    //       modelName: settings.modelName ?? GeminiProvider.defaultModelName,
    //       embeddingModelName:
    //           settings.embeddingModelName ??
    //           GeminiProvider.defaultEmbeddingModelName,
    //       apiKey: settings.apiKey ??
    //                platform.getEnv(GeminiProvider.apiKeyName),
    //       baseUrl:
    //           settings.baseUrl ??
    //           Uri.parse(
    //             'https://generativelanguage.googleapis.com/v1beta/openai',
    //           ),
    //       temperature: settings.temperature,
    //       caps: ProviderCaps.all,
    //     ),
    'google': (settings) {
      if (settings.baseUrl != null) {
        throw ArgumentError('Google provider does not support baseUrl');
      }

      return GeminiProvider(
        alias: settings.providerAlias,
        modelName: settings.modelName,
        embeddingModelName: settings.embeddingModelName,
        apiKey: settings.apiKey,
        temperature: settings.temperature,
      );
    },
  };

  /// Aliases for provider names to support different naming conventions.
  static const providerAliases = {
    'googleai': 'google',
    'google-gla': 'google',
    'gemini': 'google',
  };

  /// Creates a provider instance for the given settings.
  ///
  /// Uses the [settings providerName] to look up the appropriate provider
  /// factory in the [primaryProviders] map and creates a provider with the
  /// specified settings. Throws an [ArgumentError] if the provider family is
  /// not supported.
  static Provider providerFor(ProviderSettings settings) {
    final providerName =
        providerAliases[settings.providerName] ?? settings.providerName;
    final providerFactory = primaryProviders[providerName];
    if (providerFactory != null) return providerFactory(settings);
    throw ArgumentError('Unsupported provider: $settings.providerName');
  }
}
