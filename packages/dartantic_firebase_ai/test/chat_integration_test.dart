import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

import 'mock_firebase.dart';
import 'test_helpers/run_provider_test_helper.dart';

void main() {
  group('Firebase AI Chat Integration', () {
    setUpAll(() async {
      await initializeFirebase();
    });

    group('basic chat', () {
      runProviderTest(
        'single turn chat returns a response',
        (provider) async {
          final model = provider.createChatModel();
          final results = await model.sendStream([
            ChatMessage.user('Say "hello" and nothing else'),
          ]).toList();

          expect(results, isNotEmpty);
          final text = results.map((r) => r.output.text).nonNulls.join();
          expect(text.toLowerCase(), contains('hello'));
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );

      runProviderTest(
        'streaming yields multiple chunks',
        (provider) async {
          final model = provider.createChatModel();
          final results = await model.sendStream([
            ChatMessage.user('Count from 1 to 5, one number per line'),
          ]).toList();

          expect(results, isNotEmpty);
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );

      runProviderTest(
        'system instruction is respected',
        (provider) async {
          final model = provider.createChatModel();
          final results = await model.sendStream([
            ChatMessage.system('Always respond with exactly one word.'),
            ChatMessage.user('What is the capital of France?'),
          ]).toList();

          expect(results, isNotEmpty);
          final text = results.map((r) => r.output.text).nonNulls.join();
          expect(text.toLowerCase(), contains('paris'));
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('typed output', () {
      runProviderTest(
        'returns structured JSON when outputSchema is provided',
        (provider) async {
          final model = provider.createChatModel();
          final schema = Schema.fromMap({
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'population': {'type': 'integer'},
            },
            'required': ['name', 'population'],
          });

          final results = await model.sendStream([
            ChatMessage.user(
              'Return a JSON object with the name and population of '
              'the capital of France.',
            ),
          ], outputSchema: schema).toList();

          expect(results, isNotEmpty);
          final text = results.map((r) => r.output.text).nonNulls.join();
          final parsed = jsonDecode(text) as Map<String, dynamic>;
          expect(parsed, contains('name'));
          expect(parsed, contains('population'));
          expect(parsed['name'], isA<String>());
          expect(parsed['population'], isA<int>());
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('tool calling', () {
      runProviderTest(
        'model invokes a tool and receives the result',
        (provider) async {
          final tool = Tool<Map<String, dynamic>>(
            name: 'get_weather',
            description: 'Get the current weather for a city',
            inputSchema: Schema.fromMap({
              'type': 'object',
              'properties': {
                'city': {'type': 'string', 'description': 'The city name'},
              },
              'required': ['city'],
            }),
            onCall: (args) => {'temperature': 72, 'condition': 'sunny'},
          );

          final model = provider.createChatModel(tools: [tool]);
          final firstResults = await model.sendStream([
            ChatMessage.user("What's the weather in San Francisco?"),
          ]).toList();

          expect(firstResults, isNotEmpty);
          final lastResult = firstResults.last;
          final toolCalls = lastResult.output.parts.whereType<ToolPart>();
          expect(toolCalls, isNotEmpty);

          final toolCall = toolCalls.first;
          expect(toolCall.toolName, 'get_weather');
          expect(toolCall.kind, ToolPartKind.call);

          // Execute the tool and send the result back
          final toolResult = tool.onCall(toolCall.arguments!);
          final followUpResults = await model.sendStream([
            ChatMessage.user("What's the weather in San Francisco?"),
            lastResult.output,
            ChatMessage(
              role: ChatMessageRole.user,
              parts: [
                ToolPart.result(
                  callId: toolCall.callId,
                  toolName: toolCall.toolName,
                  result: toolResult,
                ),
              ],
            ),
          ]).toList();

          expect(followUpResults, isNotEmpty);
          final finalText = followUpResults
              .map((r) => r.output.text)
              .nonNulls
              .join();
          expect(finalText.toLowerCase(), contains('72'));
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('usage tracking', () {
      runProviderTest(
        'reports token usage',
        (provider) async {
          final model = provider.createChatModel();
          final results = await model.sendStream([
            ChatMessage.user('Say "hi"'),
          ]).toList();

          expect(results, isNotEmpty);
          final lastResult = results.last;
          expect(lastResult.usage, isNotNull);
          expect(lastResult.usage!.totalTokens, isNotNull);
          expect(lastResult.usage!.totalTokens, greaterThan(0));
        },
        integration: true,
        requiredCaps: {ProviderTestCaps.chat},
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });
  });
}
