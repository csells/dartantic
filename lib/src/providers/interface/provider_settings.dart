import '../../agent/agent.dart';

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
  /// authentication with the provider.
  ProviderSettings({
    required this.modelName,
    required this.embeddingModelName,
    required this.apiKey,
    required this.baseUrl,
    required this.temperature,
    required this.agentMode,
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

  /// The temperature for the provider.
  final double? temperature;

  /// The mode in which the agent will run.
  final AgentMode? agentMode;
}
