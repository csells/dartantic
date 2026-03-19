import 'dart:io' show Platform;

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  // Run manually with:
  // XAI_API_KEY=your_key dart test test/xai_responses_x_search_integration_test.dart
  final hasXaiKey = (Platform.environment['XAI_API_KEY'] ?? '')
      .trim()
      .isNotEmpty;
  final testModel =
      (Platform.environment['XAI_X_SEARCH_TEST_MODEL'] ??
              'grok-4-1-fast-non-reasoning')
          .trim();

  group('xAI Responses X Search Integration', () {
    test(
      'finds the last Dart release of February 2026 via bare x_search',
      () async {
        final agent = Agent(
          'xai-responses:$testModel',
          chatModelOptions: const XAIResponsesChatModelOptions(
            serverSideTools: {XAIServerSideTool.xSearch},
          ),
        );

        final chunks = <ChatResult<String>>[];
        await agent
            .sendStream(
              'Search X for posts from @dart_lang about the Dart SDK '
              'release in February 2026. What was the version number?',
            )
            .forEach(chunks.add);

        expect(chunks, isNotEmpty);
        final fullText = chunks.map((c) => c.output).join().trim();
        expect(fullText, isNotEmpty);
        expect(fullText, contains('3.11'));
      },
      skip: hasXaiKey ? false : 'Requires XAI_API_KEY',
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'finds Dart 3.7 via xSearchConfig with handle filter and date range',
      () async {
        final agent = Agent(
          'xai-responses:$testModel',
          chatModelOptions: const XAIResponsesChatModelOptions(
            serverSideTools: {XAIServerSideTool.xSearch},
            xSearchConfig: XAIXSearchConfig(
              allowedXHandles: ['dart_lang'],
              fromDate: '2025-2-01',
              toDate: '2025-2-28',
            ),
          ),
        );

        final chunks = <ChatResult<String>>[];
        await agent
            .sendStream(
              'Search X for posts from about the Dart SDK, '
              'in the month of February 2025. Im looking the dart release in '
              'that month. Reply with just the version number '
              'and a one-line summary.',
            )
            .forEach(chunks.add);

        expect(chunks, isNotEmpty);
        final fullText = chunks.map((c) => c.output).join().trim();
        expect(fullText, isNotEmpty);
        expect(fullText, contains('3.7'));
      },
      skip: hasXaiKey ? false : 'Requires XAI_API_KEY',
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
