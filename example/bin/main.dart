// ignore_for_file: avoid_print, unreachable_from_main

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/loc_time_temp.dart';
import 'package:example/temp_tool_call.dart';
import 'package:example/time_tool_call.dart';
import 'package:example/town_and_country.dart';

void main() async {
  await helloWorldExample();
  await outputTypeExampleWithJsonSchemaAndStringOutput();
  await outputTypeExampleWithJsonSchemaAndOutjectOutput();
  await outputTypeExampleWithSotiSchema();
  await toolExample();
  await toolExampleWithTypedOutput();
  exit(0);
}

Future<void> helloWorldExample() async {
  print('\nhelloWorldExample');

  final agent = Agent(
    'openai',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  final result = await agent.run('Where does "hello world" come from?');
  print(result.output);
}

Future<void> outputTypeExampleWithJsonSchemaAndStringOutput() async {
  print('\noutputTypeExampleWithJsonSchemaAndStringOutput');

  final tncSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  final agent = Agent('openai', outputType: tncSchema.toSchema());
  final result = await agent.run('The windy city in the US of A.');
  print(result.output);
}

Future<void> outputTypeExampleWithJsonSchemaAndOutjectOutput() async {
  print('\noutputTypeExampleWithJsonSchemaAndOutjectOutput');

  final tncSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  final agent = Agent(
    'openai',
    outputType: tncSchema.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );

  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );

  print(result.output);
}

Future<void> outputTypeExampleWithSotiSchema() async {
  print('\noutputTypeExampleWithSotiSchema');

  final agent = Agent(
    'openai',
    outputType: TownAndCountry.schemaMap.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );
  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );

  print(result.output);
}

Future<void> toolExample() async {
  print('\ntoolExample');

  final agent = Agent(
    'openai',
    systemPrompt:
        'Be sure to include the name of the location in your response. Show '
        'the time as local time. Do not ask any follow up questions.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputType: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputType: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  final result = await agent.run(
    'What is the time and temperature in New York City?',
  );

  print(result.output);
}

// NOTE: can the Agent handle tools+typed output itself even if the underlying
// models don't support it?
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
        inputType: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputType: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  final result = await agent.run(
    'What is the time and temperature in New York City and Chicago?',
  );

  final agent2 = Agent(
    'openai',
    systemPrompt: "Translate the user's prompt into a tool call.",
    outputType: ListOfLocTimeTemps.schemaMap.toSchema(),
    outputFromJson: ListOfLocTimeTemps.fromJson,
  );

  final result2 = await agent2.runFor<ListOfLocTimeTemps>(result.output);
  print(result2.output);
}
