import 'package:dartantic_ai/src/chat_models/llamadart_chat/llamadart_message_mappers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('Message Mapping', () {
    test('maps system message role correctly', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.system,
          parts: const [TextPart('You are helpful')],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages.length, 1);
      expect(llamaMessages[0].role, 'system');
      expect(llamaMessages[0].content, 'You are helpful');
    });

    test('maps user message role correctly', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Hello')],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages.length, 1);
      expect(llamaMessages[0].role, 'user');
      expect(llamaMessages[0].content, 'Hello');
    });

    test('maps model message role to assistant', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('Hi there')],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages.length, 1);
      expect(llamaMessages[0].role, 'assistant');
      expect(llamaMessages[0].content, 'Hi there');
    });

    test('extracts text from multiple text parts', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('Hello '), TextPart('world')],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages[0].content, contains('Hello'));
      expect(llamaMessages[0].content, contains('world'));
    });

    test('throws assertion error when ThinkingPart present', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [ThinkingPart('Internal reasoning')],
        ),
      ];

      expect(messages.toLlamaMessages, throwsA(isA<AssertionError>()));
    });

    test('skips ToolPart in message conversion', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            TextPart('Use this tool'),
            ToolPart.call(
              callId: 'call_1',
              toolName: 'test_tool',
              arguments: {'arg': 'value'},
            ),
          ],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      // Should only extract text, skip ToolPart
      expect(llamaMessages[0].content, 'Use this tool');
      expect(llamaMessages[0].content, isNot(contains('test_tool')));
    });

    test('handles empty message parts', () {
      final messages = [
        ChatMessage(role: ChatMessageRole.user, parts: const []),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages.length, 1);
      expect(llamaMessages[0].content, isEmpty);
    });

    test('converts multiple messages in order', () {
      final messages = [
        ChatMessage(
          role: ChatMessageRole.system,
          parts: const [TextPart('System')],
        ),
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [TextPart('User')],
        ),
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [TextPart('Model')],
        ),
      ];

      final llamaMessages = messages.toLlamaMessages();

      expect(llamaMessages.length, 3);
      expect(llamaMessages[0].role, 'system');
      expect(llamaMessages[1].role, 'user');
      expect(llamaMessages[2].role, 'assistant');
    });
  });
}
