// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/time_tool_call.dart';

void main() async {
  await providerSwitchingExample();
}

Future<void> providerSwitchingExample() async {
  print('providerSwitchingExample');

  // Start with OpenAI agent
  final openaiAgent = Agent(
    'openai',
    systemPrompt: 'Be helpful and call tools when needed.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  // First interaction with OpenAI
  final response1 = await openaiAgent.run('What time is it in London?');
  print('OpenAI response: ${response1.output}');

  // Switch to Gemini agent, passing the message history
  final geminiAgent = Agent(
    'gemini',
    systemPrompt: 'Be helpful and call tools when needed.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  // Continue conversation with Gemini using the message history
  final response2 = await geminiAgent.run(
    'What about New York?',
    messages: response1.messages,
  );
  print('Gemini response: ${response2.output}');

  print('\nTool calls work seamlessly across providers!');
}
