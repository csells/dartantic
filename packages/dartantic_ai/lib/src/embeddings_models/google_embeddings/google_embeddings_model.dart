import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:googleai_dart/googleai_dart.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../../providers/google_api_utils.dart';
import '../chunk_list.dart';
import 'google_embeddings_model_options.dart';

/// Google AI embeddings model implementation.
class GoogleEmbeddingsModel
    extends EmbeddingsModel<GoogleEmbeddingsModelOptions> {
  /// Creates a new Google AI embeddings model.
  GoogleEmbeddingsModel({
    required String apiKey,
    required Uri baseUrl,
    http.Client? client,
    Map<String, String>? headers,
    String? name,
    super.dimensions,
    super.batchSize = 100,
    GoogleEmbeddingsModelOptions? options,
  }) : _client = createGoogleAiClient(
         apiKey: apiKey,
         configuredBaseUrl: baseUrl,
         extraHeaders: headers ?? const {},
         httpClient: client,
       ),
       super(
         name: name ?? defaultName,
         defaultOptions:
             options ??
             GoogleEmbeddingsModelOptions(
               dimensions: dimensions,
               batchSize: batchSize,
             ),
       ) {
    _logger.info(
      'Created Google embeddings model: ${this.name} '
      '(dimensions: $dimensions, batchSize: $batchSize)',
    );
  }

  static final _logger = Logger('dartantic.embeddings.models.google');

  /// The default model name.
  static const defaultName = 'gemini-embedding-001';

  final ga.GoogleAIClient _client;

  /// The configured API base URL (including version path when provided).
  @visibleForTesting
  Uri get resolvedBaseUrl => Uri.parse(_client.config.baseUrl);

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    GoogleEmbeddingsModelOptions? options,
  }) async {
    final queryLength = query.length;
    final effectiveDimensions = options?.dimensions ?? dimensions;

    _logger.fine(
      'Embedding query with Google model "$name" '
      '(length: $queryLength, dimensions: $effectiveDimensions)',
    );

    final modelId = googleModelIdForApiRequest(name);
    final request = ga.EmbedContentRequest(
      content: ga.Content(parts: [ga.TextPart(query)]),
      taskType: ga.TaskType.retrievalQuery,
      outputDimensionality: effectiveDimensions,
    );

    final response = await _client.models.embedContent(
      model: modelId,
      request: request,
    );
    final embedding = response.embedding.values;

    // Google doesn't provide token usage, so estimate
    final estimatedTokens = (queryLength / 4).round();

    _logger.fine(
      'Google embedding query completed '
      '(estimated tokens: $estimatedTokens)',
    );

    final result = EmbeddingsResult(
      output: embedding,
      finishReason: FinishReason.stop,
      metadata: {
        'model': name,
        'dimensions': effectiveDimensions,
        'query_length': queryLength,
        'task_type': 'retrievalQuery',
      },
      usage: LanguageModelUsage(
        promptTokens: estimatedTokens,
        promptBillableCharacters: queryLength,
        totalTokens: estimatedTokens,
      ),
    );

    _logger.info(
      'Google embedding query result: '
      '${result.output.length} dimensions, '
      '${result.usage?.totalTokens ?? 0} estimated tokens',
    );

    return result;
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    GoogleEmbeddingsModelOptions? options,
  }) async {
    if (texts.isEmpty) {
      return BatchEmbeddingsResult(
        output: const <List<double>>[],
        finishReason: FinishReason.stop,
        metadata: const <String, dynamic>{},
        usage: const LanguageModelUsage(totalTokens: 0),
      );
    }

    final effectiveBatchSize = options?.batchSize ?? batchSize ?? 100;
    final effectiveDimensions = options?.dimensions ?? dimensions;
    final batches = chunkList(texts, chunkSize: effectiveBatchSize);
    final totalTexts = texts.length;
    final totalCharacters = texts.map((t) => t.length).reduce((a, b) => a + b);

    _logger.info(
      'Embedding $totalTexts documents with Google model "$name" '
      '(batches: ${batches.length}, batchSize: $effectiveBatchSize, '
      'dimensions: $effectiveDimensions, totalChars: $totalCharacters)',
    );

    final allEmbeddings = <List<double>>[];
    final modelId = googleModelIdForApiRequest(name);

    for (var i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final batchCharacters = batch.isEmpty
          ? 0
          : batch.map((t) => t.length).reduce((a, b) => a + b);

      _logger.fine(
        'Processing batch ${i + 1}/${batches.length} '
        '(${batch.length} texts, $batchCharacters chars)',
      );

      final request = ga.BatchEmbedContentsRequest(
        requests: batch
            .map(
              (text) => ga.EmbedContentRequest(
                content: ga.Content(parts: [ga.TextPart(text)]),
                taskType: ga.TaskType.retrievalDocument,
                outputDimensionality: effectiveDimensions,
              ),
            )
            .toList(growable: false),
      );

      final response = await _client.models.batchEmbedContents(
        model: modelId,
        request: request,
      );
      final batchEmbeddings = response.embeddings
          .map((embedding) => embedding.values)
          .toList(growable: false);
      allEmbeddings.addAll(batchEmbeddings);

      _logger.fine(
        'Batch ${i + 1} completed: '
        '${batchEmbeddings.length} embeddings',
      );
    }

    // Google doesn't provide token usage, so estimate
    final estimatedTokens = (totalCharacters / 4).round();

    final result = BatchEmbeddingsResult(
      output: allEmbeddings,
      finishReason: FinishReason.stop,
      metadata: {
        'model': name,
        'dimensions': effectiveDimensions,
        'batch_count': batches.length,
        'total_texts': totalTexts,
        'total_characters': totalCharacters,
      },
      usage: LanguageModelUsage(
        promptTokens: estimatedTokens,
        promptBillableCharacters: totalCharacters,
        totalTokens: estimatedTokens,
      ),
    );

    _logger.info(
      'Google batch embedding completed: '
      '${result.output.length} embeddings, '
      '${result.usage?.totalTokens ?? 0} estimated tokens',
    );

    return result;
  }

  @override
  void dispose() {
    _client.close();
  }
}
