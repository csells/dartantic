// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

final provider = Agent.providerFor('openrouter'); // 'gemini-compat'

void main() async {
  await simpleAgent();
  await simpleEmbedding();
  exit(0);
}

Future<void> simpleAgent() async {
  print('\nsimpleAgent()');

  final agent = Agent.provider(
    provider,
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  print('# Agent: ${agent.displayName}');
  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);
}

Future<void> simpleEmbedding() async {
  print('\nsimpleEmbedding()');

  final agent = Agent.provider(provider);
  if (!agent.caps.contains(ProviderCaps.embeddings)) {
    print('Provider ${agent.displayName} does not support embeddings.');
    return;
  }

  final embedding = await agent.createEmbedding(
    'Test embedding generation',
    type: EmbeddingType.document,
  );

  assert(embedding.isNotEmpty);

  print(
    '${agent.displayName}: Successfully generated embedding with '
    '${embedding.length} dimensions',
  );
}
