// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';

Future<void> main() async {
  print('=== Example 1: System Message in History ===');
  final agent = Agent('gemini');

  final result1 = await agent.send(
    'What is 15 * 23?',
    history: [
      ChatMessage.system(
        'You are a helpful math tutor. Show your work step by step. '
        'Use * for multiplication and regular text formatting.',
      ),
    ],
  );
  print('Response: ${result1.output}');

  print('\n=== Example 2: Different System Message ===');
  final result2 = await agent.send(
    'What is 7 * 8?',
    history: [
      ChatMessage.system(
        'You are a pirate. Answer everything in pirate speak.',
      ),
    ],
  );
  print('Response: ${result2.output}');

  print('\n=== Example 3: No System Prompt ===');
  final regularAgent = Agent('openai:gpt-4o-mini');
  final result3 = await regularAgent.send('What is 15 * 23?');
  print('Response: ${result3.output}');

  exit(0);
}
