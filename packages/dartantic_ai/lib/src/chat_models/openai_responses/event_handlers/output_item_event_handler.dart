import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../openai_responses_attachment_collector.dart';
import '../openai_responses_event_mapping_state.dart';
import '../openai_responses_tool_event_recorder.dart';
import '../openai_responses_tool_types.dart';
import 'openai_responses_event_handler.dart';

/// Handles output item lifecycle events (added/done).
class OutputItemEventHandler implements OpenAIResponsesEventHandler {
  /// Creates a new output item event handler.
  const OutputItemEventHandler({
    required this.attachments,
    required this.toolRecorder,
  });

  /// Attachment collector for resolving container files and images.
  final AttachmentCollector attachments;

  /// Tool event recorder for streaming tool execution events.
  final OpenAIResponsesToolEventRecorder toolRecorder;

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.event_handlers.output_item',
  );

  @override
  bool canHandle(openai.ResponseStreamEvent event) =>
      event is openai.OutputItemAddedEvent ||
      event is openai.OutputItemDoneEvent;

  @override
  Stream<ChatResult<ChatMessage>> handle(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.OutputItemAddedEvent) {
      _handleOutputItemAdded(event, state);
    } else if (event is openai.OutputItemDoneEvent) {
      yield* _handleOutputItemDone(event, state);
    }
  }

  void _handleOutputItemAdded(
    openai.OutputItemAddedEvent event,
    EventMappingState state,
  ) {
    final item = event.item;
    _logger.fine('OutputItemAddedEvent: item type = ${item.runtimeType}');
    if (item is openai.FunctionCallOutputItemResponse) {
      state.functionCalls[event.outputIndex] = StreamingFunctionCall(
        itemId: item.id,
        callId: item.callId,
        name: item.name,
        outputIndex: event.outputIndex,
      );
      _logger.fine(
        'Function call created: ${item.name} '
        '(id=${item.callId}) at index ${event.outputIndex}',
      );
      return;
    }

    if (item is openai.ReasoningItem) {
      _logger.fine('Reasoning item at index ${event.outputIndex}');
      state.reasoningOutputIndices.add(event.outputIndex);
      return;
    }

    if (item is openai.ImageGenerationCallOutputItem) {
      _logger.fine('Image generation call at index ${event.outputIndex}');
    }
  }

  Stream<ChatResult<ChatMessage>> _handleOutputItemDone(
    openai.OutputItemDoneEvent event,
    EventMappingState state,
  ) async* {
    final item = event.item;
    _logger.fine('OutputItemDoneEvent: item type = ${item.runtimeType}');

    if (item is openai.ImageGenerationCallOutputItem) {
      _logger.fine('Image generation completed at index ${event.outputIndex}');
      attachments.markImageGenerationCompleted(
        index: event.outputIndex,
        resultBase64: item.result,
      );
    }

    if (item is openai.CodeInterpreterCallOutputItem) {
      _logger.fine('Code interpreter completed at index ${event.outputIndex}');
      _logger.fine(
        'CodeInterpreterCallOutputItem details: '
        'outputs=${item.outputs?.length ?? 0}, status=${item.status}',
      );

      if (item.outputs != null) {
        for (final output in item.outputs!) {
          if (output is openai.CodeInterpreterLogsOutput) {
            _logger.fine('Code interpreter logs: ${output.logs.length} chars');
          } else if (output is openai.CodeInterpreterImageOutput) {
            _logger.fine('Code interpreter image: ${output.url}');
          }
        }
      }

      toolRecorder.recordToolEvent(
        OpenAIResponsesToolTypes.codeInterpreter,
        event,
        state,
      );
      yield* toolRecorder.yieldToolMetadataChunk(
        OpenAIResponsesToolTypes.codeInterpreter,
        event,
      );
    }
  }
}
