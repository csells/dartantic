// NEVER check for API keys in tests. Dartantic already validates API keys
// and throws a clear exception if one is missing. Tests should fail loudly
// when credentials are unavailable, not silently skip.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('Google server-side tooling E2E', () {
    test(
      'Code Execution: runs python code',
      () async {
        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.codeExecution},
          ),
        );

        final result = await agent.send(
          'Use code execution to calculate 12345 * 67890 and print the result.',
        );

        expect(result.output.replaceAll(',', ''), contains('838102050'));
        // We might want to check metadata for code execution result if
        // possible,
        // but checking output is a good end-to-end verification.
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Google Search: searches and returns grounded results',
      () async {
        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.googleSearch},
          ),
        );

        final result = await agent.send(
          'Search for "Dart programming language release date" and tell me '
          'the year.',
        );

        expect(result.output, contains('2011')); // Or 2013
        expect(result.output, contains('Dart'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Google Search with typed output: uses double agent orchestrator',
      () async {
        // This test verifies the fix for GitHub issue #96:
        // Server-side tools combined with typed output should work.
        // The double agent orchestrator handles this by:
        // - Phase 1: Execute server-side tools (no outputSchema)
        // - Phase 2: Get structured output (no tools)
        //
        // Before the fix, this would fail with:
        // "Tool use with a response mime type: 'application/json' is
        // unsupported"
        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'language': {'type': 'string'},
            'year': {'type': 'integer'},
            'creator': {'type': 'string'},
          },
          'required': ['language', 'year', 'creator'],
        });

        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.googleSearch},
          ),
        );

        final result = await agent.sendFor<Map<String, dynamic>>(
          'Search for "Dart programming language" and return information '
          'about when it was released and who created it.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        // Verify we got valid typed output
        expect(result.output['language'], isNotNull);
        expect(result.output['year'], isA<int>());
        expect(result.output['creator'], isNotNull);

        // The year should be 2011 (announced) or 2013 (1.0 release)
        expect(result.output['year'], anyOf(equals(2011), equals(2013)));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Code Execution with typed output: uses double agent orchestrator',
      () async {
        // Test code execution server-side tool with typed output.
        //
        // Before the fix, this would fail with:
        // "Tool use with a response mime type: 'application/json' is
        // unsupported"
        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'result': {'type': 'integer'},
            'calculation': {'type': 'string'},
          },
          'required': ['result', 'calculation'],
        });

        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.codeExecution},
          ),
        );

        // 123 * 456 = 56088
        final result = await agent.sendFor<Map<String, dynamic>>(
          'Use code execution to calculate 123 * 456, then return the result '
          'in the specified JSON format.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        // Verify we got valid typed output with the correct calculation
        expect(result.output['result'], equals(56088));
        expect(result.output['calculation'], isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
