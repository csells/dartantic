import 'dart:convert';

import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:uuid/uuid.dart';

import '../../utils.dart';

/// A class that processes the streaming response from OpenAI.
///
/// This class is used to process the streaming response from OpenAI. It is
/// used to process the streaming response from OpenAI. It is used to process
/// the streaming response from OpenAI. It is used to process the streaming
/// response from OpenAI.
class OpenAiStreamProcessor {
  /// Creates a new [OpenAiStreamProcessor].
  ///
  /// The [isFirstEverTextResponseUpdated] is a flag that indicates whether
  /// the first text response has been updated.
  OpenAiStreamProcessor({required this.isFirstEverTextResponseUpdated});

  /// A flag that indicates whether the first text response has been updated.
  bool isFirstEverTextResponseUpdated;

  /// A list of chunks of the streaming response.
  final List<String> _chunks = <String>[];
  final List<openai.ChatCompletionMessageToolCall> _toolCalls =
      <openai.ChatCompletionMessageToolCall>[];
  final Map<int, String?> _toolCallIdByIndex = <int, String?>{};
  final Map<String, ({String name, StringBuffer args})> _toolCallBuffers =
      <String, ({String name, StringBuffer args})>{};
  int _syntheticIndex = 0;
  bool _isFirstTextChunk = true;

  /// Processes a delta from the OpenAI streaming response.
  ///
  /// The [delta] is the delta to process.
  ///
  /// Returns the output text or null if the delta is not a text delta.
  String? processDelta(openai.ChatCompletionStreamResponseDelta delta) {
    // Handle content streaming
    if (delta.content != null && delta.content!.isNotEmpty) {
      var outputText = delta.content;
      if (_isFirstTextChunk) {
        if (!isFirstEverTextResponseUpdated) {
          outputText = '\n$outputText';
        }
        isFirstEverTextResponseUpdated = false;
        _isFirstTextChunk = false;
      }
      _chunks.add(delta.content!);
      return outputText;
    }

    // Handle tool calls during streaming
    if (delta.toolCalls != null && delta.toolCalls!.isNotEmpty) {
      final callsDesc = delta.toolCalls!
          .where((tc) => tc.function?.name != null)
          .map((tc) => '${tc.function!.name}(${tc.function?.arguments ?? ''})')
          .join(', ');
      if (callsDesc.isNotEmpty) {
        log.finer('[OpenAiModel] Tool calls received: $callsDesc');
      }

      for (final toolCall in delta.toolCalls!) {
        final index = toolCall.index ?? _syntheticIndex++;
        final id = toolCall.id;
        final name = toolCall.function?.name;
        final args = toolCall.function?.arguments;

        // If this chunk starts a new tool call, record its id and name
        if (id != null && name != null) {
          // Generate synthetic ID if empty
          final actualId = id.isEmpty ? const Uuid().v4() : id;
          _toolCallIdByIndex[index] = actualId;
          _toolCallBuffers.putIfAbsent(
            actualId,
            () => (name: name, args: StringBuffer()),
          );
        }
        // Use the most recent id for this index
        final currentId = _toolCallIdByIndex[index];
        if (currentId != null && args != null) {
          _toolCallBuffers[currentId]!.args.write(args);
          log.finer(
            '[OpenAiModel] Tool call received: index=$index, '
            'id=$currentId, name=${_toolCallBuffers[currentId]!.name}, '
            'args=$args',
          );
        }
      }
    }

    return null;
  }

  /// Finishes the streaming response.
  ///
  /// Returns the content and tool calls.
  ({String content, List<openai.ChatCompletionMessageToolCall> toolCalls})
  finish() {
    // Convert tool call buffers to tool calls
    if (_toolCallBuffers.isNotEmpty) {
      // Remove incomplete tool call buffers (empty or invalid JSON)
      _toolCallBuffers.removeWhere((_, v) {
        final argsStr = v.args.toString().trim();
        if (argsStr.isEmpty) return true;
        try {
          jsonDecode(argsStr);
          return false;
        } on Exception catch (_) {
          return true;
        }
      });

      final validToolCalls =
          _toolCallBuffers.entries
              .map(
                (entry) => openai.ChatCompletionMessageToolCall(
                  id: entry.key,
                  type: openai.ChatCompletionMessageToolCallType.function,
                  function: openai.ChatCompletionMessageFunctionCall(
                    name: entry.value.name,
                    arguments: entry.value.args.toString(),
                  ),
                ),
              )
              .toList();

      _toolCalls.addAll(validToolCalls);
    }

    return (content: _chunks.join(), toolCalls: _toolCalls);
  }
}
