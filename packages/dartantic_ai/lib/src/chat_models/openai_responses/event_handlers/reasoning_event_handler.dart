import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../openai_responses_event_mapping_state.dart';
import 'openai_responses_event_handler.dart';

/// Handles reasoning and thinking-related events.
class ReasoningEventHandler implements OpenAIResponsesEventHandler {
  /// Creates a new reasoning event handler.
  const ReasoningEventHandler();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.event_handlers.reasoning',
  );

  @override
  bool canHandle(openai.ResponseStreamEvent event) =>
      event is openai.ReasoningSummaryTextDeltaEvent ||
      event is openai.ReasoningSummaryTextDoneEvent ||
      event is openai.ReasoningSummaryPartAddedEvent ||
      event is openai.ReasoningSummaryPartDoneEvent ||
      event is openai.ReasoningTextDeltaEvent ||
      event is openai.ReasoningTextDoneEvent;

  @override
  Stream<ChatResult<ChatMessage>> handle(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.ReasoningSummaryTextDeltaEvent) {
      yield* _handleReasoningSummaryDelta(event, state);
    } else if (event is openai.ReasoningSummaryTextDoneEvent) {
      yield* _handleReasoningSummaryDone(event, state);
    }
    // Other reasoning events require no action
  }

  Stream<ChatResult<ChatMessage>> _handleReasoningSummaryDelta(
    openai.ReasoningSummaryTextDeltaEvent event,
    EventMappingState state,
  ) async* {
    final newThinking = _appendThinking(state, event.delta);
    if (newThinking.isEmpty) {
      return;
    }
    _logger.info('ResponseReasoningSummaryTextDelta: "$newThinking"');
    yield _thinkingChunk(newThinking);
  }

  Stream<ChatResult<ChatMessage>> _handleReasoningSummaryDone(
    openai.ReasoningSummaryTextDoneEvent event,
    EventMappingState state,
  ) async* {
    final newThinking = _appendThinking(state, event.text);
    if (newThinking.isEmpty) {
      return;
    }
    _logger.info('ResponseReasoningSummaryTextDone: "$newThinking"');
    yield _thinkingChunk(newThinking);
  }

  String _appendThinking(EventMappingState state, String text) {
    if (text.isEmpty) return '';
    final existing = state.thinkingBuffer.toString();

    // If the incoming text already contains the accumulated prefix,
    // only append the new suffix to avoid duplication.
    var toAppend = text;
    if (existing.isNotEmpty && text.startsWith(existing)) {
      toAppend = text.substring(existing.length);
    } else if (existing.startsWith(text)) {
      // Incoming text is a prefix we've already captured.
      return '';
    }
    if (toAppend.isEmpty) return '';

    state.thinkingBuffer.write(toAppend);
    return toAppend;
  }

  ChatResult<ChatMessage> _thinkingChunk(String thinking) =>
      ChatResult<ChatMessage>(
        output: ChatMessage(
          role: ChatMessageRole.model,
          parts: [ThinkingPart(thinking)],
        ),
        messages: const [],
        usage: null,
      );
}
