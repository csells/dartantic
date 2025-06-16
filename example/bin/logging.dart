// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';

void main() async {
  // turn on all logging
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen(
    (record) => print('[${record.level.name}] ${record.message}'),
  );

  final agent = Agent(
    'openai',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);

  exit(0);
}
