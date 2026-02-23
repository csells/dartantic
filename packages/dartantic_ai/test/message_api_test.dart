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

import 'dart:typed_data';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('Message API', () {
    group('basic message construction', () {
      test('creates simple text messages', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Hello, world!')],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(1));
        expect(message.parts.first, isA<TextPart>());
        expect((message.parts.first as TextPart).text, equals('Hello, world!'));
      });

      test('creates system messages', () {
        final message = ChatMessage(
          role: ChatMessageRole.system,
          parts: const [TextPart('You are a helpful assistant.')],
        );

        expect(message.role, equals(ChatMessageRole.system));
        expect(message.parts, hasLength(1));
        expect(message.parts.first, isA<TextPart>());
        expect(
          (message.parts.first as TextPart).text,
          equals('You are a helpful assistant.'),
        );
      });

      test('creates model response messages', () {
        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('I can help you with that!')],
        );

        expect(message.role, equals(ChatMessageRole.model));
        expect(message.parts, hasLength(1));
        expect(message.parts.first, isA<TextPart>());
        expect(
          (message.parts.first as TextPart).text,
          equals('I can help you with that!'),
        );
      });

      test('creates empty messages', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, isEmpty);
      });

      test('creates messages with multiple text parts', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('First part. '), TextPart('Second part.')],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(2));
        expect(message.parts.every((p) => p is TextPart), isTrue);
        expect((message.parts[0] as TextPart).text, equals('First part. '));
        expect((message.parts[1] as TextPart).text, equals('Second part.'));
      });
    });

    group('multipart messages', () {
      test('creates text and data combination', () {
        final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('What do you see in this image?'),
            DataPart(imageBytes, mimeType: 'image/jpeg'),
          ],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(2));
        expect(message.parts[0], isA<TextPart>());
        expect(message.parts[1], isA<DataPart>());

        final textPart = message.parts[0] as TextPart;
        final dataPart = message.parts[1] as DataPart;

        expect(textPart.text, equals('What do you see in this image?'));
        expect(dataPart.bytes, equals(imageBytes));
        expect(dataPart.mimeType, equals('image/jpeg'));
      });

      test('creates text and link combination', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('Tell me about this website: '),
            LinkPart(Uri.parse('https://www.example.com')),
          ],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(2));
        expect(message.parts[0], isA<TextPart>());
        expect(message.parts[1], isA<LinkPart>());

        final textPart = message.parts[0] as TextPart;
        final linkPart = message.parts[1] as LinkPart;

        expect(textPart.text, equals('Tell me about this website: '));
        expect(linkPart.url.toString(), equals('https://www.example.com'));
      });

      test('creates complex multipart messages', () {
        final documentBytes = Uint8List.fromList([10, 20, 30]);
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('Analyze these inputs:'),
            DataPart(documentBytes, mimeType: 'application/pdf'),
            LinkPart(Uri.parse('https://example.com/reference')),
            const TextPart('Let me know what you find.'),
          ],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(4));
        expect(message.parts[0], isA<TextPart>());
        expect(message.parts[1], isA<DataPart>());
        expect(message.parts[2], isA<LinkPart>());
        expect(message.parts[3], isA<TextPart>());

        expect(
          (message.parts[0] as TextPart).text,
          equals('Analyze these inputs:'),
        );
        expect(
          (message.parts[1] as DataPart).mimeType,
          equals('application/pdf'),
        );
        expect(
          (message.parts[2] as LinkPart).url.toString(),
          equals('https://example.com/reference'),
        );
        expect(
          (message.parts[3] as TextPart).text,
          equals('Let me know what you find.'),
        );
      });

      test('creates data-only messages', () {
        final imageBytes = Uint8List.fromList([255, 216, 255]); // JPEG header
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [DataPart(imageBytes, mimeType: 'image/jpeg')],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(1));
        expect(message.parts.first, isA<DataPart>());

        final dataPart = message.parts.first as DataPart;
        expect(dataPart.bytes, equals(imageBytes));
        expect(dataPart.mimeType, equals('image/jpeg'));
      });

      test('creates link-only messages', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [LinkPart(Uri.parse('https://docs.example.com/api'))],
        );

        expect(message.role, equals(ChatMessageRole.user));
        expect(message.parts, hasLength(1));
        expect(message.parts.first, isA<LinkPart>());

        final linkPart = message.parts.first as LinkPart;
        expect(linkPart.url.toString(), equals('https://docs.example.com/api'));
      });
    });

    group('data part specifications', () {
      test('supports various image mime types', () {
        final testCases = [
          ('image/jpeg', [255, 216, 255]),
          ('image/png', [137, 80, 78, 71]),
          ('image/gif', [71, 73, 70, 56]),
          ('image/webp', [82, 73, 70, 70]),
        ];

        for (final (mimeType, headerBytes) in testCases) {
          final bytes = Uint8List.fromList(headerBytes);
          final dataPart = DataPart(bytes, mimeType: mimeType);

          expect(dataPart.bytes, equals(bytes));
          expect(dataPart.mimeType, equals(mimeType));
        }
      });

      test('supports document mime types', () {
        final testCases = [
          'application/pdf',
          'text/plain',
          'application/json',
          'text/csv',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        ];

        for (final mimeType in testCases) {
          final bytes = Uint8List.fromList([1, 2, 3]);
          final dataPart = DataPart(bytes, mimeType: mimeType);

          expect(dataPart.mimeType, equals(mimeType));
          expect(dataPart.bytes, isNotNull);
        }
      });

      test('handles empty data', () {
        final dataPart = DataPart(Uint8List(0), mimeType: 'text/plain');

        expect(dataPart.bytes, hasLength(0));
        expect(dataPart.mimeType, equals('text/plain'));
      });

      test('handles large data efficiently', () {
        // Test with reasonably large data (1MB)
        final largeBytes = Uint8List(1024 * 1024)
          ..fillRange(0, 1024 * 1024, 42);
        final dataPart = DataPart(
          largeBytes,
          mimeType: 'application/octet-stream',
        );

        expect(dataPart.bytes.length, equals(1024 * 1024));
        expect(dataPart.mimeType, equals('application/octet-stream'));
        expect(dataPart.bytes.every((b) => b == 42), isTrue);
      });
    });

    group('link part specifications', () {
      test('supports various URL schemes', () {
        final testUrls = [
          'https://www.example.com',
          'http://localhost:3000',
          'ftp://files.example.com/data.txt',
          'file:///Users/docs/readme.txt',
          'data:text/plain;base64,SGVsbG8gV29ybGQ=',
        ];

        for (final url in testUrls) {
          final linkPart = LinkPart(Uri.parse(url));
          expect(linkPart.url.toString(), equals(url));
        }
      });

      test('handles URLs with query parameters', () {
        const url = 'https://api.example.com/data?format=json&limit=10';
        final linkPart = LinkPart(Uri.parse(url));

        expect(linkPart.url.toString(), equals(url));
      });

      test('handles URLs with fragments', () {
        const url = 'https://docs.example.com/guide#section-2';
        final linkPart = LinkPart(Uri.parse(url));

        expect(linkPart.url.toString(), equals(url));
      });
    });

    group('tool integration in messages', () {
      test('creates messages with tool calls', () {
        const toolCall = ToolPart.call(
          callId: 'call_123',
          toolName: 'string_tool',
          arguments: {'input': 'test value'},
        );

        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            TextPart('I will use the tool to process your request.'),
            toolCall,
          ],
        );

        expect(message.role, equals(ChatMessageRole.model));
        expect(message.parts, hasLength(2));
        expect(message.parts[0], isA<TextPart>());
        expect(message.parts[1], isA<ToolPart>());

        final toolPart = message.parts[1] as ToolPart;
        expect(toolPart.callId, equals('call_123'));
        expect(toolPart.toolName, equals('string_tool'));
        expect(toolPart.arguments!['input'], equals('test value'));
        expect(toolPart.kind, equals(ToolPartKind.call));
      });

      test('creates messages with tool results', () {
        const toolResult = ToolPart.result(
          callId: 'call_123',
          toolName: 'string_tool',
          result: 'Tool executed successfully',
        );

        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('Here is the result:'), toolResult],
        );

        expect(message.role, equals(ChatMessageRole.model));
        expect(message.parts, hasLength(2));
        expect(message.hasToolResults, isTrue);
        expect(message.toolResults, hasLength(1));

        final result = message.toolResults.first;
        expect(result.callId, equals('call_123'));
        expect(result.toolName, equals('string_tool'));
        expect(result.result, equals('Tool executed successfully'));
        expect(result.kind, equals(ToolPartKind.result));
      });

      test('creates messages with multiple tool results', () {
        final toolResults = [
          const ToolPart.result(
            callId: 'call_1',
            toolName: 'tool_1',
            result: 'Result 1',
          ),
          const ToolPart.result(
            callId: 'call_2',
            toolName: 'tool_2',
            result: 'Result 2',
          ),
        ];

        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: [const TextPart('Multiple tools executed:'), ...toolResults],
        );

        expect(message.hasToolResults, isTrue);
        expect(message.toolResults, hasLength(2));
        expect(message.toolResults[0].callId, equals('call_1'));
        expect(message.toolResults[1].callId, equals('call_2'));
        expect(message.toolResults[0].result, equals('Result 1'));
        expect(message.toolResults[1].result, equals('Result 2'));
      });

      test('handles tool results with complex output', () {
        const complexOutput = {
          'status': 'success',
          'data': ['item1', 'item2'],
          'metadata': {'count': 2},
        };

        const toolResult = ToolPart.result(
          callId: 'call_complex',
          toolName: 'complex_tool',
          result: complexOutput,
        );

        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('Complex tool completed:'), toolResult],
        );

        final result = message.toolResults.first;
        expect(result.result, equals(complexOutput));
        expect(
          (result.result! as Map<String, dynamic>)['status'],
          equals('success'),
        );
      });

      test('distinguishes between tool calls and results', () {
        const toolCall = ToolPart.call(
          callId: 'call_456',
          toolName: 'test_tool',
          arguments: {'param': 'value'},
        );

        const toolResult = ToolPart.result(
          callId: 'call_456',
          toolName: 'test_tool',
          result: 'Success',
        );

        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            TextPart('Processing...'),
            toolCall,
            TextPart('Done.'),
            toolResult,
          ],
        );

        expect(message.hasToolCalls, isTrue);
        expect(message.hasToolResults, isTrue);
        expect(message.toolCalls, hasLength(1));
        expect(message.toolResults, hasLength(1));
        expect(message.toolCalls.first.callId, equals('call_456'));
        expect(message.toolResults.first.callId, equals('call_456'));
      });
    });

    group('message role validation', () {
      test('supports all message roles', () {
        final roles = [
          ChatMessageRole.system,
          ChatMessageRole.user,
          ChatMessageRole.model,
        ];

        for (final role in roles) {
          final message = ChatMessage(
            role: role,
            parts: [TextPart('Message with role: $role')],
          );

          expect(message.role, equals(role));
        }
      });

      test('system messages typically contain instructions', () {
        final message = ChatMessage(
          role: ChatMessageRole.system,
          parts: const [
            TextPart(
              'You are an expert data analyst. Be concise and accurate.',
            ),
          ],
        );

        expect(message.role, equals(ChatMessageRole.system));
        final text = (message.parts.first as TextPart).text;
        expect(text, contains('You are'));
      });

      test('user messages typically contain queries', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Can you help me analyze this data?')],
        );

        expect(message.role, equals(ChatMessageRole.user));
        final text = (message.parts.first as TextPart).text;
        expect(text, contains('help'));
      });

      test('model messages typically contain responses', () {
        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            TextPart('I would be happy to help you analyze your data.'),
          ],
        );

        expect(message.role, equals(ChatMessageRole.model));
        final text = (message.parts.first as TextPart).text;
        expect(text, contains('happy to help'));
      });
    });

    group('message immutability and copying', () {
      test('messages are immutable after creation', () {
        final originalMessage = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Original text')],
        );

        // Attempting to modify parts should not affect original
        final parts = originalMessage.parts;
        expect(parts, hasLength(1));

        // Message properties should remain unchanged
        expect(originalMessage.role, equals(ChatMessageRole.user));
        expect(originalMessage.parts, hasLength(1));
      });

      test('can create message variants', () {
        final baseMessage = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Base message')],
        );

        // Create a new message with additional parts
        final extendedMessage = ChatMessage(
          role: baseMessage.role,
          parts: [...baseMessage.parts, const TextPart(' Extended text')],
        );

        expect(baseMessage.parts, hasLength(1));
        expect(extendedMessage.parts, hasLength(2));
        expect(
          (extendedMessage.parts[1] as TextPart).text,
          equals(' Extended text'),
        );
      });

      test('tool results are preserved in message copies', () {
        const originalToolResult = ToolPart.result(
          callId: 'tool_1',
          toolName: 'original_tool',
          result: 'Original result',
        );

        final originalMessage = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('Original response'), originalToolResult],
        );

        const newToolResult = ToolPart.result(
          callId: 'tool_2',
          toolName: 'new_tool',
          result: 'New result',
        );

        final newMessage = ChatMessage(
          role: originalMessage.role,
          parts: [...originalMessage.parts, newToolResult],
        );

        expect(originalMessage.toolResults, hasLength(1));
        expect(newMessage.toolResults, hasLength(2));
        expect(newMessage.toolResults[1].callId, equals('tool_2'));
      });
    });

    group('message collection patterns', () {
      test('builds conversation history', () {
        final conversation = <ChatMessage>[
          ChatMessage(
            role: ChatMessageRole.system,
            parts: const [TextPart('You are a helpful assistant.')],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: const [TextPart('Hello!')],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [TextPart('Hello! How can I help you today?')],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: const [TextPart('What is 2 + 2?')],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [TextPart('2 + 2 equals 4.')],
          ),
        ];

        expect(conversation, hasLength(5));
        expect(conversation[0].role, equals(ChatMessageRole.system));
        expect(conversation[1].role, equals(ChatMessageRole.user));
        expect(conversation[2].role, equals(ChatMessageRole.model));
        expect(conversation[3].role, equals(ChatMessageRole.user));
        expect(conversation[4].role, equals(ChatMessageRole.model));
      });

      test('filters messages by role', () {
        final conversation = <ChatMessage>[
          ChatMessage(
            role: ChatMessageRole.system,
            parts: const [TextPart('System')],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: const [TextPart('User 1')],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [TextPart('Model 1')],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: const [TextPart('User 2')],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [TextPart('Model 2')],
          ),
        ];

        final userMessages = conversation
            .where((m) => m.role == ChatMessageRole.user)
            .toList();
        final modelMessages = conversation
            .where((m) => m.role == ChatMessageRole.model)
            .toList();

        expect(userMessages, hasLength(2));
        expect(modelMessages, hasLength(2));
        expect((userMessages[0].parts[0] as TextPart).text, equals('User 1'));
        expect((modelMessages[1].parts[0] as TextPart).text, equals('Model 2'));
      });

      test('extracts all tool results from conversation', () {
        final conversation = <ChatMessage>[
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [
              TextPart('Using tool...'),
              ToolPart.result(
                callId: 'call_1',
                toolName: 'tool_1',
                result: 'Result 1',
              ),
            ],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: const [TextPart('Continue')],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [
              TextPart('Using another tool...'),
              ToolPart.result(
                callId: 'call_2',
                toolName: 'tool_2',
                result: 'Result 2',
              ),
              ToolPart.result(
                callId: 'call_3',
                toolName: 'tool_3',
                result: 'Result 3',
              ),
            ],
          ),
        ];

        final allToolResults = conversation
            .expand((m) => m.toolResults)
            .toList();

        expect(allToolResults, hasLength(3));
        expect(allToolResults[0].callId, equals('call_1'));
        expect(allToolResults[1].callId, equals('call_2'));
        expect(allToolResults[2].callId, equals('call_3'));
      });

      test('counts parts by type across conversation', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final conversation = <ChatMessage>[
          ChatMessage(
            role: ChatMessageRole.user,
            parts: [
              const TextPart('Text 1'),
              LinkPart(Uri.parse('https://example.com')),
            ],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: [
              const TextPart('Text 2'),
              DataPart(imageBytes, mimeType: 'image/jpeg'),
            ],
          ),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: const [
              TextPart('Response'),
              ToolPart.call(
                callId: 'call_1',
                toolName: 'test_tool',
                arguments: {'param': 'value'},
              ),
            ],
          ),
        ];

        final allParts = conversation.expand((m) => m.parts).toList();
        final textParts = allParts.whereType<TextPart>().length;
        final dataParts = allParts.whereType<DataPart>().length;
        final linkParts = allParts.whereType<LinkPart>().length;
        final toolParts = allParts.whereType<ToolPart>().length;

        expect(textParts, equals(3));
        expect(dataParts, equals(1));
        expect(linkParts, equals(1));
        expect(toolParts, equals(1));
        expect(allParts.length, equals(6));
      });
    });

    group('edge cases and validation', () {
      test('handles very long text content', () {
        final longText = 'A' * 10000; // 10k characters
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [TextPart(longText)],
        );

        expect(message.parts, hasLength(1));
        expect((message.parts.first as TextPart).text.length, equals(10000));
      });

      test('handles unicode and special characters', () {
        const unicodeText = '🚀 Hello 世界! 🌟 Testing émojis and accénts';
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart(unicodeText)],
        );

        final text = (message.parts.first as TextPart).text;
        expect(text, equals(unicodeText));
        expect(text, contains('🚀'));
        expect(text, contains('世界'));
        expect(text, contains('émojis'));
      });

      test('handles newlines and formatting', () {
        const formattedText = '''
Line 1
Line 2
  - Bullet point
  - Another bullet

Final paragraph.''';
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart(formattedText)],
        );

        final text = (message.parts.first as TextPart).text;
        expect(text, contains('\n'));
        expect(text, contains('  - '));
        expect(text.split('\n'), hasLength(6));
      });

      test('handles empty strings gracefully', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('')],
        );

        expect(message.parts, hasLength(1));
        expect((message.parts.first as TextPart).text, equals(''));
      });
    });

    group('convenience methods', () {
      test('text getter concatenates text parts', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('Hello '),
            LinkPart(Uri.parse('https://example.com')),
            const TextPart('world!'),
          ],
        );

        expect(message.text, equals('Hello world!'));
      });

      test('hasToolCalls and hasToolResults work correctly', () {
        final messageWithCalls = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            TextPart('Using tool...'),
            ToolPart.call(callId: 'call_1', toolName: 'tool', arguments: {}),
          ],
        );

        final messageWithResults = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            TextPart('Tool completed.'),
            ToolPart.result(callId: 'call_1', toolName: 'tool', result: 'Done'),
          ],
        );

        final messageWithBoth = ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            ToolPart.call(callId: 'call_1', toolName: 'tool', arguments: {}),
            ToolPart.result(callId: 'call_1', toolName: 'tool', result: 'Done'),
          ],
        );

        expect(messageWithCalls.hasToolCalls, isTrue);
        expect(messageWithCalls.hasToolResults, isFalse);

        expect(messageWithResults.hasToolCalls, isFalse);
        expect(messageWithResults.hasToolResults, isTrue);

        expect(messageWithBoth.hasToolCalls, isTrue);
        expect(messageWithBoth.hasToolResults, isTrue);
      });

      test('factory constructors work correctly', () {
        final systemMessage = ChatMessage.system('You are helpful.');
        final userMessage = ChatMessage.user('Hello');
        final modelMessage = ChatMessage.model('Hi there!');

        expect(systemMessage.role, equals(ChatMessageRole.system));
        expect(systemMessage.text, equals('You are helpful.'));

        expect(userMessage.role, equals(ChatMessageRole.user));
        expect(userMessage.text, equals('Hello'));

        expect(modelMessage.role, equals(ChatMessageRole.model));
        expect(modelMessage.text, equals('Hi there!'));
      });

      test('userParts and modelParts factories work correctly', () {
        final imageBytes = Uint8List.fromList([1, 2, 3]);
        final userMessage = ChatMessage.user(
          'Check this image:',
          parts: [DataPart(imageBytes, mimeType: 'image/jpeg')],
        );

        final modelMessage = ChatMessage.model(
          'Processing...',
          parts: const [
            ToolPart.call(callId: 'call_1', toolName: 'analyze', arguments: {}),
          ],
        );

        expect(userMessage.role, equals(ChatMessageRole.user));
        expect(userMessage.parts, hasLength(2));
        expect(userMessage.parts[1], isA<DataPart>());

        expect(modelMessage.role, equals(ChatMessageRole.model));
        expect(modelMessage.parts, hasLength(2));
        expect(modelMessage.parts[1], isA<ToolPart>());
        expect(modelMessage.hasToolCalls, isTrue);
      });
    });
  });
}
