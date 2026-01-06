// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage Serialization', () {
    group('User Messages', () {
      test('serializes and deserializes simple user message', () {
        final message = ChatMessage.user('Hello, world!');
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.role, equals(ChatMessageRole.user));
        expect(restored.text, equals('Hello, world!'));
      });

      test('preserves message with multiple text parts', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [TextPart('Hello'), TextPart(' '), TextPart('World')],
        );
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.text, equals('Hello World'));
      });

      test('serializes message with metadata', () {
        final message = ChatMessage.user(
          'Test',
          metadata: {'key': 'value', 'count': 42},
        );
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.metadata['key'], equals('value'));
        expect(restored.metadata['count'], equals(42));
      });
    });

    group('Model Messages', () {
      test('serializes and deserializes model message', () {
        final message = ChatMessage.model('I am an AI assistant.');
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.role, equals(ChatMessageRole.model));
        expect(restored.text, equals('I am an AI assistant.'));
      });

      test('handles markdown content', () {
        final markdownContent = '''
# Heading
- Item 1
- Item 2

```dart
void main() {}
```
''';
        final message = ChatMessage.model(markdownContent);
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.text, equals(markdownContent));
      });
    });

    group('System Messages', () {
      test('serializes and deserializes system message', () {
        final message = ChatMessage.system('You are a helpful assistant.');
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.role, equals(ChatMessageRole.system));
        expect(restored.text, equals('You are a helpful assistant.'));
      });
    });

    group('DataPart Attachments', () {
      test('serializes and deserializes message with DataPart', () {
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final message = ChatMessage.user(
          'Check this image',
          parts: [DataPart(bytes, mimeType: 'image/png', name: 'test.png')],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.parts.length, equals(2)); // TextPart + DataPart
        final dataPart = restored.parts.whereType<DataPart>().first;
        expect(dataPart.mimeType, equals('image/png'));
        expect(dataPart.name, equals('test.png'));
        expect(dataPart.bytes, equals(bytes));
      });

      test('preserves binary data through serialization', () {
        final bytes = Uint8List.fromList(List.generate(256, (i) => i));
        final message = ChatMessage.user(
          'Binary data',
          parts: [
            DataPart(
              bytes,
              mimeType: 'application/octet-stream',
              name: 'data.bin',
            ),
          ],
        );

        final json = message.toJson();
        final jsonString = jsonEncode(json);
        final decoded = jsonDecode(jsonString);
        final restored = ChatMessage.fromJson(decoded);

        final dataPart = restored.parts.whereType<DataPart>().first;
        expect(dataPart.bytes, equals(bytes));
      });
    });

    group('LinkPart Attachments', () {
      test('serializes and deserializes message with LinkPart', () {
        final message = ChatMessage.user(
          'Check this link',
          parts: [
            LinkPart(
              Uri.parse('https://example.com/image.png'),
              mimeType: 'image/png',
              name: 'example.png',
            ),
          ],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        final linkPart = restored.parts.whereType<LinkPart>().first;
        expect(
          linkPart.url.toString(),
          equals('https://example.com/image.png'),
        );
        expect(linkPart.mimeType, equals('image/png'));
        expect(linkPart.name, equals('example.png'));
      });

      test('handles LinkPart without optional fields', () {
        final message = ChatMessage.user(
          'A link',
          parts: [LinkPart(Uri.parse('https://example.com'))],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        final linkPart = restored.parts.whereType<LinkPart>().first;
        expect(linkPart.url.toString(), equals('https://example.com'));
        expect(linkPart.mimeType, isNull);
        expect(linkPart.name, isNull);
      });
    });

    group('ToolPart Serialization', () {
      test('serializes and deserializes tool call', () {
        final message = ChatMessage(
          role: ChatMessageRole.model,
          parts: [
            TextPart('Calling tool...'),
            ToolPart.call(
              id: 'call_123',
              name: 'get_weather',
              arguments: {'city': 'London', 'units': 'celsius'},
            ),
          ],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.hasToolCalls, isTrue);
        final toolCall = restored.toolCalls.first;
        expect(toolCall.id, equals('call_123'));
        expect(toolCall.name, equals('get_weather'));
        expect(toolCall.arguments?['city'], equals('London'));
      });

      test('serializes and deserializes tool result', () {
        final message = ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            ToolPart.result(
              id: 'call_123',
              name: 'get_weather',
              result: {'temperature': 20, 'condition': 'sunny'},
            ),
          ],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.hasToolResults, isTrue);
        final toolResult = restored.toolResults.first;
        expect(toolResult.id, equals('call_123'));
        expect(toolResult.name, equals('get_weather'));
        expect(toolResult.result['temperature'], equals(20));
      });
    });

    group('Complex Messages', () {
      test('serializes message with multiple attachment types', () {
        final message = ChatMessage.user(
          'Mixed content',
          parts: [
            DataPart(
              Uint8List.fromList([1, 2, 3]),
              mimeType: 'image/jpeg',
              name: 'photo.jpg',
            ),
            LinkPart(
              Uri.parse('https://example.com/doc.pdf'),
              mimeType: 'application/pdf',
            ),
          ],
        );

        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.parts.whereType<TextPart>().length, equals(1));
        expect(restored.parts.whereType<DataPart>().length, equals(1));
        expect(restored.parts.whereType<LinkPart>().length, equals(1));
      });

      test('handles empty parts list', () {
        final message = ChatMessage(role: ChatMessageRole.user, parts: []);
        final json = message.toJson();
        final restored = ChatMessage.fromJson(json);

        expect(restored.parts, isEmpty);
        expect(restored.text, isEmpty);
      });
    });

    group('History Serialization', () {
      test('serializes and deserializes full conversation history', () {
        final history = [
          ChatMessage.user('What is the weather?'),
          ChatMessage.model('Let me check the weather for you.'),
          ChatMessage(
            role: ChatMessageRole.model,
            parts: [
              ToolPart.call(
                id: 'call_1',
                name: 'get_weather',
                arguments: {'city': 'London'},
              ),
            ],
          ),
          ChatMessage(
            role: ChatMessageRole.user,
            parts: [
              ToolPart.result(
                id: 'call_1',
                name: 'get_weather',
                result: {'temp': 15},
              ),
            ],
          ),
          ChatMessage.model('The temperature in London is 15°C.'),
        ];

        final jsonHistory = history.map((m) => m.toJson()).toList();
        final jsonString = jsonEncode(jsonHistory);
        final decoded = jsonDecode(jsonString) as List;
        final restored = decoded
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
            .toList();

        expect(restored.length, equals(5));
        expect(restored[0].role, equals(ChatMessageRole.user));
        expect(restored[1].role, equals(ChatMessageRole.model));
        expect(restored[2].hasToolCalls, isTrue);
        expect(restored[3].hasToolResults, isTrue);
        expect(restored[4].text, contains('15°C'));
      });
    });

    group('JSON String Round-trip', () {
      test('survives JSON encode/decode cycle', () {
        final message = ChatMessage.user(
          'Test with special chars: "quotes" & <tags>',
          parts: [
            DataPart(
              Uint8List.fromList([0xFF, 0xFE, 0x00, 0x01]),
              mimeType: 'application/octet-stream',
            ),
          ],
          metadata: {'special': 'value with "quotes"'},
        );

        final jsonString = jsonEncode(message.toJson());
        final decoded = jsonDecode(jsonString);
        final restored = ChatMessage.fromJson(decoded);

        expect(
          restored.text,
          equals('Test with special chars: "quotes" & <tags>'),
        );
        expect(restored.metadata['special'], equals('value with "quotes"'));
      });
    });
  });
}
