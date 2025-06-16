// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:example/town_and_country.dart';

void main() async {
  await outputTypeExampleWithJsonSchemaAndStringOutput();
  await outputTypeExampleWithJsonSchemaAndObjectOutput();
  await outputTypeExampleWithSotiSchema();
}

Future<void> outputTypeExampleWithJsonSchemaAndStringOutput() async {
  print('outputTypeExampleWithJsonSchemaAndStringOutput');

  final tncSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  final agent = Agent('openai', outputSchema: tncSchema.toSchema());
  await agent
      .runStream('The windy city in the US of A.')
      .map((result) => stdout.write(result.output))
      .drain();
  print('');
}

Future<void> outputTypeExampleWithJsonSchemaAndObjectOutput() async {
  print('\noutputTypeExampleWithJsonSchemaAndObjectOutput');

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
    outputSchema: tncSchema.toSchema(),
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
    outputSchema: TownAndCountry.schemaMap.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );
  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );
  print(result.output);
}
