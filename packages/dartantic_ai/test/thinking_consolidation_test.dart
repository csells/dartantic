/// Tests for thinking consolidation invariants.
///
/// These tests ensure that ThinkingPart accumulation works exactly like
/// TextPart accumulation:
/// - At most ONE ThinkingPart per consolidated message
/// - At most ONE TextPart per consolidated message
/// - TextPart comes before ThinkingPart in the parts list
///
/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities
/// 3. 80% cases = common usage patterns tested across ALL capable providers

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

import 'test_helpers/run_provider_test.dart';

void main() {
  group(
    'Thinking Consolidation',
    timeout: const Timeout(Duration(seconds: 180)),
    () {
      group('consolidation invariants (80% cases)', () {
        _runThinkingProviderTest(
          'non-streaming: exactly one ThinkingPart per message',
          (provider) async {
            final agent = Agent.forProvider(
              provider,
              chatModelName: provider.defaultModelNames[ModelKind.chat],
              enableThinking: true,
            );

            final result = await agent.send(
              'In one sentence: what is the Fibonacci sequence?',
            );

            // Find model messages
            final modelMessages = result.messages
                .where((m) => m.role == ChatMessageRole.model)
                .toList();

            expect(
              modelMessages,
              isNotEmpty,
              reason: 'Should have model messages',
            );

            for (final message in modelMessages) {
              final thinkingParts = message.parts
                  .whereType<ThinkingPart>()
                  .toList();
              final textParts = message.parts.whereType<TextPart>().toList();

              // At most one ThinkingPart
              expect(
                thinkingParts.length,
                lessThanOrEqualTo(1),
                reason:
                    'Should have at most one ThinkingPart, '
                    'got ${thinkingParts.length}',
              );

              // At most one TextPart
              expect(
                textParts.length,
                lessThanOrEqualTo(1),
                reason:
                    'Should have at most one TextPart, '
                    'got ${textParts.length}',
              );
            }
          },
        );

        _runThinkingProviderTest(
          'non-streaming: TextPart comes before ThinkingPart',
          (provider) async {
            final agent = Agent.forProvider(
              provider,
              chatModelName: provider.defaultModelNames[ModelKind.chat],
              enableThinking: true,
            );

            final result = await agent.send(
              'In one sentence: explain recursion.',
            );

            // Find model messages with both text and thinking
            final modelMessages = result.messages
                .where((m) => m.role == ChatMessageRole.model)
                .toList();

            for (final message in modelMessages) {
              final textIndex = message.parts.indexWhere((p) => p is TextPart);
              final thinkingIndex = message.parts.indexWhere(
                (p) => p is ThinkingPart,
              );

              // If both exist, TextPart should come first
              if (textIndex != -1 && thinkingIndex != -1) {
                expect(
                  textIndex,
                  lessThan(thinkingIndex),
                  reason: 'TextPart should come before ThinkingPart',
                );
              }
            }
          },
        );

        _runThinkingProviderTest(
          'streaming: accumulated result has exactly one ThinkingPart',
          (provider) async {
            final agent = Agent.forProvider(
              provider,
              chatModelName: provider.defaultModelNames[ModelKind.chat],
              enableThinking: true,
            );

            final allMessages = <ChatMessage>[];

            await for (final chunk in agent.sendStream(
              'In one sentence: what is a binary tree?',
            )) {
              allMessages.addAll(chunk.messages);
            }

            // Find model messages (excluding streaming-only thinking messages)
            final consolidatedModelMessages = allMessages
                .where((m) => m.role == ChatMessageRole.model)
                .where(
                  (m) =>
                      m.parts.any((p) => p is TextPart) ||
                      m.parts.any((p) => p is ToolPart) ||
                      m.parts.isEmpty,
                )
                .toList();

            expect(
              consolidatedModelMessages,
              isNotEmpty,
              reason: 'Should have consolidated model messages',
            );

            for (final message in consolidatedModelMessages) {
              final thinkingParts = message.parts
                  .whereType<ThinkingPart>()
                  .toList();
              final textParts = message.parts.whereType<TextPart>().toList();

              // At most one ThinkingPart
              expect(
                thinkingParts.length,
                lessThanOrEqualTo(1),
                reason:
                    'Consolidated message should have at most one '
                    'ThinkingPart, got ${thinkingParts.length}',
              );

              // At most one TextPart
              expect(
                textParts.length,
                lessThanOrEqualTo(1),
                reason:
                    'Consolidated message should have at most one '
                    'TextPart, got ${textParts.length}',
              );
            }
          },
        );

        _runThinkingProviderTest(
          'streaming: TextPart before ThinkingPart in consolidated message',
          (provider) async {
            final agent = Agent.forProvider(
              provider,
              chatModelName: provider.defaultModelNames[ModelKind.chat],
              enableThinking: true,
            );

            final allMessages = <ChatMessage>[];

            await for (final chunk in agent.sendStream(
              'In one sentence: what is a hash table?',
            )) {
              allMessages.addAll(chunk.messages);
            }

            // Find consolidated model messages (those with TextPart)
            final consolidatedModelMessages = allMessages
                .where((m) => m.role == ChatMessageRole.model)
                .where((m) => m.parts.any((p) => p is TextPart))
                .toList();

            for (final message in consolidatedModelMessages) {
              final textIndex = message.parts.indexWhere((p) => p is TextPart);
              final thinkingIndex = message.parts.indexWhere(
                (p) => p is ThinkingPart,
              );

              // If both exist, TextPart should come first
              if (textIndex != -1 && thinkingIndex != -1) {
                expect(
                  textIndex,
                  lessThan(thinkingIndex),
                  reason:
                      'TextPart should come before ThinkingPart '
                      'in consolidated message',
                );
              }
            }
          },
        );
      });

      group('accumulator filtering (80% cases)', () {
        _runThinkingProviderTest(
          'streaming-only ThinkingPart messages are filtered from final result',
          (provider) async {
            final agent = Agent.forProvider(
              provider,
              chatModelName: provider.defaultModelNames[ModelKind.chat],
              enableThinking: true,
            );

            // Use non-streaming send() which uses AgentResponseAccumulator
            final result = await agent.send(
              'In one sentence: what is a linked list?',
            );

            // Count ThinkingPart-only messages (streaming artifacts that
            // should be filtered)
            final thinkingOnlyMessages = result.messages
                .where((m) => m.role == ChatMessageRole.model)
                .where(
                  (m) =>
                      m.parts.isNotEmpty &&
                      m.parts.every((p) => p is ThinkingPart),
                )
                .toList();

            // Should have NO streaming-only thinking messages
            expect(
              thinkingOnlyMessages,
              isEmpty,
              reason:
                  'Streaming-only ThinkingPart messages should be filtered '
                  'by AgentResponseAccumulator',
            );

            // But should still have thinking in consolidated message
            final messagesWithThinking = result.messages
                .where((m) => m.role == ChatMessageRole.model)
                .where((m) => m.parts.any((p) => p is ThinkingPart))
                .toList();

            expect(
              messagesWithThinking,
              isNotEmpty,
              reason: 'Should have consolidated message with ThinkingPart',
            );
          },
        );
      });
    },
  );
}

/// Runs a test across all providers that support thinking.
void _runThinkingProviderTest(
  String description,
  Future<void> Function(Provider provider) testFunction,
) {
  runProviderTest(
    description,
    testFunction,
    requiredCaps: {ProviderTestCaps.thinking},
  );
}
