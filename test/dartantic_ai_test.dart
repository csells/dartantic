import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dotprompt_dart/dotprompt_dart.dart';
import 'package:test/test.dart';

// NOTE: these tests require environment variables to be set.
// I recommend using .vscode/settings.json like so:
//
// {
//   "dart.env": {
//     "GEMINI_API_KEY": "your_gemini_api_key",
//     "OPENAI_API_KEY": "your_openai_api_key"
//   }
// }

void main() {
  group('Dartantic AI Integration Tests', () {
    group('Agent.model constructor', () {
      test('Hello World Example', () async {
        final agent = Agent(
          'openai',
          systemPrompt: 'Be concise, reply with one sentence.',
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'Where does "hello world" come from?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(RegExp(r'\.').allMatches(resultOutput).length, equals(1));
      });

      test('JSON Schema String Output', () async {
        final outputSchema = <String, dynamic>{
          'type': 'object',
          'properties': {
            'town': {'type': 'string'},
            'country': {'type': 'string'},
          },
          'required': ['town', 'country'],
          'additionalProperties': false,
        };

        final agent = Agent('openai', outputSchema: outputSchema.toSchema());
        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'The windy city in the US of A.',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(resultOutput, contains('Chicago'));
      });

      test('JSON Schema Object Output', () async {
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
          outputFromJson:
              (json) => {
                'town': json['town'] as String,
                'country': json['country'] as String,
              },
        );

        final result = await agent.runFor<Map<String, String>>(
          'The windy city in the US of A.',
        );

        expect(result.output, isA<Map<String, String>>());
        expect(result.output['town'], isNotEmpty);
        expect(result.output['country'], isNotEmpty);
        expect(result.output['town'], equals('Chicago'));
        expect(
          result.output['country'],
          isIn(['USA', 'United States', 'United States of America']),
        );
      });

      test('Tool Usage Example', () async {
        final agent = Agent(
          'openai',
          systemPrompt:
              'Be sure to include the name of the location in your response. '
              'Show the time as local time. '
              'Do not ask any follow up questions.',
          tools: [
            Tool(
              name: 'time',
              description: 'Get the current time in a given time zone',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'timeZoneName': {
                        'type': 'string',
                        'description':
                            'The name of the time zone (e.g. "America/New_York")',
                      },
                    },
                    'required': ['timeZoneName'],
                  }.toSchema(),
              onCall:
                  (input) async => {'time': DateTime.now().toIso8601String()},
            ),
            Tool(
              name: 'temp',
              description: 'Get the current temperature in a given location',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'location': {
                        'type': 'string',
                        'description': 'The location to get temperature for',
                      },
                    },
                    'required': ['location'],
                  }.toSchema(),
              onCall: (input) async => {'temperature': 72}, // Mock temperature
            ),
          ],
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'What is the time and temperature in New York City?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(resultOutput, contains('New York'));
      });

      test('Gemini Integration', () async {
        final agent = Agent(
          'google:gemini-2.0-flash',
          outputSchema:
              {
                'type': 'object',
                'properties': {
                  'town': {'type': 'string'},
                  'country': {'type': 'string'},
                },
                'required': ['town', 'country'],
                'additionalProperties': false,
              }.toSchema(),
          outputFromJson:
              (json) => {
                'town': json['town'] as String,
                'country': json['country'] as String,
              },
        );

        final result = await agent.runFor<Map<String, String>>(
          'The windy city in the US of A.',
        );

        expect(result.output, isA<Map<String, String>>());
        expect(result.output['town'], equals('Chicago'));
        expect(
          result.output['country'],
          isIn(['USA', 'United States', 'United States of America']),
        );
      });

      test('OpenAI Integration', () async {
        final agent = Agent(
          'openai/gpt-4o',
          outputSchema:
              {
                'type': 'object',
                'properties': {
                  'town': {'type': 'string'},
                  'country': {'type': 'string'},
                },
                'required': ['town', 'country'],
                'additionalProperties': false,
              }.toSchema(),
          outputFromJson:
              (json) => {
                'town': json['town'] as String,
                'country': json['country'] as String,
              },
        );

        final result = await agent.runFor<Map<String, String>>(
          'The windy city in the US of A.',
        );

        expect(result.output, isA<Map<String, String>>());
        expect(result.output['town'], equals('Chicago'));
        expect(
          result.output['country'],
          isIn(['USA', 'United States', 'United States of America']),
        );
      });

      test('Agent.runPrompt with DotPrompt object', () async {
        final prompt = DotPrompt('''
---
model: openai
input:
  default:
    length: 3
    text: "The quick brown fox jumps over the lazy dog."
---
Summarize this in {{length}} words: {{text}}
''');

        final output = StringBuffer();
        await for (final chunk in Agent.runPromptStream(prompt)) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(resultOutput.split(' ').length, equals(3));
      });
    });

    group('Agent constructor with provider', () {
      test('OpenAI Provider Basic', () async {
        final agent = Agent.provider(
          OpenAiProvider(),
          systemPrompt: 'Be concise, reply with one sentence.',
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'Where does "hello world" come from?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(RegExp(r'\.').allMatches(resultOutput).length, equals(1));
      });

      test('OpenAI Provider with Schema', () async {
        final agent = Agent.provider(
          OpenAiProvider(),
          outputSchema:
              {
                'type': 'object',
                'properties': {
                  'town': {'type': 'string'},
                  'country': {'type': 'string'},
                },
                'required': ['town', 'country'],
                'additionalProperties': false,
              }.toSchema(),
          outputFromJson:
              (json) => {
                'town': json['town'] as String,
                'country': json['country'] as String,
              },
        );

        final result = await agent.runFor<Map<String, String>>(
          'The windy city in the US of A.',
        );

        expect(result.output, isA<Map<String, String>>());
        expect(result.output['town'], equals('Chicago'));
        expect(
          result.output['country'],
          isIn(['USA', 'United States', 'United States of America']),
        );
      });

      test('Gemini Provider Basic', () async {
        final agent = Agent.provider(
          GeminiProvider(),
          systemPrompt: 'Be concise, reply with one sentence.',
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'Where does "hello world" come from?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(RegExp(r'\.').allMatches(resultOutput).length, equals(1));
      });

      test('Gemini Provider with Schema', () async {
        final agent = Agent.provider(
          GeminiProvider(),
          outputSchema:
              {
                'type': 'object',
                'properties': {
                  'town': {'type': 'string'},
                  'country': {'type': 'string'},
                },
                'required': ['town', 'country'],
                'additionalProperties': false,
              }.toSchema(),
          outputFromJson:
              (json) => {
                'town': json['town'] as String,
                'country': json['country'] as String,
              },
        );

        final result = await agent.runFor<Map<String, String>>(
          'The windy city in the US of A.',
        );

        expect(result.output, isA<Map<String, String>>());
        expect(result.output['town'], equals('Chicago'));
        expect(
          result.output['country'],
          isIn(['USA', 'United States', 'United States of America']),
        );
      });

      test('Provider with Tools', () async {
        final agent = Agent.provider(
          OpenAiProvider(),
          systemPrompt:
              'Be sure to include the name of the location in your response. '
              'Show the time as local time. '
              'Do not ask any follow up questions.',
          tools: [
            Tool(
              name: 'time',
              description: 'Get the current time in a given time zone',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'timeZoneName': {
                        'type': 'string',
                        'description':
                            'The name of the time zone (e.g. "America/New_York")',
                      },
                    },
                    'required': ['timeZoneName'],
                  }.toSchema(),
              onCall:
                  (input) async => {'time': DateTime.now().toIso8601String()},
            ),
            Tool(
              name: 'temp',
              description: 'Get the current temperature in a given location',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'location': {
                        'type': 'string',
                        'description': 'The location to get temperature for',
                      },
                    },
                    'required': ['location'],
                  }.toSchema(),
              // Mock temperature
              onCall: (input) async => {'temperature': 72},
            ),
          ],
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'What is the time and temperature in New York City?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(resultOutput, contains('New York'));
      });

      test('Gemini Provider with Tools', () async {
        final agent = Agent.provider(
          GeminiProvider(),
          systemPrompt:
              'Be sure to include the name of the location in your response. '
              'Show the time as local time. '
              'Do not ask any follow up questions.',
          tools: [
            Tool(
              name: 'time',
              description: 'Get the current time in a given time zone',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'timeZoneName': {
                        'type': 'string',
                        'description':
                            'The name of the time zone (e.g. "America/New_York")',
                      },
                    },
                    'required': ['timeZoneName'],
                  }.toSchema(),
              onCall:
                  (input) async => {'time': DateTime.now().toIso8601String()},
            ),
            Tool(
              name: 'temp',
              description: 'Get the current temperature in a given location',
              inputSchema:
                  {
                    'type': 'object',
                    'properties': {
                      'location': {
                        'type': 'string',
                        'description': 'The location to get temperature for',
                      },
                    },
                    'required': ['location'],
                  }.toSchema(),
              // Mock temperature
              onCall: (input) async => {'temperature': 72},
            ),
          ],
        );

        final output = StringBuffer();
        await for (final chunk in agent.runStream(
          'What is the time and temperature in New York City?',
        )) {
          output.write(chunk.output);
        }
        final resultOutput = output.toString();
        expect(resultOutput, isNotEmpty);
        expect(resultOutput, contains('New York'));
      });
    });
  });
}
