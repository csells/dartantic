import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';

import 'firebase_ai_safety_options.dart';

/// Options to pass into the Firebase AI Chat Model.
///
/// Firebase AI uses Gemini models through Firebase.
@immutable
class FirebaseAIChatModelOptions extends ChatModelOptions {
  /// Creates a new Firebase AI chat options instance.
  const FirebaseAIChatModelOptions({
    this.topP,
    this.topK,
    this.candidateCount,
    this.maxOutputTokens,
    this.temperature,
    this.stopSequences,
    this.responseMimeType,
    this.responseSchema,
    this.safetySettings,
    this.enableCodeExecution,
    this.enableThinking,
    this.thinkingBudgetTokens,
  });

  /// The maximum cumulative probability of tokens to consider when sampling.
  final double? topP;

  /// The maximum number of tokens to consider when sampling.
  final int? topK;

  /// Number of generated responses to return.
  final int? candidateCount;

  /// The maximum number of tokens to include in a candidate.
  final int? maxOutputTokens;

  /// Controls the randomness of the output.
  final double? temperature;

  /// Character sequences that will stop output generation.
  final List<String>? stopSequences;

  /// Output response mimetype of the generated candidate text.
  final String? responseMimeType;

  /// Output response schema of the generated candidate text.
  ///
  /// Used when [responseMimeType] is `application/json` to constrain the
  /// model's output to a specific structure.
  final Schema? responseSchema;

  /// Safety settings for blocking unsafe content.
  final List<FirebaseAISafetySetting>? safetySettings;

  /// Enable code execution in the model.
  final bool? enableCodeExecution;

  /// Enables inclusion of model reasoning/thinking content.
  final bool? enableThinking;

  /// The token budget for thinking/reasoning content.
  ///
  /// Set to `-1` for dynamic thinking (model decides). When `null` and
  /// thinking is enabled, defaults to dynamic thinking.
  final int? thinkingBudgetTokens;
}
