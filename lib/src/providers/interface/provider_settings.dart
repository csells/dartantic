/// Settings used to configure a provider.
///
/// Contains the necessary information to create and configure a provider
/// instance for a specific AI model family and model.
class ProviderSettings {
  /// Creates a new [ProviderSettings] instance.
  ///
  /// The [modelName] specifies which model to use within that family for text
  /// generation. The [embeddingModelName] specifies which model to use for
  /// embeddings within that family. The [apiKey] is an optional API key for
  /// authentication with the provider. The [extendedProperties] allows
  /// provider-specific configuration options.
  ProviderSettings({
    required this.modelName,
    required this.embeddingModelName,
    required this.apiKey,
    required this.baseUrl,
    this.extendedProperties,
  });

  /// The specific model name to use within the provider family for text
  /// generation.
  final String? modelName;

  /// The specific model name to use within the provider family for embeddings.
  final String? embeddingModelName;

  /// The API key for authentication with the provider.
  final String? apiKey;

  /// The base URL for the provider.
  final Uri? baseUrl;

  /// Extended properties for provider-specific configuration options.
  final Map<String, dynamic>? extendedProperties;
}
