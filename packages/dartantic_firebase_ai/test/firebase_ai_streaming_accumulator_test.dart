import 'package:dartantic_firebase_ai/src/firebase_ai_streaming_accumulator.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('FirebaseAIStreamingAccumulator', () {
    test('accumulates text chunks', () {
      final acc = FirebaseAIStreamingAccumulator(modelName: 'gemini-2.5-flash');

      acc.add(
        ChatResult<ChatMessage>(
          id: '1',
          output: ChatMessage.model('Hello '),
          messages: const [],
          finishReason: FinishReason.unspecified,
          metadata: const {},
          usage: null,
        ),
      );
      acc.add(
        ChatResult<ChatMessage>(
          id: '2',
          output: ChatMessage.model('world'),
          messages: const [],
          finishReason: FinishReason.stop,
          metadata: const {},
          usage: const LanguageModelUsage(totalTokens: 10),
        ),
      );

      final result = acc.buildFinal();
      expect(result.output.text, 'Hello world');
      expect(result.finishReason, FinishReason.stop);
      expect(result.usage?.totalTokens, 10);
      expect(acc.chunkCount, 2);
    });

    test('accumulates thinking and safety metadata', () {
      final acc = FirebaseAIStreamingAccumulator(modelName: 'gemini-2.5-flash');

      acc.add(
        ChatResult<ChatMessage>(
          id: '1',
          output: ChatMessage.model('A'),
          messages: const [],
          finishReason: FinishReason.unspecified,
          metadata: const {
            'thinking': 'step1',
            'safety_ratings': [
              {'category': 'HARASSMENT', 'probability': 'LOW'},
            ],
          },
          usage: null,
        ),
      );

      final result = acc.buildFinal();
      expect(result.metadata['thinking'], 'step1');
      expect(result.metadata['safety_ratings'] as List, hasLength(1));
    });

    test('deduplicates citation metadata values', () {
      final acc = FirebaseAIStreamingAccumulator(modelName: 'gemini-2.5-flash');

      acc.add(
        ChatResult<ChatMessage>(
          id: '1',
          output: ChatMessage.model('A'),
          messages: const [],
          finishReason: FinishReason.unspecified,
          metadata: const {'citation_metadata': 'source-1'},
          usage: null,
        ),
      );
      acc.add(
        ChatResult<ChatMessage>(
          id: '2',
          output: ChatMessage.model('B'),
          messages: const [],
          finishReason: FinishReason.stop,
          metadata: const {'citation_metadata': 'source-1'},
          usage: null,
        ),
      );

      final result = acc.buildFinal();
      expect(result.metadata['citation_metadata'], 'source-1');
    });
  });
}
