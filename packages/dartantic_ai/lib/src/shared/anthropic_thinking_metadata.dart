/// Metadata helpers for Anthropic thinking signatures.
///
/// When thinking is enabled and tool calls are present, Anthropic requires
/// the complete ThinkingBlock (including signature) to be preserved in
/// conversation history. The thinking text is stored in ThinkingPart, while
/// the signature is stored in message metadata to avoid duplication.
class AnthropicThinkingMetadata {
  AnthropicThinkingMetadata._();

  /// Metadata key used to store the thinking signature on chat messages.
  static const signatureKey = '_anthropic_thinking_signature';

  /// Extracts the thinking signature from a chat message metadata map.
  static String? getSignature(Map<String, Object?>? metadata) {
    if (metadata == null) return null;
    return metadata[signatureKey] as String?;
  }

  /// Creates metadata containing the thinking signature.
  static Map<String, Object?> buildMetadata({required String signature}) => {
    signatureKey: signature,
  };
}
