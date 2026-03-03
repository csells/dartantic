import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import 'openai_responses_attachment_collector.dart';

/// Maps OpenAI Responses API items and content to dartantic Parts.
///
/// Handles conversion of response items (function calls, outputs, messages)
/// and output message content (text, refusals) into the dartantic Part
/// representation.
class OpenAIResponsesPartMapper {
  /// Creates a new part mapper.
  const OpenAIResponsesPartMapper();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.part_mapper',
  );

  /// Maps response items to dartantic Parts.
  ///
  /// Returns a record containing the mapped parts and a mapping of tool call
  /// IDs to their names (needed for mapping function outputs).
  ({List<Part> parts, Map<String, String> toolCallNames}) mapResponseItems(
    List<openai.OutputItem> items,
    AttachmentCollector attachments,
  ) {
    final parts = <Part>[];
    final toolCallNames = <String, String>{};

    _logger.info('Mapping ${items.length} response items');
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      _logger.info('Processing response item: ${item.runtimeType}');
      if (item is openai.MessageOutputItem) {
        final messageParts = mapOutputMessage(item.content, attachments);
        _logger.info(
          'OutputMessage has ${item.content.length} content items, '
          'mapped to ${messageParts.length} parts',
        );
        for (final part in messageParts) {
          if (part is TextPart) {
            _logger.info('Adding TextPart with text: "${part.text}"');
          }
        }
        parts.addAll(messageParts);
        continue;
      }

      if (item is openai.FunctionCallOutputItemResponse) {
        _logger.fine(
          'Adding function call to final result: ${item.name} '
          '(id=${item.callId})',
        );
        toolCallNames[item.callId] = item.name;
        parts.add(
          ToolPart.call(
            callId: item.callId,
            toolName: item.name,
            arguments: item.argumentsMap,
          ),
        );
        continue;
      }

      if (item is openai.ReasoningItem) {
        // Already accumulated via ResponseReasoningSummaryTextDelta
        continue;
      }

      if (item is openai.CodeInterpreterCallOutputItem) {
        _extractContainerFiles(item, attachments);
        continue;
      }

      if (item is openai.ImageGenerationCallOutputItem) {
        attachments.registerImageCall(item, index);
        continue;
      }

      if (item is openai.WebSearchCallOutputItem ||
          item is openai.FileSearchCallOutputItem) {
        // Events streamed in ChatResult.metadata
        continue;
      }

      if (item is openai.McpCallOutputItem) {
        // Events streamed in ChatResult.metadata
        continue;
      }
    }

    return (parts: parts, toolCallNames: toolCallNames);
  }

  /// Maps output message content to dartantic Parts.
  List<Part> mapOutputMessage(
    List<openai.OutputContent> content,
    AttachmentCollector attachments,
  ) {
    final parts = <Part>[];
    for (final entry in content) {
      _logger.info('Processing OutputContent: ${entry.runtimeType}');
      if (entry is openai.OutputTextContent) {
        _logger.info('OutputTextContent text: "${entry.text}"');
        parts.add(TextPart(entry.text));

        // Extract file citations from annotations
        final annotations = entry.annotations;
        if (annotations != null) {
          for (final annotation in annotations) {
            if (annotation is openai.FileCitation) {
              _logger.info('Found file citation: file_id=${annotation.fileId}');
            }
          }
        }
      } else if (entry is openai.RefusalContent) {
        parts.add(TextPart(entry.refusal));
      } else if (entry is openai.SummaryTextContent) {
        _logger.info(
          'Skipping summary_text from output - '
          'already in thinking buffer',
        );
      } else {
        final json = entry.toJson();
        _logger.info('OtherOutputContent: $json');
        parts.add(TextPart(jsonEncode(json)));
      }
    }
    return parts;
  }

  /// Extracts container file references from code interpreter outputs.
  void _extractContainerFiles(
    openai.CodeInterpreterCallOutputItem item,
    AttachmentCollector attachments,
  ) {
    final outputs = item.outputs;
    if (outputs == null) return;
    for (final output in outputs) {
      final type = output['type'] as String?;
      if (type == null) {
        _logger.warning(
          'Code interpreter output missing "type" key: '
          '${output.keys.join(', ')}',
        );
        continue;
      }
      if (type != 'files') continue;
      final files = output['files'] as List<dynamic>?;
      if (files == null) {
        _logger.warning('Code interpreter "files" output missing "files" key');
        continue;
      }
      for (final file in files) {
        if (file is Map<String, dynamic>) {
          final fileId = (file['file_id'] ?? file['id']) as String?;
          final containerId = output['container_id'] as String?;
          if (fileId != null && containerId != null) {
            _logger.info(
              'Found code interpreter file output: '
              'container_id=$containerId, file_id=$fileId',
            );
            attachments.trackContainerCitation(
              containerId: containerId,
              fileId: fileId,
            );
          }
        }
      }
    }
  }

  /// Decodes function call result from JSON string.
  dynamic decodeResult(String raw) => jsonDecode(raw);
}
