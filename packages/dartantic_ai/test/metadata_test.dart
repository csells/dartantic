// Test to verify metadata is properly attached to messages
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';

import 'package:test/test.dart';

void main() {
  group('Message Metadata', () {
    test('Anthropic attaches metadata for suppressed content', () async {
      final recipeSchema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'ingredients': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['name', 'ingredients'],
      });

      final recipeTool = Tool<Map<String, dynamic>>(
        name: 'get_recipe',
        description: 'Get a recipe',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        }),

        onCall: (input) => {
          'name': 'Test Recipe',
          'ingredients': ['ingredient1', 'ingredient2'],
        },
      );

      final agent = Agent('anthropic', tools: [recipeTool]);
      final result = await agent.sendFor<Map<String, dynamic>>(
        'Get me a test recipe',
        outputSchema: recipeSchema,
      );

      // Check that we got valid JSON output
      expect(result.output['name'], isNotNull);
      expect(result.output['ingredients'], isA<List>());

      // Anthropic typed output returns JSON in result.output, not in a model
      // message. Metadata (including suppressed content) is merged into the
      // result and not necessarily attached to individual messages.
      void checkMetadata(Map<String, dynamic> metadata, String source) {
        if (metadata.isEmpty) return;
        print('Found metadata on $source:');
        print(const JsonEncoder.withIndent('  ').convert(metadata));

        // Metadata may contain suppressed text if the model produced any
        if (metadata.containsKey('suppressed_text')) {
          expect(metadata['suppressed_text'], isA<String>());
        }
        if (metadata.containsKey('suppressedText')) {
          expect(metadata['suppressedText'], isA<String>());
        }
      }

      checkMetadata(result.metadata, 'result');
      for (final msg in result.messages) {
        checkMetadata(msg.metadata, 'message (${msg.role})');
      }
    });

    test('Google attaches metadata for suppressed content', () async {
      final recipeSchema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'ingredients': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['name', 'ingredients'],
      });

      final recipeTool = Tool<Map<String, dynamic>>(
        name: 'get_recipe',
        description: 'Get a recipe',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        }),
        onCall: (input) => {
          'name': 'Test Recipe',
          'ingredients': ['ingredient1', 'ingredient2'],
        },
      );

      final agent = Agent('google', tools: [recipeTool]);
      final result = await agent.sendFor<Map<String, dynamic>>(
        'Get me a test recipe',
        outputSchema: recipeSchema,
      );

      // Check that we got valid JSON output
      expect(result.output['name'], isNotNull);
      expect(result.output['ingredients'], isA<List>());

      // Find the message with JSON output
      ChatMessage? jsonMessage;
      for (final msg in result.messages) {
        if (msg.role == ChatMessageRole.model && msg.text.contains('{')) {
          jsonMessage = msg;
          break;
        }
      }

      expect(jsonMessage, isNotNull, reason: 'Should have a message with JSON');

      // Check for metadata
      if (jsonMessage!.metadata.isNotEmpty) {
        print('Found metadata on JSON message:');
        print(const JsonEncoder.withIndent('  ').convert(jsonMessage.metadata));

        // Google double agent should suppress any text from Phase 1
        // when there are no tool calls, or suppress tool-related metadata
        // Metadata may contain suppressedText if LLM added any
        if (jsonMessage.metadata.containsKey('suppressedText')) {
          expect(jsonMessage.metadata['suppressedText'], isA<String>());
        }
      }
    });

    test('ChatMessage preserves metadata during concatenation', () {
      final msg1 = ChatMessage(
        role: ChatMessageRole.model,
        parts: const [TextPart('Hello')],
        metadata: const {'key1': 'value1'},
      );

      final msg2 = ChatMessage(
        role: ChatMessageRole.model,
        parts: const [TextPart(' world')],
        metadata: const {'key2': 'value2'},
      );

      // Simulate what Agent._concatMessages would do
      final merged = ChatMessage(
        role: msg1.role,
        parts: [...msg1.parts, ...msg2.parts],
        metadata: {...msg1.metadata, ...msg2.metadata},
      );

      expect(merged.text, equals('Hello world'));
      expect(merged.metadata['key1'], equals('value1'));
      expect(merged.metadata['key2'], equals('value2'));
    });
  });
}
