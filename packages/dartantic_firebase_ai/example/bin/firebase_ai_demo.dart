import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';

void main() async {
  Agent.providerFactories['firebase-vertex'] = () =>
      FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
  Agent.providerFactories['firebase-google'] = () =>
      FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

  const model = 'firebase-vertex:gemini-2.0-flash';
  await singleTurnChat(model);
  await singleTurnChatStream(model);
  exit(0);
}

Future<void> singleTurnChat(String model) async {
  stdout.writeln('\n## Firebase AI Single Turn Chat');

  final agent = Agent(model);
  const prompt = 'What is Firebase AI and how does it work with Gemini models?';
  stdout.writeln('User: $prompt');

  final result = await agent.send(prompt);
  stdout.writeln('${agent.displayName}: ${result.output}');
  stdout.writeln('Usage: ${result.usage}');
}

Future<void> singleTurnChatStream(String model) async {
  stdout.writeln('\n## Firebase AI Streaming Chat');

  final agent = Agent(model);
  const prompt = 'Count from 1 to 5, explaining each number';
  stdout.writeln('User: $prompt');
  stdout.write('${agent.displayName}: ');

  await for (final result in agent.sendStream(prompt)) {
    stdout.write(result.output);
  }
  stdout.writeln();
}
