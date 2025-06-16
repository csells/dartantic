// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/temp_tool_call.dart';
import 'package:example/time_tool_call.dart';

void main() async {
  await toolExample();
  await toolExampleWithTypedOutput();
  exit(0);
}

Future<void> toolExample() async {
  print('toolExample');

  final agent = Agent(
    'openai',
    systemPrompt:
        'Be sure to include the name of the location in your response. Show '
        'the time as local time. Do not ask any follow up questions.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputSchema: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  await agent
      .runStream('What is the time and temperature in New York City?')
      .map((event) => stdout.write(event.output))
      .drain();
  print('');
}

Future<void> toolExampleWithTypedOutput() async {
  print('\ntoolExampleWithTypedOutput');

  final agent = Agent(
    'openai',
    systemPrompt:
        'Be sure to include the name of the location in your response. '
        'Show all dates and times in ISO 8601 format.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputSchema: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  await agent
      .runStream(
        'What is the time and temperature in New York City and Chicago?',
      )
      .map((event) => stdout.write(event.output))
      .drain();
  print('');

  // TODO: this doesn't work yet; perhaps it needs a RefProvider.sync() to
  // resolve the LocTimeTemp schema? this would require a call to direct call to
  // JsonSchema.create() instead of the toSchema() extension method.
  // final agent2 = Agent(
  //   'openai',
  //   systemPrompt: "Translate the user's prompt into a tool call.",
  //   outputType: ListOfLocTimeTemps.schemaMap.toSchema(),
  //   outputFromJson: ListOfLocTimeTemps.fromJson,
  // );

  // final result2 = await agent2.runFor<ListOfLocTimeTemps>(result.output);
  // print(result2.output);
}
