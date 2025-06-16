// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  await multiTurnChatExample();
}

Future<void> multiTurnChatExample() async {
  print('multiTurnChatExample');

  final agent = Agent(
    'openai',
    systemPrompt: 'You are a helpful assistant. Keep responses concise.',
  );

  // Start with empty message history
  var messages = <Message>[];

  // First turn
  final response1 = await agent.run(
    'What is the capital of France?',
    messages: messages,
  );
  print('User: What is the capital of France?');
  print('Assistant: ${response1.output}');

  // Update message history with the response
  messages = response1.messages;

  // Second turn - the agent should remember the context
  final response2 = await agent.run(
    'What is the population of that city?',
    messages: messages,
  );
  print('User: What is the population of that city?');
  print('Assistant: ${response2.output}');

  print('\nMessage history contains ${response2.messages.length} messages');
}
