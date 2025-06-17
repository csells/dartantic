import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import 'provider_caps.dart';

/// Abstract interface for AI model providers.
///
/// Providers are responsible for creating model instances with appropriate
/// configuration and serving as a factory for specific model implementations.
abstract class Provider {
  /// The provider name for this provider, e.g. "openai"
  String get name;

  /// The alias for this provider, e.g. "openrouter"
  String? get alias;

  /// Creates a model instance with the specified settings.
  ///
  /// Uses the provider's configuration along with the given [settings]
  /// to instantiate and configure a model implementation.
  Model createModel(ModelSettings settings);

  /// The capabilities of this provider.
  Set<ProviderCaps> get caps;
}
