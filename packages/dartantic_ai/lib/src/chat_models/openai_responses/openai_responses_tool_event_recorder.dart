import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import 'openai_responses_event_mapping_state.dart';
import 'openai_responses_tool_types.dart';

/// Records and streams tool execution events from OpenAI Responses API.
///
/// Handles recording tool events to state and yielding them as metadata chunks
/// that can be streamed to consumers for real-time tool execution visibility.
class OpenAIResponsesToolEventRecorder {
  /// Creates a new tool event recorder.
  const OpenAIResponsesToolEventRecorder();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.tool_recorder',
  );

  /// Records tool events based on the event type and yields metadata chunks.
  Stream<ChatResult<ChatMessage>> recordToolEventIfNeeded(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.ResponseImageGenerationCallPartialImageEvent ||
        event is openai.ResponseImageGenerationCallInProgressEvent ||
        event is openai.ResponseImageGenerationCallGeneratingEvent ||
        event is openai.ResponseImageGenerationCallCompletedEvent) {
      recordToolEvent(OpenAIResponsesToolTypes.imageGeneration, event, state);
      yield* yieldToolMetadataChunk(
        OpenAIResponsesToolTypes.imageGeneration,
        event,
      );
      return;
    }

    if (event is openai.ResponseWebSearchCallInProgressEvent ||
        event is openai.ResponseWebSearchCallSearchingEvent ||
        event is openai.ResponseWebSearchCallCompletedEvent) {
      yield* handleStandardToolEvent(
        OpenAIResponsesToolTypes.webSearch,
        event,
        state,
      );
      return;
    }

    if (event is openai.ResponseFileSearchCallInProgressEvent ||
        event is openai.ResponseFileSearchCallSearchingEvent ||
        event is openai.ResponseFileSearchCallCompletedEvent) {
      yield* handleStandardToolEvent(
        OpenAIResponsesToolTypes.fileSearch,
        event,
        state,
      );
      return;
    }

    if (event is openai.ResponseMcpCallArgumentsDeltaEvent ||
        event is openai.ResponseMcpCallArgumentsDoneEvent ||
        event is openai.ResponseMcpCallInProgressEvent ||
        event is openai.ResponseMcpCallCompletedEvent ||
        event is openai.ResponseMcpCallFailedEvent ||
        event is openai.ResponseMcpListToolsInProgressEvent ||
        event is openai.ResponseMcpListToolsCompletedEvent ||
        event is openai.ResponseMcpListToolsFailedEvent) {
      yield* handleStandardToolEvent(
        OpenAIResponsesToolTypes.mcp,
        event,
        state,
      );
      return;
    }

    if (event is openai.ResponseCodeInterpreterCallInProgressEvent ||
        event is openai.ResponseCodeInterpreterCallCompletedEvent ||
        event is openai.ResponseCodeInterpreterCallInterpretingEvent) {
      yield* handleStandardToolEvent(
        OpenAIResponsesToolTypes.codeInterpreter,
        event,
        state,
      );
      return;
    }

    _logger.warning(
      'Unhandled Responses event in tool recorder: ${event.runtimeType}',
    );
  }

  /// Records a tool event in the state's tool event log.
  void recordToolEvent(
    String toolType,
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) {
    state.recordToolEvent(toolType, event.toJson());
  }

  /// Yields a metadata chunk containing the tool event.
  ///
  /// Converts the event to JSON and wraps it in a ChatResult with metadata
  /// following the thinking pattern (always emit as list for consistency).
  Stream<ChatResult<ChatMessage>> yieldToolMetadataChunk(
    String toolKey,
    Object eventOrMap,
  ) async* {
    // Convert to JSON - handle both event objects and maps
    final Map<String, Object?> eventJson;
    if (eventOrMap is openai.ResponseStreamEvent) {
      eventJson = eventOrMap.toJson();
    } else if (eventOrMap is Map<String, Object?>) {
      eventJson = eventOrMap;
    } else {
      throw ArgumentError(
        'Expected ResponseEvent or Map, got ${eventOrMap.runtimeType}',
      );
    }

    // Yield a metadata-only chunk with the event as a single-item list
    // Following the thinking pattern: always emit as list for consistency
    yield ChatResult<ChatMessage>(
      output: ChatMessage(
        role: ChatMessageRole.model,
        parts: const [], // No text parts - just metadata
      ),
      messages: const [],
      metadata: {
        toolKey: [eventJson], // Single-item list
      },
      usage: null,
    );
  }

  /// Helper to record and yield tool events for standard tool types.
  Stream<ChatResult<ChatMessage>> handleStandardToolEvent(
    String toolKey,
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    recordToolEvent(toolKey, event, state);
    yield* yieldToolMetadataChunk(toolKey, event);
  }
}
