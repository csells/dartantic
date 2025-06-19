import 'package:dartantic_ai/src/platform/platform.dart' as platform;
import 'package:dartantic_ai/src/providers/implementation/gemini_provider.dart';
import 'package:dartantic_ai/src/providers/implementation/openai_provider.dart';
import 'package:test/test.dart';

void main() {
  group('Model Stability Detection', () {
    test('GeminiProvider sets stable field correctly', () async {
      final apiKey = platform.getEnv('GEMINI_API_KEY');
      final provider = GeminiProvider(apiKey: apiKey);
      final models = await provider.listModels();
      final modelMap = {for (final model in models) model.name: model};

      expect(models.isNotEmpty, isTrue);

      // Known stable Gemini models
      const knownStableModels = [
        'gemini-1.5-pro',
        'gemini-1.5-flash',
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'text-embedding-004',
        'embedding-001',
        'gemini-2.0-flash-lite',
      ];

      // Known unstable Gemini models (preview/experimental/dated/versioned/variants/latest)
      const knownUnstableModels = [
        'gemini-2.5-pro-exp-03-25',
        'gemini-2.5-pro-preview-03-25',
        'gemini-2.5-flash-preview-04-17',
        'gemini-2.0-flash-thinking-exp-01-21',
        'learnlm-2.0-flash-experimental',
        'gemini-1.5-flash-002',
        'gemini-1.5-flash-8b',
        'gemini-2.0-flash-exp',
        'gemini-2.0-flash-lite-001',
        'gemini-1.0-pro-vision-latest',
        'gemini-1.5-pro-latest',
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash-8b-latest',
      ];

      // Check known stable models
      for (final modelName in knownStableModels) {
        final model = modelMap[modelName];
        if (model == null) {
          throw Exception(
            'Known stable model $modelName not found in provider response',
          );
        }
        expect(
          model.stable,
          isTrue,
          reason: 'Known stable model $modelName should be marked as stable',
        );
      }

      // Check known unstable models
      for (final modelName in knownUnstableModels) {
        final model = modelMap[modelName];
        if (model == null) {
          throw Exception(
            'Known unstable model $modelName not found in provider response',
          );
        }
        expect(
          model.stable,
          isFalse,
          reason:
              'Known unstable model $modelName should be marked as unstable',
        );
      }
    });

    test('OpenAI Provider sets stable field correctly', () async {
      final apiKey = platform.getEnv('OPENAI_API_KEY');
      final provider = OpenAiProvider(apiKey: apiKey);
      final models = await provider.listModels();
      final modelMap = {for (final model in models) model.name: model};

      expect(models.isNotEmpty, isTrue);

      // Known stable OpenAI models (no dates or preview markers)
      const knownStableModels = [
        'gpt-4',
        'gpt-4o',
        'gpt-4o-mini',
        'gpt-4-turbo',
        'gpt-3.5-turbo',
        'text-embedding-3-large',
        'text-embedding-3-small',
        'text-embedding-ada-002',
      ];

      // Known unstable OpenAI models (preview/beta/alpha/dates/latest)
      const knownUnstableModels = [
        'gpt-4-1106-preview',
        'gpt-4-0125-preview',
        'gpt-4-turbo-preview',
        'o1-preview',
        'gpt-4o-audio-preview',
        'gpt-4.5-preview',
        'gpt-3.5-turbo-instruct-0914',
        'gpt-4o-2024-05-13',
        'o1-mini-2024-09-12',
        'codex-mini-latest',
        'chatgpt-4o-latest',
        'omni-moderation-latest',
      ];

      // Check known stable models
      for (final modelName in knownStableModels) {
        final model = modelMap[modelName];
        if (model == null) {
          throw Exception(
            'Known stable model $modelName not found in provider response',
          );
        }
        expect(
          model.stable,
          isTrue,
          reason: 'Known stable model $modelName should be marked as stable',
        );
      }

      // Check known unstable models
      for (final modelName in knownUnstableModels) {
        final model = modelMap[modelName];
        if (model == null) {
          throw Exception(
            'Known unstable model $modelName not found in provider response',
          );
        }
        expect(
          model.stable,
          isFalse,
          reason:
              'Known unstable model $modelName should be marked as unstable',
        );
      }
    });
  });
}
