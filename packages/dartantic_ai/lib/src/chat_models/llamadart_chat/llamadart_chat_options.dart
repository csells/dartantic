import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:llamadart/llamadart.dart' show LlamaLogLevel;
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
    this.logLevel,
  });

  /// Maximum number of tokens to generate
  final int? maxTokens;

  /// Temperature for sampling (0.0 to 1.0)
  final double? temperature;

  /// Top-p sampling parameter
  final double? topP;

  /// Model resolver for resolving model names to paths/URLs
  final ModelResolver? resolver;

  /// Log level for the llamadart native engine
  ///
  /// Controls the verbosity of logging output from the underlying llama.cpp
  /// library. Available levels:
  /// - `LlamaLogLevel.none` - No logging output (default)
  /// - `LlamaLogLevel.error` - Critical error messages only
  /// - `LlamaLogLevel.warn` - Warnings about potential issues
  /// - `LlamaLogLevel.info` - General execution information
  /// - `LlamaLogLevel.debug` - Detailed debug information
  ///
  /// When null (default), uses `LlamaLogLevel.none` to minimize output.
  ///
  /// **Note**: Llamadart's native library writes logs directly to stderr/stdout,
  /// bypassing Dart's logging system.
  final LlamaLogLevel? logLevel;
}
