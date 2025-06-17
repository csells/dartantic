import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';

/// Abstract interface for AI model providers.
///
/// Providers are responsible for creating model instances with appropriate
/// configuration and serving as a factory for specific model implementations.
abstract class Provider {
  /// The display name for this provider.
  String get displayName;

  /// The alias for this provider.
  String? get alias;

  /// Creates a model instance with the specified settings.
  ///
  /// Uses the provider's configuration along with the given [settings]
  /// to instantiate and configure a model implementation.
  Model createModel(ModelSettings settings);
}
