import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../openai_responses_event_mapping_state.dart';
import 'openai_responses_event_handler.dart';

/// Handles function call tracking and argument accumulation.
class FunctionCallEventHandler implements OpenAIResponsesEventHandler {
  /// Creates a new function call event handler.
  const FunctionCallEventHandler();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.event_handlers.function_call',
  );

  @override
  bool canHandle(openai.ResponseStreamEvent event) =>
      event is openai.FunctionCallArgumentsDeltaEvent ||
      event is openai.FunctionCallArgumentsDoneEvent;

  @override
  Stream<ChatResult<ChatMessage>> handle(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.FunctionCallArgumentsDeltaEvent) {
      _handleFunctionCallArgumentsDelta(event, state);
    } else if (event is openai.FunctionCallArgumentsDoneEvent) {
      _handleFunctionCallArgumentsDone(event, state);
    }
  }

  void _handleFunctionCallArgumentsDelta(
    openai.FunctionCallArgumentsDeltaEvent event,
    EventMappingState state,
  ) {
    final call = state.functionCalls[event.outputIndex];
    if (call != null) {
      call.appendArguments(event.delta);
      _logger.fine(
        'Appended arguments delta to call at index '
        '${event.outputIndex}: ${event.delta}',
      );
    } else {
      _logger.warning(
        'No function call found for outputIndex ${event.outputIndex}',
      );
    }
  }

  void _handleFunctionCallArgumentsDone(
    openai.FunctionCallArgumentsDoneEvent event,
    EventMappingState state,
  ) {
    _logger.fine(
      'FunctionCallArgumentsDoneEvent for index ${event.outputIndex}',
    );
    final call = state.functionCalls[event.outputIndex];
    if (call != null) {
      call.arguments = event.arguments;
      _logger.fine(
        'Function call completed: ${call.name} with args: ${event.arguments}',
      );
    } else {
      _logger.warning(
        'No function call found for completion at index ${event.outputIndex}',
      );
    }
  }
}
