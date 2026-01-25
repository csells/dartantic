import 'dart:typed_data';

/// Metadata helpers for Google thinking signatures.
///
/// When thinking is enabled and tool calls are present, Google's Gemini models
/// use thought signatures to preserve reasoning context across tool call
/// boundaries. These signatures are opaque byte arrays that must be stored in
/// message metadata and sent back with subsequent tool calls/results.
class GoogleThinkingMetadata {
  GoogleThinkingMetadata._();

  /// Metadata key used to store thought signatures on chat messages.
  static const signaturesKey = '_google_thought_signatures';

  /// Extracts thought signatures map from chat message metadata.
  ///
  /// Returns an empty map if no signatures are present.
  static Map<String, dynamic> getSignatures(Map<String, dynamic>? metadata) {
    if (metadata == null) return const {};
    return metadata[signaturesKey] as Map<String, dynamic>? ?? const {};
  }

  /// Gets the signature bytes for a specific tool call ID.
  ///
  /// Returns null if no signature exists for the given call ID.
  static Uint8List? getSignatureBytes(
    Map<String, dynamic> signatures,
    String callId,
  ) {
    final sig = signatures[callId] as List<int>?;
    return sig != null ? Uint8List.fromList(sig) : null;
  }

  /// Stores signature bytes for a tool call ID.
  ///
  /// Only stores if the signature is non-empty.
  static void setSignatureBytes(
    Map<String, dynamic> signatures,
    String callId,
    Uint8List bytes,
  ) {
    if (bytes.isNotEmpty) {
      signatures[callId] = bytes.toList();
    }
  }

  /// Creates metadata containing thought signatures.
  ///
  /// Returns an empty map if signatures is empty.
  static Map<String, dynamic> buildMetadata({
    required Map<String, dynamic> signatures,
  }) => signatures.isEmpty ? const {} : {signaturesKey: signatures};
}
