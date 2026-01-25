import 'package:dartantic_interface/dartantic_interface.dart';

/// Accumulates streaming chat results into a final consolidated result.
///
/// Handles accumulation of output text, messages, metadata, and usage
/// statistics from streaming chunks into a final ChatResult.
class AgentResponseAccumulator {
  /// Creates a new response accumulator.
  AgentResponseAccumulator();

  final List<ChatMessage> _allNewMessages = <ChatMessage>[];
  final StringBuffer _finalOutputBuffer = StringBuffer();
  final StringBuffer _finalThinkingBuffer = StringBuffer();
  final Map<String, dynamic> _accumulatedMetadata = <String, dynamic>{};

  ChatResult<String> _finalResult = ChatResult<String>(
    output: '',
    finishReason: FinishReason.unspecified,
    metadata: const <String, dynamic>{},
    usage: null,
  );

  /// Adds a streaming result chunk to the accumulator.
  void add(ChatResult<String> result) {
    // Accumulate output text
    if (result.output.isNotEmpty) {
      _finalOutputBuffer.write(result.output);
    }

    // Accumulate thinking text
    if (result.thinking != null) {
      _finalThinkingBuffer.write(result.thinking);
    }

    // Accumulate messages, filtering out streaming-only ThinkingPart messages.
    // These are emitted during streaming for real-time display but are
    // duplicated in the consolidated model message. The consolidated message
    // (which has ThinkingPart + TextPart/ToolPart, or ThinkingPart with
    // signature metadata) is what mappers need for multi-turn tool calling.
    for (final message in result.messages) {
      final isStreamingThinkingOnly = message.parts.isNotEmpty &&
          message.parts.every((p) => p is ThinkingPart);
      if (!isStreamingThinkingOnly) {
        _allNewMessages.add(message);
      }
    }

    // Store the latest result for final metadata/usage/finishReason
    _finalResult = result;

    // Merge metadata (preserving response-level info from final chunk)
    for (final entry in result.metadata.entries) {
      _accumulatedMetadata[entry.key] = entry.value;
    }
  }

  /// Builds the final accumulated ChatResult.
  ChatResult<String> buildFinal() {
    final thinking = _finalThinkingBuffer.toString();
    return ChatResult<String>(
      id: _finalResult.id,
      output: _finalOutputBuffer.toString(),
      thinking: thinking.isEmpty ? null : thinking,
      messages: _allNewMessages,
      finishReason: _finalResult.finishReason,
      metadata: _accumulatedMetadata,
      usage: _finalResult.usage,
    );
  }
}
