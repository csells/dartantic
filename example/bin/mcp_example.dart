// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final localTime = Tool(
    name: 'local_time',
    description: 'Returns the current local time in ISO 8601 format.',
    onCall: (args) async => {'result': DateTime.now().toIso8601String()},
  );

  final deepwiki = McpServer.remote(
    'deepwiki',
    url: 'https://mcp.deepwiki.com/mcp',
  );

  final agent = Agent(
    'google',
    systemPrompt:
        'You are a helpful assistant with access to various tools; use them!',
    tools: [localTime, ...await deepwiki.getTools()],
  );

  try {
    const query =
        'What time is it and '
        'what model providers does csells/dartantic_ai currently support?';
    await agent.runStream(query).map((r) => print(r.output)).drain();
  } finally {
    await deepwiki.disconnect();
  }

  exit(0);
}
