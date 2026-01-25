import '../model/model.dart';
import 'chat_message.dart';

/// Result returned by the Chat Model.
class ChatResult<T extends Object> extends LanguageModelResult<T> {
  /// Creates a new chat result instance.
  ChatResult({
    required super.output,
    super.finishReason = FinishReason.unspecified,
    super.metadata = const {},
    super.usage,
    this.messages = const [],
    this.thinking,
    super.id,
  });

  /// The new messages generated during this chat interaction.
  final List<ChatMessage> messages;

  /// Thinking content for real-time streaming display (for reasoning models).
  ///
  /// During streaming, this field contains incremental thinking deltas as they
  /// arrive from the model. The final consolidated thinking is available in
  /// the message's [ThinkingPart].
  final String? thinking;

  @override
  String toString() =>
      '''
ChatResult{
  id: $id,
  output: $output,
  thinking: $thinking,
  messages: $messages,
  finishReason: $finishReason,
  metadata: $metadata,
  usage: $usage,
}''';
}
