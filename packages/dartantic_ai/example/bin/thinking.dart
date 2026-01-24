import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/src/dump_stuff.dart';

void main() async {
  final agent = Agent('openai-responses:gpt-5', enableThinking: true);
  stdout.writeln('[[model thinking appears in brackets]]\n');
  await thinking(agent);
  await thinkingStream(agent);
  exit(0);
}

Future<void> thinking(Agent agent) async {
  stdout.writeln('\n${agent.displayName} thinking:');
  final result = await agent.send('In one sentence: how does quicksort work?');

  // Thinking is in message parts as ThinkingPart
  final thinking = result.messages
      .expand((m) => m.parts)
      .whereType<ThinkingPart>()
      .map((p) => p.text)
      .join();
  assert(thinking.isNotEmpty);
  stdout.writeln('[[$thinking]]\n');
  stdout.writeln(result.output);
  dumpMessages(result.messages);
}

Future<void> thinkingStream(Agent agent) async {
  stdout.writeln('\n${agent.displayName} thinkingStream:');

  final history = <ChatMessage>[];
  var stillThinking = true;
  stdout.write('[[');

  await for (final chunk in agent.sendStream(
    'In one sentence: how does quicksort work?',
  )) {
    // Display thinking in real-time from streaming-only messages (those
    // without TextPart). The consolidated message also has ThinkingParts
    // but we don't want to print those again.
    for (final message in chunk.messages) {
      final hasTextPart = message.parts.any((p) => p is TextPart);
      if (!hasTextPart) {
        // Streaming thinking-only message - display it
        for (final part in message.parts.whereType<ThinkingPart>()) {
          stdout.write(part.text);
        }
      }
    }

    // Display response text
    if (chunk.output.isNotEmpty) {
      if (stillThinking) {
        stillThinking = false;
        stdout.writeln(']]\n');
      }
      stdout.write(chunk.output);
    }

    // Only add "real" messages to history (user messages and model messages
    // with text/tools), not streaming thinking-only messages which are
    // already included in the consolidated model message
    for (final message in chunk.messages) {
      final hasTextOrTools = message.parts.any(
        (p) => p is TextPart || p is ToolPart,
      );
      if (hasTextOrTools || message.role == ChatMessageRole.user) {
        history.add(message);
      }
    }
  }

  stdout.writeln('\n');
  dumpMessages(history);
}
