// ignore_for_file: avoid_print, unreachable_from_main, unused_element

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';

void main() async {
  Logger.root.level = Level.INFO; // FINE
  Logger.root.onRecord.listen(
    (record) => print('\n[${record.level.name}]: ${record.message}\n'),
  );

  // await singleMcpServer();
  // await multipleToolsAndMcpServers();
  await oneRequestMultiTool(); // simulated calendar MCP server
  exit(0);
}

Future<void> oneRequestMultiTool() async {
  print('\nOne Request, Multi Tool Calls');

  final agent = Agent(
    'openai',
    systemPrompt: '''
You are a helpful calendar assistant.
Make sure you use the get-current-date-time tool FIRST to ground yourself.
Then use the get-calendar-schedule tool to get the schedule for the day.
''',
    tools: [
      Tool(
        name: 'get-current-date-time',
        description: 'Get the current local date and time in ISO-8601 format',
        onCall: (_) async => {'datetime': DateTime.now().toIso8601String()},
      ),
      Tool(
        name: 'get-calendar-schedule',
        description: 'Get the schedule for the day',
        inputSchema:
            {
              'type': 'object',
              'properties': {
                'date': {'type': 'string', 'format': 'date'},
              },
              'required': ['date'],
            }.toSchema(),
        onCall:
            (args) async => {
              'result': '[${args['date']}: You have a meeting at 10:00 AM',
            },
      ),
    ],
  );

  var messages = <Message>[];
  await agent.runStream("What's on my schedule today?", messages: messages).map(
    (r) {
      messages = r.messages;
      stdout.write(r.output);
    },
  ).drain();

  _dumpMessages(messages);
}

Future<void> singleMcpServer() async {
  print('\nSingle MCP Server');

  final huggingFace = McpClient.remote(
    'huggingface',
    url: Uri.parse('https://huggingface.co/mcp'),
  );

  final hgTools = await huggingFace.listTools();
  // _dumpTools('huggingface', hgTools);

  final agent = Agent(
    'google',
    systemPrompt:
        'You are a helpful assistant with access to various tools; '
        'use the right one for the right job!',
    tools: [...hgTools],
  );

  try {
    const query = 'Who is hugging face?';
    await agent.runStream(query).map((r) => stdout.write(r.output)).drain();
  } finally {
    await huggingFace.disconnect();
  }

  print('');
}

Future<void> multipleToolsAndMcpServers() async {
  print('\nMultiple Tools and MCP Servers');

  final localTime = Tool(
    name: 'local_time',
    description: 'Returns the current local time in ISO 8601 format.',
    onCall: (args) async => {'result': DateTime.now().toIso8601String()},
  );

  final location = Tool(
    name: 'location',
    description: 'Returns the current location.',
    onCall: (args) async => {'result': 'Portland, OR'},
  );

  final deepwiki = McpClient.remote(
    'deepwiki',
    url: Uri.parse('https://mcp.deepwiki.com/mcp'),
  );

  final dwTools = await deepwiki.listTools();
  // _dumpTools('deepwiki', dwTools);

  final huggingFace = McpClient.remote(
    'huggingface',
    url: Uri.parse('https://huggingface.co/mcp'),
  );

  final hgTools = await huggingFace.listTools();

  final agent = Agent(
    'google',
    systemPrompt:
        'You are a helpful assistant with access to various tools; '
        'make sure to use those first before answering questions!',
    tools: [localTime, location, ...dwTools, ...hgTools],
  );

  try {
    const query =
        'Where am I and what time is it and '
        'who is hugging face and '
        'what model providers does csells/dartantic_ai currently support?';

    var messages = <Message>[];
    await agent.runStream(query).map((r) {
      stdout.write(r.output);
      messages = r.messages;
    }).drain();

    _dumpMessages(messages);
  } finally {
    await Future.wait([deepwiki.disconnect(), huggingFace.disconnect()]);
  }

  print('');
}

void _dumpTools(String name, Iterable<Tool> tools) {
  print('\n# $name');
  for (final tool in tools) {
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(jsonDecode(tool.inputSchema!.toJson()));
    print('\n## Tool');
    print('- name: ${tool.name}');
    print('- description: ${tool.description}');
    print('- inputSchema: $json');
  }
}

void _dumpMessages(List<Message> messages) {
  print('Messages:');
  for (final message in messages) {
    final parts = message.parts
        .map((p) {
          final s = p.toString();
          return s.substring(0, min(s.length, 96)).replaceAll('\n', ' ');
        })
        .join('\n                     ');
    print('  ${message.role}: $parts');
  }
}
