import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

/// Message accumulator that handles standard streaming protocols.
///
/// This implementation:
/// - Concatenates text parts
/// - Merges tool calls with the same ID
/// - Preserves all other parts as-is
/// - Consolidates multiple TextParts into a single part
class MessageAccumulator {
  /// Creates a new MessageAccumulator
  const MessageAccumulator();

  /// Logger for accumulator.message operations.
  static final Logger _logger = Logger('dartantic.accumulator.message');

  /// Provider hint for debugging and logging.
  String get providerHint => 'default';

  /// Accumulates a new chunk into the existing message.
  ///
  /// This method handles the logic for merging streaming chunks, including:
  /// - Text concatenation
  /// - Tool call merging (for providers that stream tool calls incrementally)
  /// - Metadata merging
  /// - Part deduplication
  ///
  /// Returns a new ChatMessage with the accumulated content.
  ChatMessage accumulate(ChatMessage accumulated, ChatMessage newChunk) {
    if (accumulated.parts.isEmpty) {
      return newChunk;
    }

    _logger.fine('Accumulating message chunk: ${newChunk.parts.length} parts');

    // Collect parts by type for merging
    final accumulatedParts = <Part>[...accumulated.parts];

    for (final newPart in newChunk.parts) {
      if (newPart is ToolPart && newPart.kind == ToolPartKind.call) {
        // Find existing tool call with same ID for merging
        final existingIndex = accumulatedParts.indexWhere(
          (part) =>
              part is ToolPart &&
              part.kind == ToolPartKind.call &&
              part.callId.isNotEmpty &&
              part.callId == newPart.callId,
        );

        if (existingIndex != -1) {
          // Merge with existing tool call
          final existingToolCall = accumulatedParts[existingIndex] as ToolPart;
          final mergedToolCall = ToolPart.call(
            callId: newPart.callId,
            toolName: newPart.toolName.isNotEmpty
                ? newPart.toolName
                : existingToolCall.toolName,
            arguments: newPart.arguments?.isNotEmpty ?? false
                ? newPart.arguments!
                : existingToolCall.arguments ?? {},
          );
          accumulatedParts[existingIndex] = mergedToolCall;
        } else {
          // Add new tool call
          accumulatedParts.add(newPart);
        }
      } else {
        // Add other parts as-is (TextPart, DataPart, etc.)
        accumulatedParts.add(newPart);
      }
    }

    // Merge metadata from both messages
    final mergedMetadata = <String, dynamic>{
      ...accumulated.metadata,
      ...newChunk.metadata,
    };
    _logger.fine(
      'Merging metadata; accumulated keys=${accumulated.metadata.keys}, '
      'new keys=${newChunk.metadata.keys}',
    );

    return ChatMessage(
      role: accumulated.role,
      parts: accumulatedParts,
      metadata: mergedMetadata,
    );
  }

  /// Consolidates the accumulated message parts for final output.
  ///
  /// This method performs final processing on the accumulated message:
  /// - Consolidates multiple TextParts into a single TextPart
  /// - Consolidates multiple ThinkingParts into a single ThinkingPart
  /// - Orders parts appropriately
  /// - Cleans up any streaming artifacts
  ///
  /// Returns a ChatMessage ready for storage in conversation history.
  ChatMessage consolidate(ChatMessage accumulated) {
    _logger.fine(
      'Consolidating accumulated message: ${accumulated.parts.length} parts',
    );
    _logger.fine('Consolidated metadata keys: ${accumulated.metadata.keys}');

    // Separate parts by type for consolidation
    final textParts = accumulated.parts.whereType<TextPart>().toList();
    final thinkingParts = accumulated.parts.whereType<ThinkingPart>().toList();
    final otherParts = accumulated.parts
        .where((part) => part is! TextPart && part is! ThinkingPart)
        .toList();

    final finalParts = <Part>[];

    // Add consolidated text as a single TextPart (if any)
    if (textParts.isNotEmpty) {
      final consolidatedText = textParts.map((p) => p.text).join();
      if (consolidatedText.isNotEmpty) {
        finalParts.add(TextPart(consolidatedText));
      }
    }

    // Add consolidated thinking as a single ThinkingPart (if any)
    if (thinkingParts.isNotEmpty) {
      final consolidatedThinking = thinkingParts.map((p) => p.text).join();
      if (consolidatedThinking.isNotEmpty) {
        finalParts.add(ThinkingPart(consolidatedThinking));
      }
    }

    // Add all other parts (already properly merged)
    finalParts.addAll(otherParts);

    // Create final message with consolidated parts
    return ChatMessage(
      role: accumulated.role,
      parts: finalParts,
      metadata: accumulated.metadata,
    );
  }
}
