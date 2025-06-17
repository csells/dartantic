// ignore_for_file: avoid_print, lines_longer_than_80_chars, prefer_const_declarations, avoid_catches_without_on_clauses, prefer_int_literals

import 'dart:typed_data';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

// NOTE: these tests require environment variables to be set.
// I recommend using .vscode/settings.json like so:
//
// {
//   "dart.env": {
//     "GEMINI_API_KEY": "your_gemini_api_key",
//     "OPENAI_API_KEY": "your_openai_api_key"
//   }
// }

void main() {
  group('Embedding generation', () {
    Future<void> testCreateEmbedding(Provider provider) async {
      final agent = Agent.provider(provider);

      // Test document embedding
      final documentText =
          'This is a sample document for embedding generation.';
      final documentEmbedding = await agent.createEmbedding(
        documentText,
        type: EmbeddingType.document,
      );

      expect(
        documentEmbedding,
        isA<Float64List>(),
        reason: '${agent.displayName}: should return Float64List',
      );
      expect(
        documentEmbedding.length,
        greaterThan(0),
        reason: '${agent.displayName}: embedding should not be empty',
      );

      print(
        '${agent.displayName} document embedding length: ${documentEmbedding.length}',
      );

      // Test query embedding
      final queryText = 'What is this document about?';
      final queryEmbedding = await agent.createEmbedding(
        queryText,
        type: EmbeddingType.query,
      );

      expect(
        queryEmbedding,
        isA<Float64List>(),
        reason: '${agent.displayName}: should return Float64List',
      );
      expect(
        queryEmbedding.length,
        greaterThan(0),
        reason: '${agent.displayName}: embedding should not be empty',
      );

      print(
        '${agent.displayName} query embedding length: ${queryEmbedding.length}',
      );

      // Verify embedding dimensions are consistent
      expect(
        documentEmbedding.length,
        equals(queryEmbedding.length),
        reason: '${agent.displayName}: embeddings should have same dimensions',
      );

      // Test that embeddings contain meaningful values (not all zeros)
      final documentSum = documentEmbedding.fold<double>(
        0.0,
        (sum, value) => sum + value.abs(),
      );
      final querySum = queryEmbedding.fold<double>(
        0.0,
        (sum, value) => sum + value.abs(),
      );

      expect(
        documentSum,
        greaterThan(0.0),
        reason:
            '${agent.displayName}: document embedding should contain non-zero values',
      );
      expect(
        querySum,
        greaterThan(0.0),
        reason:
            '${agent.displayName}: query embedding should contain non-zero values',
      );

      print('${agent.displayName} document embedding sum: $documentSum');
      print('${agent.displayName} query embedding sum: $querySum');
    }

    test('createEmbedding: OpenAI', () async {
      await testCreateEmbedding(OpenAiProvider());
    });

    test('createEmbedding: Gemini', () async {
      await testCreateEmbedding(GeminiProvider());
    });

    Future<void> testEmbeddingSimilarity(Provider provider) async {
      final agent = Agent.provider(provider);

      // Create embeddings for similar texts
      final text1 = 'The cat sat on the mat.';
      final text2 = 'A cat is sitting on a mat.';
      final text3 = 'The weather is sunny today.';

      final embedding1 = await agent.createEmbedding(
        text1,
        type: EmbeddingType.document,
      );
      final embedding2 = await agent.createEmbedding(
        text2,
        type: EmbeddingType.document,
      );
      final embedding3 = await agent.createEmbedding(
        text3,
        type: EmbeddingType.document,
      );

      // Calculate cosine similarity using Agent's static method
      final similarity1vs2 = Agent.cosineSimilarity(embedding1, embedding2);
      final similarity1vs3 = Agent.cosineSimilarity(embedding1, embedding3);

      print(
        '${agent.displayName} similarity between similar texts: $similarity1vs2',
      );
      print(
        '${agent.displayName} similarity between different texts: $similarity1vs3',
      );

      // Similar texts should have higher similarity than different texts
      expect(
        similarity1vs2,
        greaterThan(similarity1vs3),
        reason:
            '${agent.displayName}: similar texts should have higher similarity',
      );

      // Both similarities should be positive
      expect(
        similarity1vs2,
        greaterThan(0.0),
        reason: '${agent.displayName}: similarity should be positive',
      );
    }

    test('embedding similarity comparison: OpenAI', () async {
      await testEmbeddingSimilarity(OpenAiProvider());
    });

    test('embedding similarity comparison: Gemini', () async {
      await testEmbeddingSimilarity(GeminiProvider());
    });

    Future<void> testEmbeddingTypesDifference(Provider provider) async {
      final agent = Agent.provider(provider);

      final text = 'Machine learning is a subset of artificial intelligence.';

      // Create embeddings with different types
      final documentEmbedding = await agent.createEmbedding(
        text,
        type: EmbeddingType.document,
      );
      final queryEmbedding = await agent.createEmbedding(
        text,
        type: EmbeddingType.query,
      );

      // Both should be valid embeddings
      expect(
        documentEmbedding.length,
        equals(queryEmbedding.length),
        reason: '${agent.displayName}: embeddings should have same dimensions',
      );

      // Calculate similarity between the two embeddings of the same text
      final similarity = Agent.cosineSimilarity(
        documentEmbedding,
        queryEmbedding,
      );

      print(
        '${agent.displayName} similarity between document and query embeddings of same text: $similarity',
      );

      // The embeddings should be similar but may not be identical due to different optimization
      expect(
        similarity,
        greaterThan(0.5),
        reason:
            '${agent.displayName}: same text with different types should still be similar',
      );
    }

    test('embedding types produce different optimizations: OpenAI', () async {
      await testEmbeddingTypesDifference(OpenAiProvider());
    });

    test('embedding types produce different optimizations: Gemini', () async {
      await testEmbeddingTypesDifference(GeminiProvider());
    });

    Future<void> testEmptyTextHandling(Provider provider) async {
      final agent = Agent.provider(provider);

      try {
        await agent.createEmbedding('', type: EmbeddingType.document);
        fail('${agent.displayName}: should throw exception for empty text');
      } on Exception catch (e) {
        // Expected to throw an exception
        expect(
          e,
          isNotNull,
          reason: '${agent.displayName}: should handle empty text gracefully',
        );
        print(
          '${agent.displayName} correctly handled empty text with error: $e',
        );
      }
    }

    test('empty text handling: OpenAI', () async {
      await testEmptyTextHandling(OpenAiProvider());
    });

    test('empty text handling: Gemini', () async {
      await testEmptyTextHandling(GeminiProvider());
    });

    test('createEmbedding with all primary providers', () async {
      final allProviders = [
        for (final providerName in ProviderTable.primaryProviders.keys)
          Agent.providerFor(providerName),
      ];

      expect(
        allProviders,
        isNotEmpty,
        reason: 'At least one provider should be available',
      );

      for (final provider in allProviders) {
        final agent = Agent.provider(provider);
        final embedding = await agent.createEmbedding(
          'Test embedding generation',
          type: EmbeddingType.document,
        );

        expect(
          embedding,
          isA<Float64List>(),
          reason: '${agent.displayName}: should return Float64List',
        );
        expect(
          embedding.length,
          greaterThan(0),
          reason: '${agent.displayName}: embedding should not be empty',
        );

        print(
          '${agent.displayName}: Successfully generated embedding with ${embedding.length} dimensions',
        );
      }
    });
  });
}
