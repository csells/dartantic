// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final deepwiki = McpServer.remote(
    'deepwiki',
    url: 'https://mcp.deepwiki.com/mcp',
  );

  final agent = Agent(
    'google',
    systemPrompt: '''
You are a helpful assistant with access to tools. Take advantage of them!
Always explain what tools you're using and why.
''',
    tools: await deepwiki.getTools(),
  );

  try {
    const query =
        'check flutter/flutter for how to write hello, world in Flutter';
    await agent.runStream(query).map((r) => print(r.output)).drain();
  } finally {
    await deepwiki.disconnect();
  }
}
