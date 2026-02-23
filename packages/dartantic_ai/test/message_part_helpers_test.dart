// CRITICAL TEST FAILURE INVESTIGATION PROCESS:
// When a test fails for a provider capability:
// 1. NEVER immediately disable the capability in provider definitions
// 2. ALWAYS investigate at the API level first:
//    - Test with curl to verify if the feature works at the raw API level
//    - Check the provider's official documentation
//    - Look for differences between our implementation and the API requirements
// 3. ONLY disable a capability after confirming:
//    - The API itself doesn't support the feature, OR
//    - The API has a fundamental limitation (like Together's
//      streaming tool format)
// 4. If the API supports it but our code doesn't: FIX THE IMPLEMENTATION

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_ai/src/chat_models/helpers/message_part_helpers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('MessagePartHelpers', () {
    group('extractText', () {
      test('returns empty string for empty list', () {
        final parts = <Part>[];
        expect(parts.text, equals(''));
      });

      test('returns single text part content', () {
        final parts = <Part>[const TextPart('Hello world')];
        expect(parts.text, equals('Hello world'));
      });

      test('concatenates multiple text parts without separator', () {
        final parts = <Part>[
          const TextPart('Hello'),
          const TextPart(' '),
          const TextPart('world'),
        ];
        expect(parts.text, equals('Hello world'));
      });

      test('includes empty text parts in concatenation', () {
        final parts = <Part>[
          const TextPart('Hello'),
          const TextPart(''),
          const TextPart('world'),
        ];
        expect(parts.text, equals('Helloworld'));
      });

      test('ignores non-text parts', () {
        final parts = <Part>[
          const TextPart('Hello'),
          const ToolPart.call(callId: '123', toolName: 'test', arguments: {}),
          const TextPart(' world'),
          DataPart(Uint8List(0), mimeType: 'image/png'),
        ];
        expect(parts.text, equals('Hello world'));
      });

      test('handles list with only non-text parts', () {
        final parts = <Part>[
          const ToolPart.call(callId: '123', toolName: 'test', arguments: {}),
          DataPart(Uint8List(0), mimeType: 'image/png'),
        ];
        expect(parts.text, equals(''));
      });

      test('preserves whitespace and special characters', () {
        final parts = <Part>[
          const TextPart('  Hello\n'),
          const TextPart('\tworld  '),
          const TextPart(r'!@#$%'),
        ];
        expect(parts.text, equals('  Hello\n\tworld  !@#\$%'));
      });

      test('handles unicode and emojis', () {
        final parts = <Part>[
          const TextPart('Hello 👋 '),
          const TextPart('世界'),
          const TextPart(' 🌍'),
        ];
        expect(parts.text, equals('Hello 👋 世界 🌍'));
      });
    });

    group('extractToolCalls', () {
      test('returns empty list for empty parts', () {
        final parts = <Part>[];
        expect(parts.toolCalls, isEmpty);
      });

      test('returns empty list when no tool calls present', () {
        final parts = <Part>[
          const TextPart('Hello'),
          const ToolPart.result(
            callId: '123',
            toolName: 'test',
            result: 'result',
          ),
        ];
        expect(parts.toolCalls, isEmpty);
      });

      test('extracts single tool call', () {
        const toolCall = ToolPart.call(
          callId: '123',
          toolName: 'get_weather',
          arguments: {'location': 'Boston'},
        );
        final parts = <Part>[
          const TextPart('Let me check the weather'),
          toolCall,
        ];

        final calls = parts.toolCalls;
        expect(calls, hasLength(1));
        expect(calls.first, equals(toolCall));
        expect(calls.first.callId, equals('123'));
        expect(calls.first.toolName, equals('get_weather'));
      });

      test('extracts multiple tool calls', () {
        const call1 = ToolPart.call(
          callId: '123',
          toolName: 'get_weather',
          arguments: {'location': 'Boston'},
        );
        const call2 = ToolPart.call(
          callId: '456',
          toolName: 'get_time',
          arguments: {'timezone': 'EST'},
        );

        final parts = <Part>[
          const TextPart('Checking weather and time'),
          call1,
          const ToolPart.result(
            callId: '123',
            toolName: 'get_weather',
            result: '72°F',
          ),
          call2,
        ];

        final calls = parts.toolCalls;
        expect(calls, hasLength(2));
        expect(calls[0], equals(call1));
        expect(calls[1], equals(call2));
      });

      test('handles tool calls with empty arguments', () {
        const toolCall = ToolPart.call(
          callId: '123',
          toolName: 'get_current_time',
          arguments: null,
        );
        final parts = <Part>[toolCall];

        final calls = parts.toolCalls;
        expect(calls, hasLength(1));
        expect(calls.first.arguments, isNull);
      });

      test('handles tool calls with empty IDs', () {
        const toolCall = ToolPart.call(
          callId: '',
          toolName: 'test_tool',
          arguments: {},
        );
        final parts = <Part>[toolCall];

        final calls = parts.toolCalls;
        expect(calls, hasLength(1));
        expect(calls.first.callId, equals(''));
      });
    });

    group('extractToolResults', () {
      test('returns empty list for empty parts', () {
        final parts = <Part>[];
        expect(parts.toolResults, isEmpty);
      });

      test('returns empty list when no tool results present', () {
        final parts = <Part>[
          const TextPart('Hello'),
          const ToolPart.call(callId: '123', toolName: 'test', arguments: {}),
        ];
        expect(parts.toolResults, isEmpty);
      });

      test('extracts single tool result', () {
        const toolResult = ToolPart.result(
          callId: '123',
          toolName: 'get_weather',
          result: '72°F and sunny',
        );
        final parts = <Part>[const TextPart('The weather is:'), toolResult];

        final results = parts.toolResults;
        expect(results, hasLength(1));
        expect(results.first, equals(toolResult));
        expect(results.first.result, equals('72°F and sunny'));
      });

      test('extracts multiple tool results', () {
        const result1 = ToolPart.result(
          callId: '123',
          toolName: 'get_weather',
          result: '72°F',
        );
        const result2 = ToolPart.result(
          callId: '456',
          toolName: 'get_time',
          result: '3:45 PM',
        );

        final parts = <Part>[
          const ToolPart.call(
            callId: '123',
            toolName: 'get_weather',
            arguments: {},
          ),
          result1,
          const ToolPart.call(
            callId: '456',
            toolName: 'get_time',
            arguments: {},
          ),
          result2,
          const TextPart('Results shown above'),
        ];

        final results = parts.toolResults;
        expect(results, hasLength(2));
        expect(results[0], equals(result1));
        expect(results[1], equals(result2));
      });

      test('handles JSON object results', () {
        final jsonResult = {
          'temperature': 72,
          'unit': 'F',
          'conditions': 'sunny',
        };
        final toolResult = ToolPart.result(
          callId: '123',
          toolName: 'get_weather',
          result: jsonResult,
        );
        final parts = <Part>[toolResult];

        final results = parts.toolResults;
        expect(results, hasLength(1));
        expect(results.first.result, equals(jsonResult));
      });
    });
  });

  group('ToolResultHelpers', () {
    group('serialize', () {
      test('returns string as-is', () {
        const result = 'Hello world';
        expect(ToolResultHelpers.serialize(result), equals('Hello world'));
      });

      test('returns empty string as-is', () {
        const result = '';
        expect(ToolResultHelpers.serialize(result), equals(''));
      });

      test('encodes map to JSON', () {
        final result = {'key': 'value', 'number': 42};
        expect(
          ToolResultHelpers.serialize(result),
          equals('{"key":"value","number":42}'),
        );
      });

      test('encodes list to JSON', () {
        final result = ['a', 'b', 'c'];
        expect(ToolResultHelpers.serialize(result), equals('["a","b","c"]'));
      });

      // Note: null cannot call extension methods in Dart
      // In real usage, tool results are never null

      test('encodes number to JSON', () {
        const result = 42;
        expect(ToolResultHelpers.serialize(result), equals('42'));
      });

      test('encodes boolean to JSON', () {
        const result = true;
        expect(ToolResultHelpers.serialize(result), equals('true'));
      });

      test('encodes nested structures to JSON', () {
        final result = {
          'user': {'name': 'John', 'age': 30},
          'items': ['apple', 'banana'],
          'active': true,
        };
        expect(
          ToolResultHelpers.serialize(result),
          equals(
            '{"user":{"name":"John","age":30},"items":["apple","banana"],'
            '"active":true}',
          ),
        );
      });

      test('handles special characters in strings', () {
        final result = {'message': 'Hello\n"World"\t!'};
        expect(
          ToolResultHelpers.serialize(result),
          equals(r'{"message":"Hello\n\"World\"\t!"}'),
        );
      });

      test('handles unicode in JSON encoding', () {
        final result = {'greeting': 'Hello 👋', 'text': '世界'};
        expect(
          ToolResultHelpers.serialize(result),
          equals('{"greeting":"Hello 👋","text":"世界"}'),
        );
      });
    });

    group('ensureMap', () {
      test('returns Map<String, dynamic> as-is', () {
        final result = <String, dynamic>{'key': 'value'};
        expect(ToolResultHelpers.ensureMap(result), equals(result));
        expect(
          ToolResultHelpers.ensureMap(result),
          same(result),
        ); // Same instance
      });

      test('wraps string in map', () {
        const result = 'Hello world';
        expect(
          ToolResultHelpers.ensureMap(result),
          equals({'result': 'Hello world'}),
        );
      });

      test('wraps number in map', () {
        const result = 42;
        expect(ToolResultHelpers.ensureMap(result), equals({'result': 42}));
      });

      test('wraps boolean in map', () {
        const result = true;
        expect(ToolResultHelpers.ensureMap(result), equals({'result': true}));
      });

      // Note: null cannot call extension methods in Dart
      // In real usage, tool results are never null

      test('wraps list in map', () {
        final result = [1, 2, 3];
        expect(
          ToolResultHelpers.ensureMap(result),
          equals({
            'result': [1, 2, 3],
          }),
        );
      });

      test('handles typed maps correctly', () {
        final result = <String, int>{'a': 1, 'b': 2};
        // Map<String, int> is considered Map<String, dynamic> at runtime
        // so it's returned as-is (not wrapped)
        expect(ToolResultHelpers.ensureMap(result), equals({'a': 1, 'b': 2}));
        expect(ToolResultHelpers.ensureMap(result), same(result));
      });

      test('handles empty map correctly', () {
        final result = <String, dynamic>{};
        expect(ToolResultHelpers.ensureMap(result), equals(result));
        expect(ToolResultHelpers.ensureMap(result), same(result));
      });

      test('handles nested structures when wrapping', () {
        final result = {
          'data': [1, 2, 3],
          'nested': {'key': 'value'},
        };
        expect(ToolResultHelpers.ensureMap(result), equals(result));
      });

      test('wraps complex objects', () {
        final result = DateTime(2023, 7, 1);
        final wrapped = ToolResultHelpers.ensureMap(result);
        expect(wrapped, equals({'result': result}));
        expect(wrapped['result'], isA<DateTime>());
      });
    });
  });

  group('Real-world inspired scenarios', () {
    test('OpenAI-style streaming accumulation', () {
      // Simulating how OpenAI sends tool calls in chunks
      final chunk1Parts = <Part>[
        const TextPart("I'll check the weather for you."),
        const ToolPart.call(
          callId: 'call_abc123',
          toolName: 'get_weather',
          arguments: null,
        ),
      ];

      final chunk2Parts = <Part>[
        const ToolPart.call(
          callId: 'call_abc123',
          toolName: '',
          arguments: {'location': 'Boston'},
        ),
      ];

      // In real usage, these would be merged at a higher level
      // Here we just verify extraction works correctly
      expect(chunk1Parts.text, equals("I'll check the weather for you."));
      expect(chunk1Parts.toolCalls, hasLength(1));
      expect(chunk2Parts.toolCalls, hasLength(1));
    });

    test('Google-style complete tool calls', () {
      final parts = <Part>[
        const TextPart('Let me get that information for you.'),
        const ToolPart.call(
          callId: '',
          toolName: 'current_date_time',
          arguments: {},
        ),
        const ToolPart.call(
          callId: '',
          toolName: 'get_temperature',
          arguments: {'location': 'NYC'},
        ),
      ];

      expect(parts.text, equals('Let me get that information for you.'));
      final calls = parts.toolCalls;
      expect(calls, hasLength(2));
      expect(calls.every((c) => c.callId.isEmpty), isTrue);
    });

    test('Tool result handling with various types', () {
      const stringResult = 'The weather is sunny';
      final mapResult = {'temperature': 72, 'conditions': 'sunny'};
      final listResult = ['sunny', 'warm', 'humid'];

      expect(
        ToolResultHelpers.serialize(stringResult),
        equals('The weather is sunny'),
      );
      expect(
        ToolResultHelpers.serialize(mapResult),
        equals(json.encode(mapResult)),
      );
      expect(
        ToolResultHelpers.serialize(listResult),
        equals(json.encode(listResult)),
      );

      expect(
        ToolResultHelpers.ensureMap(stringResult),
        equals({'result': stringResult}),
      );
      expect(ToolResultHelpers.ensureMap(mapResult), same(mapResult));
      expect(
        ToolResultHelpers.ensureMap(listResult),
        equals({'result': listResult}),
      );

      // Note: In real usage, tool results are never null because they come from
      // ToolPart.result which is typed as dynamic (non-nullable)
    });

    test('Mixed content message processing', () {
      final parts = <Part>[
        const TextPart('Based on your request, '),
        const TextPart("I've executed the following tools:\n\n"),
        const ToolPart.call(
          callId: '1',
          toolName: 'search',
          arguments: {'query': 'Dart'},
        ),
        const ToolPart.result(
          callId: '1',
          toolName: 'search',
          result: 'Found 10 results',
        ),
        const TextPart('\nThe search returned 10 results.'),
      ];

      expect(
        parts.text,
        equals(
          "Based on your request, I've executed the following tools:\n\n\n"
          'The search returned 10 results.',
        ),
      );
      expect(parts.toolCalls, hasLength(1));
      expect(parts.toolResults, hasLength(1));
    });

    test('Error result handling', () {
      final errorResult = {'error': 'API rate limit exceeded'};

      expect(
        ToolResultHelpers.serialize(errorResult),
        equals('{"error":"API rate limit exceeded"}'),
      );
      expect(ToolResultHelpers.ensureMap(errorResult), same(errorResult));
    });
  });
}
