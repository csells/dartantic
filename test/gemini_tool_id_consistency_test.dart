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

  group('Gemini Tool ID Consistency', () {
    late List<Tool> testTools;
    late Map<String, dynamic> toolCallLog;

    setUp(() {
      toolCallLog = <String, dynamic>{};

      testTools = [
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
        Tool(
          name: 'find_events',
          description: 'Find events for a specific date',
          onCall: (args) async {
            toolCallLog['find_events'] = args;
            return {
              'events': [
                {'id': 'event1', 'title': 'Morning Meeting', 'time': '09:00'},
              ],
            };
          },
        ),
      ];
    });

    test(
      'should create matching tool call and result pairs with same IDs',
      () async {
        final geminiAgent = Agent('gemini', tools: testTools);

        var conversationHistory = <Message>[];
        await for (final response in geminiAgent.runStreamWithRetries(
          'Get the current time',
        )) {
          if (response.messages.isNotEmpty) {
            conversationHistory = response.messages.toList();
          }
        }

        // Verify tool was called
        expect(toolCallLog, containsPair('get_current_time', {}));

        // Extract all tool parts from the conversation
        final allParts = conversationHistory.expand((m) => m.parts).toList();
        final toolParts = allParts.whereType<ToolPart>().toList();

        print('Tool parts found: ${toolParts.length}');
        for (final part in toolParts) {
          print(
            'ToolPart: kind=${part.kind}, id=${part.id}, name=${part.name}',
          );
        }

        // Separate tool calls and results
        final toolCalls =
            toolParts.where((p) => p.kind == ToolPartKind.call).toList();
        final toolResults =
            toolParts.where((p) => p.kind == ToolPartKind.result).toList();

        // Validate basic expectations
        expect(
          toolCalls,
          isNotEmpty,
          reason: 'Should have at least one tool call',
        );
        expect(
          toolResults,
          isNotEmpty,
          reason: 'Should have at least one tool result',
        );
        expect(
          toolCalls.length,
          equals(toolResults.length),
          reason: 'Should have equal number of tool calls and results',
        );

        // Validate each tool call has a matching result with the same ID
        for (final call in toolCalls) {
          expect(
            call.id,
            isNotEmpty,
            reason: 'Tool call should have non-empty ID',
          );

          final matchingResult =
              toolResults.where((r) => r.id == call.id).singleOrNull;
          expect(
            matchingResult,
            isNotNull,
            reason: 'Should find matching result for tool call ID ${call.id}',
          );

          expect(
            matchingResult!.name,
            equals(call.name),
            reason: 'Tool call and result should have matching names',
          );

          print(
            '✓ Verified match: call ${call.id} -> result ${matchingResult.id}',
          );
        }

        // Ensure no orphaned results (results without matching calls)
        for (final result in toolResults) {
          final matchingCall =
              toolCalls.where((c) => c.id == result.id).singleOrNull;
          expect(
            matchingCall,
            isNotNull,
            reason: 'Every tool result should have a matching tool call',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'should handle multiple sequential tool calls with consistent IDs',
      () async {
        final geminiAgent = Agent('gemini', tools: testTools);

        var conversationHistory = <Message>[];
        await for (final response in geminiAgent.runStreamWithRetries(
          'Get the current time, then find my events',
        )) {
          if (response.messages.isNotEmpty) {
            conversationHistory = response.messages.toList();
          }
        }

        // Verify both tools were called
        expect(toolCallLog, containsPair('get_current_time', {}));
        expect(toolCallLog.containsKey('find_events'), isTrue);

        // Extract tool parts
        final allParts = conversationHistory.expand((m) => m.parts).toList();
        final toolParts = allParts.whereType<ToolPart>().toList();

        final toolCalls =
            toolParts.where((p) => p.kind == ToolPartKind.call).toList();
        final toolResults =
            toolParts.where((p) => p.kind == ToolPartKind.result).toList();

        print(
          'Multi-tool scenario: ${toolCalls.length} calls, ${toolResults.length} results',
        );

        // Should have multiple tool calls and results
        expect(
          toolCalls.length,
          greaterThan(1),
          reason: 'Should have multiple tool calls',
        );
        expect(
          toolResults.length,
          greaterThan(1),
          reason: 'Should have multiple tool results',
        );
        expect(toolCalls.length, equals(toolResults.length));

        // Validate ID consistency for all calls
        final callIds = <String>{};
        final resultIds = <String>{};

        for (final call in toolCalls) {
          expect(call.id, isNotEmpty);
          expect(
            callIds.add(call.id),
            isTrue,
            reason: 'Tool call IDs should be unique',
          );

          final matchingResult =
              toolResults.where((r) => r.id == call.id).singleOrNull;
          expect(matchingResult, isNotNull);
          expect(matchingResult!.name, equals(call.name));
        }

        for (final result in toolResults) {
          resultIds.add(result.id);
        }

        expect(
          callIds,
          equals(resultIds),
          reason: 'Call IDs and result IDs should match exactly',
        );
      },
    );

    test('should handle single-step mode with consistent IDs', () async {
      final geminiAgent = Agent(
        'gemini',
        tools: testTools,
        toolCallingMode: ToolCallingMode.singleStep,
      );

      var conversationHistory = <Message>[];
      await for (final response in geminiAgent.runStreamWithRetries(
        'Get the current time and find events',
      )) {
        if (response.messages.isNotEmpty) {
          conversationHistory = response.messages.toList();
        }
      }

      // Extract tool parts
      final allParts = conversationHistory.expand((m) => m.parts).toList();
      final toolParts = allParts.whereType<ToolPart>().toList();

      final toolCalls =
          toolParts.where((p) => p.kind == ToolPartKind.call).toList();
      final toolResults =
          toolParts.where((p) => p.kind == ToolPartKind.result).toList();

      print(
        'Single-step mode: ${toolCalls.length} calls, ${toolResults.length} results',
      );

      // In single-step mode, should still have matching pairs
      expect(
        toolCalls.length,
        equals(toolResults.length),
        reason: 'Even in single-step mode, calls and results should match',
      );

      // Validate ID consistency
      for (final call in toolCalls) {
        final matchingResult =
            toolResults.where((r) => r.id == call.id).singleOrNull;
        expect(
          matchingResult,
          isNotNull,
          reason: 'Single-step mode should still maintain ID consistency',
        );
        expect(matchingResult!.name, equals(call.name));
      }
    });
  });
}
