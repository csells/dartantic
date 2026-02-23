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
      expect(provider.aliases, contains('firebase-google'));
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

    test('creates embeddings and media models', () {
      final provider = FirebaseAIProvider();
      final embeddingsModel = provider.createEmbeddingsModel();
      final mediaModel = provider.createMediaModel();

      expect(embeddingsModel, isA<FirebaseAIEmbeddingsModel>());
      expect(mediaModel, isA<FirebaseAIMediaGenerationModel>());
    });

    test('supports Imagen and Gemini media option variants', () {
      final provider = FirebaseAIProvider();

      final imagenModel = provider.createMediaModel(
        options: const FirebaseAIMediaGenerationModelOptions.imagen(
          imageSampleCount: 2,
          responseMimeType: 'image/png',
          safetySettings: FirebaseAIImagenSafetySettings(
            safetyFilterLevel:
                FirebaseAIImagenSafetyFilterLevel.blockMediumAndAbove,
            personFilterLevel: FirebaseAIImagenPersonFilterLevel.allowAdult,
          ),
        ),
      );
      expect(
        imagenModel.defaultOptions,
        isA<FirebaseAIImagenMediaGenerationModelOptions>(),
      );
      expect(
        (imagenModel.defaultOptions
                as FirebaseAIImagenMediaGenerationModelOptions)
            .safetySettings?.safetyFilterLevel,
        FirebaseAIImagenSafetyFilterLevel.blockMediumAndAbove,
      );

      final geminiModel = provider.createMediaModel(
        name: 'gemini-2.5-flash',
        options: const FirebaseAIMediaGenerationModelOptions.gemini(
          imageSampleCount: 1,
          responseMimeType: 'image/png',
          safetySettings: [
            FirebaseAISafetySetting(
              category: FirebaseAISafetySettingCategory.harassment,
              threshold: FirebaseAISafetySettingThreshold.blockOnlyHigh,
            ),
          ],
        ),
      );
      expect(
        geminiModel.defaultOptions,
        isA<FirebaseAIGeminiMediaGenerationModelOptions>(),
      );
      expect(
        (geminiModel.defaultOptions
                as FirebaseAIGeminiMediaGenerationModelOptions)
            .safetySettings,
        hasLength(1),
      );
    });

    test('embeddings model reports unsupported operation on use', () {
      final provider = FirebaseAIProvider();
      final model = provider.createEmbeddingsModel();

      expect(
        () => model.embedQuery('hello'),
        throwsA(isA<UnsupportedError>()),
      );
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
