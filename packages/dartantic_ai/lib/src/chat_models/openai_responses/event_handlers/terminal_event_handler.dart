import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../openai_responses_attachment_collector.dart';
import '../openai_responses_event_mapping_state.dart';
import '../openai_responses_message_builder.dart';
import '../openai_responses_part_mapper.dart';
import '../openai_responses_session_manager.dart';
import 'openai_responses_event_handler.dart';

/// Handles terminal events that complete the response stream.
class TerminalEventHandler implements OpenAIResponsesEventHandler {
  /// Creates a new terminal event handler.
  const TerminalEventHandler({
    required this.storeSession,
    required this.attachments,
  });

  /// Whether session persistence is enabled for this request.
  final bool storeSession;

  /// Attachment collector for resolving container files and images.
  final AttachmentCollector attachments;

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.event_handlers.terminal',
  );

  OpenAIResponsesMessageBuilder get _messageBuilder =>
      const OpenAIResponsesMessageBuilder();
  OpenAIResponsesSessionManager get _sessionManager =>
      const OpenAIResponsesSessionManager();
  OpenAIResponsesPartMapper get _partMapper =>
      const OpenAIResponsesPartMapper();

  @override
  bool canHandle(openai.ResponseStreamEvent event) =>
      event is openai.ResponseCompletedEvent ||
      event is openai.ResponseFailedEvent;

  @override
  Stream<ChatResult<ChatMessage>> handle(
    openai.ResponseStreamEvent event,
    EventMappingState state,
  ) async* {
    if (event is openai.ResponseCompletedEvent) {
      yield* _handleResponseCompleted(event, state);
    } else if (event is openai.ResponseFailedEvent) {
      _handleResponseFailed(event);
    }
  }

  Stream<ChatResult<ChatMessage>> _handleResponseCompleted(
    openai.ResponseCompletedEvent event,
    EventMappingState state,
  ) async* {
    if (state.finalResultBuilt) {
      return;
    }
    state.finalResultBuilt = true;
    yield await _buildFinalResult(event.response, state);
  }

  void _handleResponseFailed(openai.ResponseFailedEvent event) {
    final error = event.response.error;
    if (error != null) {
      throw openai.ApiException(
        message: error.message,
        code: error.code,
        statusCode: -1,
      );
    }
    throw const openai.ApiException(
      message: 'OpenAI Responses request failed',
      statusCode: -1,
    );
  }

  Future<ChatResult<ChatMessage>> _buildFinalResult(
    openai.Response response,
    EventMappingState state,
  ) async {
    final parts = await _collectAllParts(response);
    final messageMetadata = _sessionManager.buildSessionMetadata(
      response: response,
      storeSession: storeSession,
    );
    final usage = _mapUsage(response.usage);
    final resultMetadata = _sessionManager.buildResultMetadata(response);

    // Extract container_id from ContainerFileCitation annotations if present.
    final containerId = _extractContainerId(response);
    if (containerId != null) {
      resultMetadata['container_id'] = containerId;
    }

    final finishReason = _mapFinishReason(response);
    final responseId = response.id;

    _logger.fine('Building final message with ${parts.length} parts');
    for (final part in parts) {
      _logger.fine('  Part: ${part.runtimeType}');
    }

    if (state.hasStreamedText) {
      return _messageBuilder.createStreamingResult(
        responseId: responseId,
        parts: parts,
        messageMetadata: messageMetadata,
        usage: usage,
        finishReason: finishReason,
        resultMetadata: resultMetadata,
      );
    } else {
      return _messageBuilder.createNonStreamingResult(
        responseId: responseId,
        parts: parts,
        messageMetadata: messageMetadata,
        usage: usage,
        finishReason: finishReason,
        resultMetadata: resultMetadata,
      );
    }
  }

  Future<List<Part>> _collectAllParts(openai.Response response) async {
    final mapped = _partMapper.mapResponseItems(response.output, attachments);
    final parts = [...mapped.parts];

    final attachmentParts = await attachments.resolveAttachments();
    if (attachmentParts.isNotEmpty) {
      parts.addAll(attachmentParts);
    }

    return parts;
  }

  static LanguageModelUsage _mapUsage(openai.ResponseUsage? usage) =>
      usage == null
      ? const LanguageModelUsage()
      : LanguageModelUsage(
          promptTokens: usage.inputTokens,
          responseTokens: usage.outputTokens,
          totalTokens: usage.totalTokens,
        );

  static FinishReason _mapFinishReason(openai.Response response) =>
      switch (response.status) {
        openai.ResponseStatus.completed => FinishReason.stop,
        openai.ResponseStatus.incomplete => _mapIncompleteReason(response),
        openai.ResponseStatus.unknown ||
        openai.ResponseStatus.queued ||
        openai.ResponseStatus.inProgress ||
        openai.ResponseStatus.failed ||
        openai.ResponseStatus.cancelled => FinishReason.unspecified,
      };

  /// Extracts the first container_id from ContainerFileCitation annotations
  /// in the response's message output items.
  static String? _extractContainerId(openai.Response response) {
    for (final item in response.output) {
      if (item is openai.MessageOutputItem) {
        for (final content in item.content) {
          if (content is openai.OutputTextContent) {
            final annotations = content.annotations;
            if (annotations == null) continue;
            for (final annotation in annotations) {
              if (annotation is openai.ContainerFileCitation) {
                return annotation.containerId;
              }
            }
          }
        }
      }
    }
    return null;
  }

  static FinishReason _mapIncompleteReason(openai.Response response) {
    final reason = response.incompleteDetails?.reason;
    if (reason == 'max_output_tokens') return FinishReason.length;
    if (reason == 'content_filter') return FinishReason.contentFilter;
    return FinishReason.unspecified;
  }
}
