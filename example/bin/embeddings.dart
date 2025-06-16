// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  await embeddingExample();
}

Future<void> embeddingExample() async {
  print('embeddingExample');

  final agent = Agent('openai');

  // Generate embeddings for different types of content
  const documentText =
      'Machine learning is a subset of artificial '
      'intelligence that enables computers to learn and make decisions '
      'from data.';
  const queryText = 'What is machine learning?';
  const unrelatedText = 'The weather today is sunny and warm.';

  // Create document embedding
  final documentEmbedding = await agent.createEmbedding(
    documentText,
    type: EmbeddingType.document,
  );
  print('Document embedding created: ${documentEmbedding.length} dimensions');

  // Create query embedding
  final queryEmbedding = await agent.createEmbedding(
    queryText,
    type: EmbeddingType.query,
  );
  print('Query embedding created: ${queryEmbedding.length} dimensions');

  // Create embedding for unrelated content
  final unrelatedEmbedding = await agent.createEmbedding(
    unrelatedText,
    type: EmbeddingType.document,
  );
  print('Unrelated embedding created: ${unrelatedEmbedding.length} dimensions');

  // Calculate similarities using cosine similarity
  final docQuerySimilarity = Agent.cosineSimilarity(
    documentEmbedding,
    queryEmbedding,
  );
  final docUnrelatedSimilarity = Agent.cosineSimilarity(
    documentEmbedding,
    unrelatedEmbedding,
  );

  print(
    '\nSimilarity between document and query: '
    '${docQuerySimilarity.toStringAsFixed(4)}',
  );
  print(
    'Similarity between document and unrelated: '
    '${docUnrelatedSimilarity.toStringAsFixed(4)}',
  );

  // The query should be more similar to the document than the unrelated text
  if (docQuerySimilarity > docUnrelatedSimilarity) {
    print('✓ Query is more similar to document than unrelated text');
  } else {
    print('✗ Unexpected similarity results');
  }

  // Test with Gemini provider for comparison
  print('\nTesting with Gemini provider...');
  final geminiAgent = Agent('gemini');

  final geminiDocEmbedding = await geminiAgent.createEmbedding(
    documentText,
    type: EmbeddingType.document,
  );
  print('Gemini document embedding: ${geminiDocEmbedding.length} dimensions');

  final geminiQueryEmbedding = await geminiAgent.createEmbedding(
    queryText,
    type: EmbeddingType.query,
  );

  final geminiSimilarity = Agent.cosineSimilarity(
    geminiDocEmbedding,
    geminiQueryEmbedding,
  );
  print('Gemini similarity: ${geminiSimilarity.toStringAsFixed(4)}');
}
