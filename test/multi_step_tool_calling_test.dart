// ignore_for_file: lines_longer_than_80_chars, avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  setUpAll(() {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
  });

  group('Multi-step tool calling', () {
    late List<Tool> testTools;
    late Map<String, dynamic> toolCallLog;

    setUp(() {
      toolCallLog = <String, dynamic>{};

      testTools = [
        // First tool: get current time
        Tool(
          name: 'get_current_time',
          description: 'Get the current date and time',
          onCall: (args) async {
            toolCallLog['get_current_time'] = args;
            return {
              'datetime': '2025-06-20T12:00:00Z',
              'timestamp': 1718888400,
            };
          },
        ),

        // Second tool: find events based on time
        Tool(
          name: 'find_events',
          description: 'Find events for a specific date/time',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'date': {
                    'type': 'string',
                    'description':
                        'Date to search for events (YYYY-MM-DD format)',
                  },
                },
                'required': ['date'],
              }.toSchema(),
          onCall: (args) async {
            toolCallLog['find_events'] = args;
            return {
              'events': [
                {'id': 'event1', 'title': 'Morning Meeting', 'time': '09:00'},
                {'id': 'event2', 'title': 'Lunch with team', 'time': '12:30'},
              ],
            };
          },
        ),

        // Third tool: get event details
        Tool(
          name: 'get_event_details',
          description: 'Get detailed information about a specific event',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'event_id': {
                    'type': 'string',
                    'description': 'The ID of the event to get details for',
                  },
                },
                'required': ['event_id'],
              }.toSchema(),
          onCall: (args) async {
            toolCallLog['get_event_details'] = args;
            return {
              'event_id': args['event_id'],
              'title': 'Morning Meeting',
              'description': 'Weekly team standup meeting',
              'attendees': ['alice@example.com', 'bob@example.com'],
              'location': 'Conference Room A',
            };
          },
        ),
      ];
    });

    group('Performance', () {
      test(
        'should complete multi-step calls within reasonable time',
        () async {
          final agent = Agent('openai', tools: testTools);

          final stopwatch = Stopwatch()..start();

          await for (final response in agent.runStreamWithRetries(
            'Get current time, find events, and get details for the first event.',
          )) {
            // Allow the agent to complete its multi-step process
            if (response.output.isNotEmpty) {
              // We don't need to store responses for performance test,
              // just let the stream complete
            }
          }

          stopwatch.stop();

          // Should complete within a reasonable time (2 minutes max)
          expect(stopwatch.elapsed, lessThan(const Duration(minutes: 2)));

          // Verify all tools were called
          expect(toolCallLog.keys, hasLength(3));
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    });

    group('Tool Calling Mode', () {
      setUp(() {
        toolCallLog.clear();
      });

      group('OpenAI Model', () {
        test('should call multiple tools in multi-step mode', () async {
          final agent = Agent(
            'openai',
            tools: testTools,
            toolCallingMode: ToolCallingMode.multiStep,
          );

          await agent.runWithRetries(
            'Get the current time, then find my events for today.',
          );

          // Verify both tools were called in sequence
          expect(toolCallLog, containsPair('get_current_time', {}));
          expect(toolCallLog, contains('find_events'));
          expect(
            toolCallLog['find_events'],
            containsPair('date', '2025-06-20'),
          );

          // Verify the total number of tool calls
          expect(toolCallLog.keys, hasLength(2));
        });

        test('should call only one tool in single-step mode', () async {
          final agent = Agent(
            'openai',
            tools: testTools,
            toolCallingMode: ToolCallingMode.singleStep,
          );

          await agent.runWithRetries(
            "IMPORTANT: First call the get_current_time tool, then use that information to call the find_events tool with today's date.",
          );

          // Verify only the first tool was called
          expect(toolCallLog, containsPair('get_current_time', {}));

          // The second tool should not be called in single-step mode
          expect(toolCallLog, isNot(contains('find_events')));

          // Verify only one tool was called
          expect(toolCallLog.keys, hasLength(1));
        });
      });

      group('Gemini Model', () {
        test('should call multiple tools in multi-step mode', () async {
          final agent = Agent(
            'gemini',
            tools: testTools,
            toolCallingMode: ToolCallingMode.multiStep,
            systemPrompt:
                'You are a helpful assistant that can find events for a user. '
                'Make sure to ground yourself in the current time and date. '
                'You can use the get_current_time tool to get the current time, '
                'and the find_events tool to find events for a user.',
          );

          await agent.runWithRetries('find my events for the current date');

          // Verify both tools were called in sequence
          expect(toolCallLog, containsPair('get_current_time', {}));
          expect(toolCallLog, contains('find_events'));
          expect(
            toolCallLog['find_events'],
            containsPair('date', '2025-06-20'),
          );

          // Verify the total number of tool calls
          expect(toolCallLog.keys, hasLength(2));
        });

        test('should call only one tool in single-step mode', () async {
          final agent = Agent(
            'gemini',
            tools: testTools,
            toolCallingMode: ToolCallingMode.singleStep,
          );

          await agent.runWithRetries(
            "IMPORTANT: First call the get_current_time tool, then use that information to call the find_events tool with today's date.",
          );

          // Verify only the first tool was called
          expect(toolCallLog, containsPair('get_current_time', {}));

          // The second tool should not be called in single-step mode
          expect(toolCallLog, isNot(contains('find_events')));

          // Verify only one tool was called
          expect(toolCallLog.keys, hasLength(1));
        });
      });
    });

    group('Conversation Context', () {
      test(
        'should maintain conversation history with tool results',
        () async {
          final agent = Agent('openai', tools: testTools);

          AgentResponse? finalResponse;
          await for (final response in agent.runStreamWithRetries(
            'Get current time and find events',
          )) {
            finalResponse = response;
          }

          // Verify final response includes complete conversation history
          expect(finalResponse, isNotNull);
          expect(finalResponse!.messages, isNotEmpty);

          // Should have user message, assistant messages with tool calls, and tool results
          final messageTypes =
              finalResponse.messages.map((m) => m.role).toList();
          expect(messageTypes, contains(MessageRole.user));
          expect(messageTypes, contains(MessageRole.model));

          // Check for tool parts in the messages
          final allParts =
              finalResponse.messages.expand((m) => m.parts).toList();
          final toolParts = allParts.whereType<ToolPart>().toList();
          expect(toolParts, isNotEmpty);

          // Should have both tool calls and tool results
          final toolCalls =
              toolParts.where((p) => p.kind == ToolPartKind.call).toList();
          final toolResults =
              toolParts.where((p) => p.kind == ToolPartKind.result).toList();
          expect(toolCalls, isNotEmpty);
          expect(toolResults, isNotEmpty);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });

    group('Error Handling', () {
      test(
        'should handle tool call errors gracefully',
        () async {
          final errorTools = [
            Tool(
              name: 'failing_tool',
              description: 'A tool that always fails',
              onCall: (args) async {
                throw Exception('Tool intentionally failed');
              },
            ),
            Tool(
              name: 'working_tool',
              description: 'A tool that works',
              onCall: (args) async => {'result': 'success'},
            ),
          ];

          final agent = Agent('openai', tools: errorTools);

          final responses = <String>[];
          await for (final response in agent.runStreamWithRetries(
            'Use the failing tool, then use the working tool.',
          )) {
            if (response.output.isNotEmpty) {
              responses.add(response.output);
            }
          }

          // Should complete despite the error
          expect(responses, isNotEmpty);
          final fullResponse = responses.join().toLowerCase();
          expect(
            fullResponse,
            anyOf([contains('error'), contains('failed'), contains('success')]),
          );
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });
  });
}
