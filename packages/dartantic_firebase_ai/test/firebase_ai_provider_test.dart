import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

import 'mock_firebase.dart';
import 'test_helpers/run_provider_test_helper.dart';

void main() {
  group('FirebaseAIProvider', () {
    setUpAll(() async {
      await initializeMockFirebase();
    });

    runProviderTest('has expected identity and defaults', (provider) async {
      expect(provider.name, 'firebase_ai');
      expect(provider.defaultModelNames[ModelKind.chat], 'gemini-2.5-flash');
      expect(
        provider.defaultModelNames[ModelKind.media],
        'imagen-4.0-generate-001',
      );
      expect(provider.aliases, isNotEmpty);
    }, requiredCaps: {ProviderTestCaps.chat});

    runProviderTest('creates chat model', (provider) async {
      final model = provider.createChatModel(name: 'gemini-2.5-flash');
      expect(model, isA<FirebaseAIChatModel>());
      expect(model.name, 'gemini-2.5-flash');
    }, requiredCaps: {ProviderTestCaps.chat});

    runProviderTest('rejects out-of-range temperature', (provider) async {
      expect(
        () => provider.createChatModel(temperature: -0.1),
        throwsArgumentError,
      );
      expect(
        () => provider.createChatModel(temperature: 2.1),
        throwsArgumentError,
      );
    }, requiredCaps: {ProviderTestCaps.chat});

    runProviderTest('creates media model', (provider) async {
      final mediaModel = provider.createMediaModel();

      expect(mediaModel, isA<FirebaseAIMediaGenerationModel>());
    }, requiredCaps: {ProviderTestCaps.mediaGeneration});

    runProviderTest(
      'supports Imagen and Gemini media option variants',
      (provider) async {
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
              .safetySettings
              ?.safetyFilterLevel,
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
      },
      requiredCaps: {ProviderTestCaps.mediaGeneration},
    );

    runProviderTest('createEmbeddingsModel throws UnsupportedError', (
      provider,
    ) async {
      expect(
        () => provider.createEmbeddingsModel(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    runProviderTest('lists chat and media models', (provider) async {
      final models = await provider.listModels().toList();
      expect(models, isNotEmpty);
      expect(models.any((m) => m.kinds.contains(ModelKind.chat)), isTrue);
      expect(models.any((m) => m.kinds.contains(ModelKind.media)), isTrue);
      expect(models.every((m) => m.providerName == 'firebase_ai'), isTrue);
    }, requiredCaps: {ProviderTestCaps.chat});
  });
}
