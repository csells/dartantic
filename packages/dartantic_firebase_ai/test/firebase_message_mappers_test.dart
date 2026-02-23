import 'dart:typed_data';

import 'package:dartantic_firebase_ai/src/firebase_ai_chat_options.dart';
import 'package:dartantic_firebase_ai/src/firebase_message_mappers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai/firebase_ai.dart' as f;
import 'package:test/test.dart';

void main() {
  group('firebase mappers', () {
    test('maps basic user/model messages', () {
      final content = <ChatMessage>[
        ChatMessage.user('hello'),
        ChatMessage.model('hi'),
      ].toContentList();

      expect(content, hasLength(2));
      expect(content.first.parts.first, isA<f.TextPart>());
      expect(content.last.parts.first, isA<f.TextPart>());
    });

    test('maps multimodal user message', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('img'),
            DataPart(Uint8List.fromList([1, 2, 3, 4]), mimeType: 'image/png'),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      expect(list.first.parts.length, 2);
      expect(list.first.parts[1], isA<f.InlineDataPart>());
    });

    test('maps tool call + tool result with new ToolPart fields', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            ToolPart.call(
              callId: 'call_1',
              toolName: 'lookup',
              arguments: {'q': 'dart'},
            ),
          ],
        ),
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_1',
              toolName: 'lookup',
              result: {'ok': true},
            ),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(2));
      expect(list.first.parts.single, isA<f.FunctionCall>());
      expect(list.last.parts.single, isA<f.FunctionResponse>());
    });

    test('groups consecutive tool results into single response content', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_1',
              toolName: 'lookup',
              result: {'ok': true},
            ),
          ],
        ),
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_2',
              toolName: 'search',
              result: {'items': 3},
            ),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      expect(list.single.parts.length, 2);
      expect(list.single.parts.first, isA<f.FunctionResponse>());
      expect(list.single.parts.last, isA<f.FunctionResponse>());
    });

    test('maps tools to firebase tool declarations', () {
      final tools = [
        Tool<Map<String, dynamic>>(
          name: 'search',
          description: 'Search docs',
          inputSchema: Schema.fromMap({
            'type': 'object',
            'properties': {
              'q': {'type': 'string'},
            },
          }),
          onCall: (input) => input,
        ),
      ];

      final firebaseTools = tools.toToolList(enableCodeExecution: false);
      expect(firebaseTools, isNotNull);
      expect(firebaseTools, isNotEmpty);
    });

    test('maps safety settings', () {
      final settings = [
        const FirebaseAISafetySetting(
          category: FirebaseAISafetySettingCategory.harassment,
          threshold: FirebaseAISafetySettingThreshold.blockLowAndAbove,
        ),
      ];
      final mapped = settings.toSafetySettings();
      expect(mapped, hasLength(1));
    });
  });
}
