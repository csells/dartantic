/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities (e.g.
///    ProviderTestCaps)
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

import 'test_helpers/run_provider_test.dart';
import 'test_tools.dart';

void main() {
  // Extended timeout for thinking tests as models take longer when reasoning
  group(
    'Thinking (Extended Reasoning)',
    timeout: const Timeout(Duration(seconds: 180)),
    () {
      group('streaming with thinking (80% cases)', () {
        _runThinkingProviderTest(
          'thinking appears in metadata during streaming',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            // Use a simple conceptual question like the example does
            // (example/bin/thinking.dart uses "how does quicksort work?") Math
            // questions may be processed differently by reasoning models.
            final thinkingChunks = <String>[];
            final textChunks = <String>[];

            await for (final chunk in agent.sendStream(
              'In one sentence: how does quicksort work?',
            )) {
              // Collect thinking from ThinkingPart in messages
              for (final message in chunk.messages) {
                for (final part in message.parts) {
                  if (part is ThinkingPart) {
                    thinkingChunks.add(part.text);
                  }
                }
              }

              // Collect response text
              if (chunk.output.isNotEmpty) {
                textChunks.add(chunk.output);
              }
            }

            // Should have received thinking content
            expect(
              thinkingChunks,
              isNotEmpty,
              reason: 'Should receive thinking chunks',
            );

            // Should have received response text
            expect(
              textChunks,
              isNotEmpty,
              reason: 'Should receive text response',
            );

            // Full thinking should be substantial
            final fullThinking = thinkingChunks.join();
            expect(
              fullThinking.length,
              greaterThan(10),
              reason: 'Thinking should be substantial',
            );

            // Response should mention quicksort concepts
            final fullResponse = textChunks.join().toLowerCase();
            expect(
              fullResponse.contains('pivot') ||
                  fullResponse.contains('partition') ||
                  fullResponse.contains('sort') ||
                  fullResponse.contains('divide'),
              isTrue,
              reason: 'Should explain quicksort',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking accumulates through streaming',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final thinkingChunks = <String>[];

            await for (final chunk in agent.sendStream(
              'Calculate 156 divided by 12',
            )) {
              // Collect thinking from ThinkingPart in messages
              for (final message in chunk.messages) {
                for (final part in message.parts) {
                  if (part is ThinkingPart) {
                    thinkingChunks.add(part.text);
                  }
                }
              }
            }

            // Should have received thinking chunks
            expect(
              thinkingChunks,
              isNotEmpty,
              reason: 'Should receive thinking chunks',
            );

            // Accumulated thinking should be substantial
            final fullThinking = thinkingChunks.join();
            expect(
              fullThinking.length,
              greaterThan(10),
              reason: 'Thinking should accumulate to substantial content',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking appears as ThinkingPart in streamed messages',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            var hadThinkingParts = false;

            await for (final chunk in agent.sendStream('Simple math: 7 + 8')) {
              // Check messages in this chunk for ThinkingPart
              for (final message in chunk.messages) {
                for (final part in message.parts) {
                  if (part is ThinkingPart) {
                    hadThinkingParts = true;
                  }
                }
              }
            }

            // Should have ThinkingPart in messages
            expect(
              hadThinkingParts,
              true,
              reason: 'Thinking should appear as ThinkingPart in messages',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking streams via chunk.thinking field',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final thinkingChunks = <String>[];
            final textChunks = <String>[];

            await for (final chunk in agent.sendStream(
              'In one sentence: explain binary search.',
            )) {
              // Collect thinking from chunk.thinking field (real-time)
              if (chunk.thinking != null) {
                thinkingChunks.add(chunk.thinking!);
              }

              // Collect response text from chunk.output field
              if (chunk.output.isNotEmpty) {
                textChunks.add(chunk.output);
              }
            }

            // Should have received thinking via chunk.thinking field
            expect(
              thinkingChunks,
              isNotEmpty,
              reason: 'Should receive thinking via chunk.thinking field',
            );

            // Accumulated thinking should be substantial
            final fullThinking = thinkingChunks.join();
            expect(
              fullThinking.length,
              greaterThan(10),
              reason: 'Thinking should accumulate to substantial content',
            );

            // Should also have received text response
            expect(
              textChunks,
              isNotEmpty,
              reason: 'Should receive text response',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'streaming does not pollute history with ThinkingPart-only messages',
          (provider) async {
            // This test ensures that streaming with thinking doesn't yield
            // individual ThinkingPart-only messages that would pollute the
            // message history. ThinkingPart should only appear in consolidated
            // messages alongside TextPart or ToolPart.
            final agent = _createAgentWithThinking(
              provider,
              tools: [currentDateTimeTool],
            );

            final allMessages = <ChatMessage>[];

            await for (final chunk in agent.sendStream(
              'What time is it and what day is today?',
            )) {
              allMessages.addAll(chunk.messages);
            }

            // Check that no model message has ONLY ThinkingPart (no pollution)
            final thinkingOnlyMessages = allMessages
                .where((m) => m.role == ChatMessageRole.model)
                .where((m) {
                  final parts = m.parts.toList();
                  // Has thinking parts but NO text or tool parts
                  final hasThinking = parts.any((p) => p is ThinkingPart);
                  final hasTextOrTool =
                      parts.any((p) => p is TextPart || p is ToolPart);
                  return hasThinking && !hasTextOrTool;
                });

            expect(
              thinkingOnlyMessages,
              isEmpty,
              reason: 'Should not have ThinkingPart-only messages - '
                  'thinking should be consolidated with text/tool parts. '
                  'Found ${thinkingOnlyMessages.length} ThinkingPart-only '
                  'messages in history.',
            );

            // Verify thinking IS present (consolidated with other parts)
            final thinkingMessages = allMessages
                .where((m) => m.role == ChatMessageRole.model)
                .where((m) => m.parts.any((p) => p is ThinkingPart));

            expect(
              thinkingMessages,
              isNotEmpty,
              reason: 'Should have consolidated messages with ThinkingPart',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking works with tool calls',
          (provider) async {
            final agent = _createAgentWithThinking(
              provider,
              tools: [currentDateTimeTool],
            );

            var hadThinking = false;
            var hadToolCall = false;
            var hadText = false;

            await for (final chunk in agent.sendStream(
              'What time is it right now?',
            )) {
              // Check for thinking in ThinkingPart
              for (final message in chunk.messages) {
                for (final part in message.parts) {
                  if (part is ThinkingPart) hadThinking = true;
                }
                if (message.toolCalls.isNotEmpty) hadToolCall = true;
              }

              // Check for text output
              if (chunk.output.isNotEmpty) hadText = true;
            }

            expect(hadThinking, true, reason: 'Should have thinking');
            expect(hadToolCall, true, reason: 'Should have tool call');
            expect(hadText, true, reason: 'Should have text response');
          },
          requiredCaps: {
            ProviderTestCaps.thinking,
            ProviderTestCaps.multiToolCalls,
          },
        );
      });

      group('non-streaming with thinking (80% cases)', () {
        _runThinkingProviderTest(
          'thinking appears in message parts for non-streaming',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final result = await agent.send('What is 15 plus 27?');

            // Thinking should be in message parts as ThinkingPart
            final thinkingText = result.messages
                .expand((m) => m.parts)
                .whereType<ThinkingPart>()
                .map((p) => p.text)
                .join();
            expect(thinkingText, isNotEmpty, reason: 'Should have thinking');
            expect(
              thinkingText.length,
              greaterThan(10),
              reason: 'Thinking should be substantial',
            );

            // Response should contain answer
            expect(
              result.output,
              contains('42'),
              reason: 'Should contain correct answer',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking appears as ThinkingPart in message parts',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final result = await agent.send('Simple question: 2+2');

            // Thinking should appear as ThinkingPart in message parts
            final thinkingParts = result.messages
                .expand((m) => m.parts)
                .whereType<ThinkingPart>()
                .toList();
            expect(
              thinkingParts,
              isNotEmpty,
              reason: 'Thinking should appear as ThinkingPart in messages',
            );
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );
      });

      group('thinking with different question types (80% cases)', () {
        _runThinkingProviderTest(
          'thinking for mathematical reasoning',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final result = await agent.send(
              'If a train travels 60 miles per hour for 2.5 hours, '
              'how far does it travel?',
            );

            final thinkingText = result.messages
                .expand((m) => m.parts)
                .whereType<ThinkingPart>()
                .map((p) => p.text)
                .join();
            expect(thinkingText, isNotEmpty);

            // Should contain the answer
            expect(result.output, contains('150'));
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking for logical reasoning',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final result = await agent.send(
              'If all cats are mammals, and Fluffy is a cat, '
              'what can we conclude about Fluffy?',
            );

            final thinkingText = result.messages
                .expand((m) => m.parts)
                .whereType<ThinkingPart>()
                .map((p) => p.text)
                .join();
            expect(thinkingText, isNotEmpty);

            // Should conclude Fluffy is a mammal
            final output = result.output.toLowerCase();
            expect(output, contains('mammal'));
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );

        _runThinkingProviderTest(
          'thinking for problem decomposition',
          (provider) async {
            final agent = _createAgentWithThinking(provider);

            final result = await agent.send(
              'How many quarters are in 5 dollars?',
            );

            final thinkingText = result.messages
                .expand((m) => m.parts)
                .whereType<ThinkingPart>()
                .map((p) => p.text)
                .join();
            expect(thinkingText, isNotEmpty);

            // Should contain the answer
            expect(result.output, contains('20'));
          },
          requiredCaps: {ProviderTestCaps.thinking},
        );
      });
    },
  );
}

void _runThinkingProviderTest(
  String description,
  Future<void> Function(Provider provider) testFunction, {
  Set<ProviderTestCaps>? requiredCaps,
  bool edgeCase = false,
  Timeout? timeout,
  Set<String>? skipProviders,
}) {
  runProviderTest(
    description,
    (provider) async {
      await testFunction(provider);
    },
    requiredCaps: requiredCaps,
    edgeCase: edgeCase,
    timeout: timeout,
    skipProviders: skipProviders,
  );
}

/// Creates an agent with thinking enabled for the given provider.
///
/// This function handles provider-specific configuration for thinking:
/// - Uses the provider's default model (which must support thinking)
/// - Enables thinking at the Agent level
Agent _createAgentWithThinking(Provider provider, {List<Tool>? tools}) =>
    Agent(provider.name, tools: tools, enableThinking: true);
