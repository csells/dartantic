import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart';

import '../chunk_list.dart';
import 'ollama_embeddings_model_options.dart';

/// Ollama embeddings model implementation.
class OllamaEmbeddingsModel
    extends EmbeddingsModel<OllamaEmbeddingsModelOptions> {
  /// Creates a new Ollama embeddings model.
  OllamaEmbeddingsModel({
    required super.name,
    Uri? baseUrl,
    http.Client? client,
    Map<String, String>? headers,
    super.dimensions,
    super.batchSize = 100,
    OllamaEmbeddingsModelOptions? options,
  }) : _client = OllamaClient(
         config: OllamaConfig(
           baseUrl: baseUrl?.toString() ?? 'http://localhost:11434',
           defaultHeaders: headers ?? {},
         ),
         httpClient: client,
       ),
       super(defaultOptions: options ?? const OllamaEmbeddingsModelOptions()) {
    _logger.info(
      'Created Ollama embeddings model: $name '
      '(dimensions: $dimensions, batchSize: $batchSize)',
    );
  }

  static final _logger = Logger('dartantic.embeddings.models.ollama');
  final OllamaClient _client;

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    OllamaEmbeddingsModelOptions? options,
  }) async {
    final queryLength = query.length;

    _logger.fine(
      'Embedding query with Ollama model "$name" '
      '(length: $queryLength)',
    );

    final result = await embedDocuments([query], options: options);

    final queryResult = EmbeddingsResult(
      id: result.id,
      output: result.embeddings.first,
      finishReason: result.finishReason,
      usage: result.usage,
      metadata: result.metadata,
    );

    _logger.info(
      'Ollama embedding query result: '
      '${queryResult.output.length} dimensions, '
      '${queryResult.usage?.totalTokens ?? 0} tokens',
    );

    return queryResult;
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    OllamaEmbeddingsModelOptions? options,
  }) async {
    if (texts.isEmpty) {
      return BatchEmbeddingsResult(
        output: const [],
        finishReason: FinishReason.stop,
        metadata: {'model': name, 'provider': 'ollama'},
        usage: const LanguageModelUsage(),
      );
    }

    final actualBatchSize = options?.batchSize ?? batchSize ?? 100;
    final totalTexts = texts.length;
    final totalCharacters = texts.map((t) => t.length).fold(0, (a, b) => a + b);
    final chunks = chunkList(texts, chunkSize: actualBatchSize);

    _logger.info(
      'Embedding $totalTexts documents with Ollama model "$name" '
      '(batches: ${chunks.length}, batchSize: $actualBatchSize, '
      'totalChars: $totalCharacters)',
    );

    final allEmbeddings = <List<double>>[];
    var totalPromptTokens = 0;

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final chunkCharacters = chunk
          .map((t) => t.length)
          .fold(0, (a, b) => a + b);

      _logger.fine(
        'Processing batch ${i + 1}/${chunks.length} '
        '(${chunk.length} texts, $chunkCharacters chars)',
      );

      final actualDimensions = options?.dimensions ?? dimensions;
      final actualTruncate = options?.truncate ?? defaultOptions.truncate;
      final actualKeepAlive = options?.keepAlive ?? defaultOptions.keepAlive;

      final response = await _client.embeddings.create(
        request: EmbedRequest(
          model: name,
          input: chunk,
          truncate: actualTruncate,
          dimensions: actualDimensions,
          keepAlive: actualKeepAlive,
        ),
      );

      // Handle both single embedding (embedding) and batch (embeddings)
      final batchEmbeddings =
          response.embeddings ??
          (response.embedding != null
              ? <List<double>>[response.embedding!]
              : const <List<double>>[]);
      if (batchEmbeddings.length != chunk.length) {
        throw StateError(
          'Expected ${chunk.length} embeddings for batch ${i + 1}, '
          'received ${batchEmbeddings.length}.',
        );
      }
      allEmbeddings.addAll(batchEmbeddings);

      // Accumulate usage data
      totalPromptTokens += response.promptEvalCount ?? 0;

      _logger.fine(
        'Batch ${i + 1} completed: '
        '${chunk.length} embeddings, '
        '${response.promptEvalCount ?? 0} tokens',
      );
    }

    final usage = LanguageModelUsage(
      promptTokens: totalPromptTokens > 0 ? totalPromptTokens : null,
      totalTokens: totalPromptTokens > 0 ? totalPromptTokens : null,
    );

    final result = BatchEmbeddingsResult(
      output: allEmbeddings,
      finishReason: FinishReason.stop,
      usage: usage,
      metadata: {'model': name, 'provider': 'ollama'},
    );

    _logger.info(
      'Ollama batch embedding completed: '
      '${result.output.length} embeddings, '
      '${result.usage?.totalTokens ?? 0} total tokens',
    );

    return result;
  }

  @override
  void dispose() => _client.close();
}
