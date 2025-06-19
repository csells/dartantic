import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import 'provider_caps.dart';

/// Abstract interface for AI model providers.
///
/// Providers are responsible for creating model instances with appropriate
/// configuration and serving as a factory for specific model implementations.
/// Each provider encapsulates the logic for communicating with a specific
/// AI service (e.g., OpenAI, Google Gemini) and creating models that can
/// execute prompts and handle responses.
abstract class Provider {
  /// The provider name for this provider, e.g. "openai"
  ///
  /// This is used to identify the provider type and should be unique
  /// across all provider implementations.
  String get name;

  /// The alias for this provider, e.g. "openrouter"
  ///
  /// This allows providers to be referenced by an alternative name,
  /// useful for providers that act as proxies or wrappers for other services.
  String? get alias;

  /// The name referenced in the provider table, i.e. either an alias or the
  /// name, depending on which is available.
  String get handle => alias ?? name;

  /// Creates a model instance with the specified settings.
  ///
  /// Uses the provider's configuration along with the given [settings]
  /// to instantiate and configure a model implementation. The returned
  /// model can be used to run prompts, create embeddings, and other
  /// AI operations supported by the provider.
  Model createModel(ModelSettings settings);

  /// The capabilities of this provider.
  ///
  /// Indicates what features this provider supports, such as chat completion,
  /// embeddings, image generation, etc. This helps determine if a provider
  /// can be used for specific use cases.
  Set<ProviderCaps> get caps;

  /// Lists all available models from this provider.
  ///
  /// Returns information about models that can be used with this provider,
  /// including their names, types, and capabilities. This is useful for
  /// discovering what models are available and their characteristics.
  Future<Iterable<ModelInfo>> listModels();
}

/// The type of AI model based on its primary capability.
enum ModelKind {
  /// Chat completion models for conversational AI
  chat,

  /// Image generation or vision models
  image,

  /// Text embedding models for semantic similarity
  embedding,

  /// Audio processing models (speech-to-text, etc.)
  audio,

  /// Text-to-speech models
  tts,

  /// Other specialized model types
  other,
}

/// Information about an available AI model.
///
/// Contains metadata about a model that can be used to make informed
/// decisions about which model to use for specific tasks.
class ModelInfo {
  /// Creates a new [ModelInfo] instance.
  const ModelInfo({
    required this.providerName,
    required this.name,
    required this.kind,
  });

  /// The name of the provider that offers this model.
  final String providerName;

  /// The name or identifier of the model.
  final String name;

  /// The type of model based on its primary capability.
  final Set<ModelKind> kind;
}
