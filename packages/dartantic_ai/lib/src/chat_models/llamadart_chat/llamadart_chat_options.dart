import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';

import 'model_resolvers.dart';

/// Options for Llamadart chat models
@immutable
class LlamadartChatOptions extends ChatModelOptions {
  /// Creates [LlamadartChatOptions]
  const LlamadartChatOptions({
    this.maxTokens,
    this.temperature,
    this.topP,
    this.resolver,
  });

  /// Maximum number of tokens to generate
  final int? maxTokens;

  /// Temperature for sampling (0.0 to 1.0)
  final double? temperature;

  /// Top-p sampling parameter
  final double? topP;

  /// Model resolver for resolving model names to paths/URLs
  final ModelResolver? resolver;
}
