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
  /// Controls logging output from the underlying llama.cpp library.
  ///
  /// **Native Platforms (iOS, Android, macOS, Linux, Windows)**:
  /// - `LlamaLogLevel.none` - Completely suppresses all logging (default)
  /// - `LlamaLogLevel.error`, `warn`, `info`, `debug` - All enable full
  ///   logging to stderr. These levels are treated identically on native
  ///   platforms as an on/off toggle for stability. Granular filtering is
  ///   not supported.
  ///
  /// **Web Platform**:
  /// - Full granular filtering supported: `none`, `debug`, `info`, `warn`,
  ///   `error`
  ///
  /// When null (default), uses `LlamaLogLevel.none` to suppress all output.
  ///
  /// **Note**: On native platforms, llamadart writes logs directly to
  /// stderr, bypassing Dart's logging system. This is a limitation of the
  /// llama.cpp native library.
  final LlamaLogLevel? logLevel;
}
