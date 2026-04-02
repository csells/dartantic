import 'package:googleai_dart/googleai_dart.dart' as ga;

import 'google_chat_options.dart';

/// Builds [ga.ThinkingConfig] for Gemini generate-content from Dartantic
/// options.
///
/// [thinkingLevel] is sent whenever it is set; it controls reasoning depth on
/// Gemini 3+ and does not require [enableThinking]. When [enableThinking] is
/// also true, [ga.ThinkingConfig.includeThoughts] is set so thought summaries
/// are returned (see Gemini thinking docs).
///
/// The [thinkingBudgetTokens] path only applies when [enableThinking] is true
/// (Gemini 2.5-style budget). When [enableThinking] is false and no level is
/// set, returns null.
///
/// Throws [ArgumentError] if both [thinkingLevel] and
/// [thinkingBudgetTokens] are non-null, because the API does not allow
/// combining thinking level (Gemini 3+) with thinking budget (Gemini
/// 2.5-style).
ga.ThinkingConfig? buildGoogleGenerationThinkingConfig({
  required bool enableThinking,
  int? thinkingBudgetTokens,
  GoogleThinkingLevel? thinkingLevel,
}) {
  if (thinkingLevel != null && thinkingBudgetTokens != null) {
    throw ArgumentError(
      'GoogleChatModelOptions: cannot set both thinkingLevel (Gemini 3+) and '
      'thinkingBudgetTokens (Gemini 2.5-style thinking budget). Use one or '
      'the other.',
    );
  }

  if (thinkingLevel != null) {
    final gaLevel = switch (thinkingLevel) {
      GoogleThinkingLevel.minimal => ga.ThinkingLevel.minimal,
      GoogleThinkingLevel.low => ga.ThinkingLevel.low,
      GoogleThinkingLevel.medium => ga.ThinkingLevel.medium,
      GoogleThinkingLevel.high => ga.ThinkingLevel.high,
    };
    return ga.ThinkingConfig(
      includeThoughts: enableThinking ? true : null,
      thinkingLevel: gaLevel,
    );
  }

  if (!enableThinking) return null;

  final thinkingBudget = thinkingBudgetTokens ?? -1;
  return ga.ThinkingConfig(
    includeThoughts: true,
    thinkingBudget: thinkingBudget,
  );
}
