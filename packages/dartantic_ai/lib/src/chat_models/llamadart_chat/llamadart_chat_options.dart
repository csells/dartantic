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
    this.verbose = false,
  });

  /// Maximum number of tokens to generate
  final int? maxTokens;

  /// Temperature for sampling (0.0 to 1.0)
  final double? temperature;

  /// Top-p sampling parameter
  final double? topP;

  /// Model resolver for resolving model names to paths/URLs
  final ModelResolver? resolver;

  /// Enable verbose logging from the llamadart engine
  ///
  /// When true, sets the native llama.cpp log level to INFO, showing detailed
  /// diagnostic information including model loading, tensor operations, and
  /// GPU/Metal configuration.
  ///
  /// When false (default), sets the log level to NONE to minimize output.
  ///
  /// **Note**: Llamadart's native library writes logs directly to stderr/stdout,
  /// bypassing Dart's logging system. Due to timing of native initialization,
  /// some output may appear regardless of this setting. The verbose option
  /// controls the log level but cannot guarantee complete suppression of all
  /// native library output.
  final bool verbose;
}
