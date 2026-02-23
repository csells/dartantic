import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

import 'mock_firebase.dart';

void main() {
  group('FirebaseAIProvider', () {
    setUpAll(() async {
      await initializeMockFirebase();
    });

    test('has expected identity and defaults', () {
      final provider = FirebaseAIProvider();
      expect(provider.name, 'firebase_ai');
      expect(provider.defaultModelNames[ModelKind.chat], 'gemini-2.5-flash');
      expect(
        provider.defaultModelNames[ModelKind.media],
        'gemini-2.5-flash-image',
      );
      expect(provider.aliases, contains('firebase-vertex'));
    });

    test('creates chat model', () {
      final provider = FirebaseAIProvider();
      final model = provider.createChatModel(name: 'gemini-2.5-flash');
      expect(model, isA<FirebaseAIChatModel>());
      expect(model.name, 'gemini-2.5-flash');
    });

    test('rejects invalid model names', () {
      final provider = FirebaseAIProvider();
      expect(
        () => provider.createChatModel(name: 'gpt-4o'),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range temperature', () {
      final provider = FirebaseAIProvider();
      expect(
        () => provider.createChatModel(temperature: -0.1),
        throwsArgumentError,
      );
      expect(
        () => provider.createChatModel(temperature: 2.1),
        throwsArgumentError,
      );
    });

    test('embeddings/media are currently unimplemented', () {
      final provider = FirebaseAIProvider();
      expect(provider.createEmbeddingsModel, throwsUnimplementedError);
      expect(provider.createMediaModel, throwsUnimplementedError);
    });

    test('lists chat models', () async {
      final provider = FirebaseAIProvider();
      final models = await provider.listModels().toList();
      expect(models, isNotEmpty);
      expect(models.any((m) => m.kinds.contains(ModelKind.chat)), isTrue);
      expect(models.every((m) => m.providerName == 'firebase_ai'), isTrue);
    });
  });
}
