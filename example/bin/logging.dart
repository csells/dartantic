// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';

void main() async {
  // Configure logging for dartantic_ai specifically
  hierarchicalLoggingEnabled = true;
  final dartanticLogger = Logger('dartantic_ai');
  dartanticLogger.level = Level.ALL;
  dartanticLogger.onRecord.listen((record) {
    assert(record.loggerName == 'dartantic_ai');
    print('[${record.loggerName}.${record.level.name}] ${record.message}');
  });

  final agent = Agent(
    'gemini',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);

  exit(0);
}
