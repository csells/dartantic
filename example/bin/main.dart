// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent(
    'openai',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);
}
