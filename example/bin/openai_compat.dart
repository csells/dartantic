// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent(
    // 'gemini-compat',
    'openrouter',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  print('# Agent: ${agent.displayName}');
  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);

  exit(0);
}
