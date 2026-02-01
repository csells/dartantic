import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:llamadart/llamadart.dart';

/// Extension to convert Dartantic messages to Llamadart format
extension LlamadartMessageListMapper on List<ChatMessage> {
  /// Converts Dartantic [ChatMessage] list to llamadart [LlamaChatMessage] list
  ///
  /// CRITICAL: Asserts that no ThinkingPart is present in messages.
  /// ThinkingPart is model-generated output only and must never be sent to LLM.
  List<LlamaChatMessage> toLlamaMessages() {
    // CRITICAL: Assert ThinkingPart never sent to LLM
    assert(
      !any((m) => m.parts.any((p) => p is ThinkingPart)),
      'ThinkingPart must never be sent to the LLM. '
      'Thinking content is model-generated output only.',
    );

    return map((msg) {
      final role = switch (msg.role) {
        ChatMessageRole.system => 'system',
        ChatMessageRole.user => 'user',
        ChatMessageRole.model => 'assistant',
      };

      // Extract text only - skip ToolPart (not supported by llamadart)
      final content = msg.parts.text;

      return LlamaChatMessage(role: role, content: content);
    }).toList(growable: false);
  }
}
