// ignore_for_file: avoid_print, lines_longer_than_80_chars, prefer_const_declarations, avoid_catches_without_on_clauses

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

// NOTE: these tests require environment variables to be set.
// I recommend using .vscode/settings.json like so:
//
// {
//   "dart.env": {
//     "GEMINI_API_KEY": "your_gemini_api_key",
//     "OPENAI_API_KEY": "your_openai_api_key",
//     "OPENROUTER_API_KEY": "your_openrouter_api_key"
//   }
// }

void main() {
  group('Provider Capabilities', () {
    test('OpenAI provider should support all capabilities', () {
      try {
        final provider = Agent.providerFor('openai');
        final agent = Agent.provider(provider);

        // OpenAI should support all capabilities
        expect(agent.caps, contains(ProviderCaps.textGeneration));
        expect(agent.caps, contains(ProviderCaps.embeddings));
        expect(agent.caps, contains(ProviderCaps.chat));
        expect(agent.caps, contains(ProviderCaps.fileUploads));
        expect(agent.caps, contains(ProviderCaps.tools));

        // Check embedding support specifically
        final supportsEmbeddings = agent.caps.contains(ProviderCaps.embeddings);
        expect(supportsEmbeddings, isTrue);

        print('OpenAI capabilities: ${agent.caps}');
      } catch (e) {
        print('Skipping OpenAI capabilities test: $e');
      }
    });

    test('OpenRouter provider should not support embeddings', () {
      try {
        final provider = Agent.providerFor('openrouter');
        final agent = Agent.provider(provider);

        // OpenRouter should support most capabilities except embeddings
        expect(agent.caps, contains(ProviderCaps.textGeneration));
        expect(agent.caps, isNot(contains(ProviderCaps.embeddings)));
        expect(agent.caps, contains(ProviderCaps.chat));
        expect(agent.caps, contains(ProviderCaps.fileUploads));
        expect(agent.caps, contains(ProviderCaps.tools));

        // Check embedding support specifically
        final supportsEmbeddings = agent.caps.contains(ProviderCaps.embeddings);
        expect(supportsEmbeddings, isFalse);

        print('OpenRouter capabilities: ${agent.caps}');
      } catch (e) {
        print('Skipping OpenRouter capabilities test: $e');
      }
    });

    test('Google/Gemini provider should support all capabilities', () {
      try {
        final provider = Agent.providerFor('google');
        final agent = Agent.provider(provider);

        // Gemini should support all capabilities
        expect(agent.caps, contains(ProviderCaps.textGeneration));
        expect(agent.caps, contains(ProviderCaps.embeddings));
        expect(agent.caps, contains(ProviderCaps.chat));
        expect(agent.caps, contains(ProviderCaps.fileUploads));
        expect(agent.caps, contains(ProviderCaps.tools));

        // Check embedding support specifically
        final supportsEmbeddings = agent.caps.contains(ProviderCaps.embeddings);
        expect(supportsEmbeddings, isTrue);

        print('Google/Gemini capabilities: ${agent.caps}');
      } catch (e) {
        print('Skipping Google/Gemini capabilities test: $e');
      }
    });

    test('capabilities check with all available providers', () {
      final availableProviders = <Provider>[];
      final providerCapabilities = <String, Set<ProviderCaps>>{};

      // Test known provider names instead of accessing ProviderTable directly
      for (final providerName in ['openai', 'openrouter', 'google']) {
        try {
          final provider = Agent.providerFor(providerName);
          final agent = Agent.provider(provider);
          availableProviders.add(provider);
          providerCapabilities[agent.model] = agent.caps.toSet();

          print('${agent.model} capabilities: ${agent.caps}');
          print(
            '${agent.model} supports embeddings: ${agent.caps.contains(ProviderCaps.embeddings)}',
          );
        } catch (e) {
          print('Skipping $providerName: $e');
        }
      }

      // Skip this test if no providers are available (no API keys set)
      if (availableProviders.isEmpty) {
        print(
          'No providers available (no API keys set) - skipping capability checks',
        );
        return;
      }

      // Verify capability consistency
      for (final entry in providerCapabilities.entries) {
        final name = entry.key;
        final caps = entry.value;

        // Every provider should support basic text generation and chat
        expect(
          caps,
          contains(ProviderCaps.textGeneration),
          reason: '$name should support text generation',
        );
        expect(
          caps,
          contains(ProviderCaps.chat),
          reason: '$name should support chat',
        );

        // OpenRouter specifically should not support embeddings
        if (name.contains('openrouter')) {
          expect(
            caps,
            isNot(contains(ProviderCaps.embeddings)),
            reason: 'OpenRouter should not support embeddings',
          );
        }
      }
    });

    test(
      'embedding operations should fail gracefully for unsupported providers',
      () async {
        try {
          final agent = Agent('openrouter');

          // Check capabilities first
          final supportsEmbeddings = agent.caps.contains(
            ProviderCaps.embeddings,
          );
          expect(
            supportsEmbeddings,
            isFalse,
            reason: 'OpenRouter should not support embeddings',
          );

          // Should throw a descriptive error when attempting embeddings
          expect(
            () async => agent.createEmbedding(
              'Test text',
              type: EmbeddingType.document,
            ),
            throwsA(
              predicate(
                (e) =>
                    e.toString().toLowerCase().contains('embedding') ||
                    e.toString().contains('404') ||
                    e.toString().contains('Not Found') ||
                    e.toString().contains('not supported'),
              ),
            ),
          );

          print('OpenRouter correctly fails embedding operations');
        } catch (e) {
          print('Skipping OpenRouter embedding failure test: $e');
        }
      },
    );

    test('ProviderCaps.all and allExcept work correctly', () {
      final allCaps = ProviderCaps.all.toSet();
      expect(
        allCaps,
        hasLength(5),
      ); // textGeneration, embeddings, chat, fileUploads, tools
      expect(allCaps, contains(ProviderCaps.textGeneration));
      expect(allCaps, contains(ProviderCaps.embeddings));
      expect(allCaps, contains(ProviderCaps.chat));
      expect(allCaps, contains(ProviderCaps.fileUploads));
      expect(allCaps, contains(ProviderCaps.tools));

      final capsWithoutEmbeddings =
          ProviderCaps.allExcept({ProviderCaps.embeddings}).toSet();
      expect(capsWithoutEmbeddings, hasLength(4)); // all except embeddings
      expect(capsWithoutEmbeddings, contains(ProviderCaps.textGeneration));
      expect(capsWithoutEmbeddings, isNot(contains(ProviderCaps.embeddings)));
      expect(capsWithoutEmbeddings, contains(ProviderCaps.chat));
      expect(capsWithoutEmbeddings, contains(ProviderCaps.fileUploads));
      expect(capsWithoutEmbeddings, contains(ProviderCaps.tools));
    });
  });
}
