import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../openai_responses_event_mapping_state.dart';
import 'openai_responses_event_handler.dart';

/// Handles text delta and completion events.
class TextEventHandler implements OpenAIResponsesEventHandler {
  /// Creates a new text event handler.
  const TextEventHandler();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.event_handlers.text',
  );

  @override
  bool canHandle(openai.ResponseStreamEvent event) =>
      event is openai.OutputTextDeltaEvent ||
      event is openai.OutputTextDoneEvent;

  @override
  Stream<ChatResult<ChatMessage>> handle(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.OutputTextDeltaEvent) {
      yield* _handleTextDelta(event, state);
    }
    // OutputTextDoneEvent requires no action
  }

  Stream<ChatResult<ChatMessage>> _handleTextDelta(
    openai.OutputTextDeltaEvent event,
    EventMappingState state,
  ) async* {
    if (event.delta.isEmpty) {
      return;
    }

    if (state.reasoningOutputIndices.contains(event.outputIndex)) {
      _logger.fine(
        'Skipping reasoning text delta at index ${event.outputIndex}: '
        '"${event.delta}"',
      );
      return;
    }

    _logger.fine(
      'ResponseOutputTextDelta: outputIndex=${event.outputIndex}, '
      'delta="${event.delta}"',
    );

    state.hasStreamedText = true;
    state.streamedTextBuffer.write(event.delta);

    final deltaMessage = ChatMessage(
      role: ChatMessageRole.model,
      parts: [TextPart(event.delta)],
    );
    yield ChatResult<ChatMessage>(
      output: deltaMessage,
      messages: const [],
      metadata: const {},
      usage: null,
    );
  }
}
