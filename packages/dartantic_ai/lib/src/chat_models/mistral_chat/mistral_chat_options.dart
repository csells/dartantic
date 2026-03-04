import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';
import 'package:mistralai_dart/mistralai_dart.dart'
    show MistralPromptMode, Prediction, StopSequence;

/// Options to pass into MistralAI.
@immutable
class MistralChatModelOptions extends ChatModelOptions {
  /// Creates a new mistral ai options instance.
  const MistralChatModelOptions({
    this.topP,
    this.maxTokens,
    this.safePrompt,
    this.randomSeed,
    this.presencePenalty,
    this.frequencyPenalty,
    this.stop,
    this.n,
    this.parallelToolCalls,
    this.prediction,
    this.promptMode,
  });

  /// Nucleus sampling, where the model considers the results of the tokens
  /// with `top_p` probability mass. So 0.1 means only the tokens comprising
  /// the top 10% probability mass are considered.
  ///
  /// We generally recommend altering this or `temperature` but not both.
  final double? topP;

  /// The maximum number of tokens to generate in the completion.
  ///
  /// The token count of your prompt plus `max_tokens` cannot exceed the
  /// model's context length.
  final int? maxTokens;

  /// Whether to inject a safety prompt before all conversations.
  final bool? safePrompt;

  /// The seed to use for random sampling.
  /// If set, different calls will generate deterministic results.
  final int? randomSeed;

  /// Presence penalty (-2.0 to 2.0). Positive values penalize new tokens
  /// based on whether they appear in the text so far.
  final double? presencePenalty;

  /// Frequency penalty (-2.0 to 2.0). Positive values penalize new tokens
  /// based on their existing frequency in the text so far.
  final double? frequencyPenalty;

  /// Stop sequences.
  final StopSequence? stop;

  /// Number of completions to generate.
  final int? n;

  /// Whether to allow parallel tool calls.
  final bool? parallelToolCalls;

  /// Prediction for speculative decoding.
  ///
  /// Supported by mistral-large-2411, codestral-latest.
  final Prediction? prediction;

  /// Prompt mode for reasoning models.
  final MistralPromptMode? promptMode;
}
