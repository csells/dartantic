import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/src/dump_stuff.dart';

void main() async {
  final agent = Agent('google:gemini-3-flash-preview', enableThinking: true);
  // final agent = Agent('openai-responses:gpt-5', enableThinking: true);
  // final agent = Agent('claude', enableThinking: true);
  stdout.writeln('[[model thinking appears in brackets]]\n');
  await thinking(agent);
  await thinkingStream(agent);
  exit(0);
}

Future<void> thinking(Agent agent) async {
  stdout.writeln('\n${agent.displayName} thinking:');
  final result = await agent.send('In one sentence: how does quicksort work?');

  // Thinking is available via result.thinking (accumulated from streaming)
  assert(result.thinking != null && result.thinking!.isNotEmpty);
  stdout.writeln('[[${result.thinking}]]\n');
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
    // Display thinking in real-time via chunk.thinking field
    if (chunk.thinking != null) {
      stdout.write(chunk.thinking);
    }

    // Display response text
    if (chunk.output.isNotEmpty) {
      if (stillThinking) {
        stillThinking = false;
        stdout.writeln(']]\n');
      }
      stdout.write(chunk.output);
    }

    // Add messages to history - chunk.messages contains consolidated messages
    // that are ready for the conversation history
    history.addAll(chunk.messages);
  }

  stdout.writeln('\n');
  dumpMessages(history);
}
