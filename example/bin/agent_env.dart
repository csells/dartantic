// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

import 'env.dart';

void main() async {
  Agent.environment.addAll(Env.tryAll);

  final openAiAgent = Agent('openai', systemPrompt: 'Be concise.');
  final openAiResult = await openAiAgent.run('Why is the sky blue?');
  print('\n# OpenAI Agent\n${openAiResult.output}');

  final geminiAgent = Agent('gemini', systemPrompt: 'Be concise.');
  final geminiResult = await geminiAgent.run('Why is the sea salty?');
  print('\n# Gemini Agent\n${geminiResult.output}');

  exit(0);
}
