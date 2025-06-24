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

  group('OpenAI Multiple Tool Results Bug', () {
    late List<Tool> testTools;

    setUp(() {
      testTools = [
        Tool(
          name: 'current_date',
          description: 'Get the current date',
          onCall: (args) async => {'date': '2025-06-20'},
        ),
        Tool(
          name: 'current_time',
          description: 'Get the current time',
          onCall: (args) async => {'time': '12:00:00Z'},
        ),
      ];
    });

    test(
      'should handle multiple tool results in a single message correctly',
      () async {
        // Create the EXACT problematic structure that Gemini produces
        // Based on the JSON dump: tool results in USER role messages!
        final problematicHistory = [
          // User's initial request
          Message.user([const TextPart('Get the current date and time')]),

          // Assistant message with tool calls
          Message.model([
            ToolPart(
              kind: ToolPartKind.call,
              id: 'a181e729-d068-49a7-8499-d74277a38dbc',
              name: 'current_date',
              arguments: {},
            ),
            ToolPart(
              kind: ToolPartKind.call,
              id: '846fdc4f-8ab2-44a4-b80a-dd4197238715',
              name: 'current_time',
              arguments: {},
            ),
          ]),

          // User messages with tool results
          Message.user([
            ToolPart(
              kind: ToolPartKind.result,
              id: 'a181e729-d068-49a7-8499-d74277a38dbc',
              name: 'current_date',
              result: {'date': '2025-06-20'},
            ),
            ToolPart(
              kind: ToolPartKind.result,
              id: '846fdc4f-8ab2-44a4-b80a-dd4197238715',
              name: 'current_time',
              result: {'time': '12:00:00Z'},
            ),
          ]),

          // Final assistant response
          Message.model([
            const TextPart(
              'The current date is 2025-06-20 and the current time is 12:00:00Z.',
            ),
          ]),
        ];

        print('\n=== TESTING MULTIPLE TOOL RESULTS IN SINGLE MESSAGE ===');
        print('This structure has multiple tool results in user role messages');

        final openaiAgent = Agent('openai', tools: testTools);

        final response = await openaiAgent.runWithRetries(
          'Hello?',
          messages: problematicHistory,
        );

        expect(
          response.output.isNotEmpty,
          isTrue,
          reason:
              'OpenAI should successfully process multiple tool results in single message',
        );

        print(
          '✅ OpenAI correctly handled multiple tool results in a single message!',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
