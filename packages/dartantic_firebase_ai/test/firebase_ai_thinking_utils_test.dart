import 'package:dartantic_firebase_ai/src/firebase_ai_thinking_utils.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseAIThinkingUtils', () {
    test('disabled thinking returns null', () {
      final result = ChatResult<ChatMessage>(
        id: 'id-1',
        output: ChatMessage.model('hello'),
        messages: const [],
        finishReason: FinishReason.stop,
        metadata: const {},
        usage: null,
      );

      final thinking = FirebaseAIThinkingUtils.extractThinking(
        result,
        options: const FirebaseAIThinkingOptions(enabled: false),
      );
      expect(thinking, isNull);
    });

    test('extracts safety and reasoning metadata', () {
      final result = ChatResult<ChatMessage>(
        id: 'id-2',
        output: ChatMessage.model('Let me think about this'),
        messages: const [],
        finishReason: FinishReason.stop,
        metadata: const {
          'safety_ratings': [
            {'category': 'HARASSMENT', 'probability': 'LOW'},
          ],
          'finish_message': 'completed normally',
        },
        usage: null,
      );

      final thinking = FirebaseAIThinkingUtils.extractThinking(
        result,
        options: const FirebaseAIThinkingOptions(enabled: true),
      );
      expect(thinking, isNotNull);
      expect(thinking, contains('[SAFETY ANALYSIS]'));
      expect(thinking, contains('[COMPLETION REASONING]'));
    });

    test('addThinkingMetadata returns updated result', () {
      final result = ChatResult<ChatMessage>(
        id: 'id-3',
        output: ChatMessage.model('The reason is simple.'),
        messages: const [],
        finishReason: FinishReason.stop,
        metadata: const {'finish_message': 'done'},
        usage: null,
      );

      final updated = FirebaseAIThinkingUtils.addThinkingMetadata(
        result,
        const FirebaseAIThinkingOptions(enabled: true),
      );
      expect(updated.metadata.containsKey('thinking'), isTrue);
    });

    test('addThinkingMetadata returns original when disabled', () {
      final result = ChatResult<ChatMessage>(
        id: 'id-4',
        output: ChatMessage.model('hello'),
        messages: const [],
        finishReason: FinishReason.stop,
        metadata: const {'finish_message': 'done'},
        usage: null,
      );

      final updated = FirebaseAIThinkingUtils.addThinkingMetadata(
        result,
        const FirebaseAIThinkingOptions(enabled: false),
      );
      expect(updated, same(result));
    });
  });
}
