import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import 'firebase_ai_embeddings_options.dart';

/// Embeddings model for Firebase AI.
///
/// Firebase AI's public Flutter SDK currently does not expose an embeddings
/// endpoint. This model exists so provider APIs are fully wired and can evolve
/// without breaking changes once embeddings become available.
class FirebaseAIEmbeddingsModel
    extends EmbeddingsModel<FirebaseAIEmbeddingsModelOptions> {
  /// Creates a Firebase AI embeddings model handle.
  FirebaseAIEmbeddingsModel({
    required super.name,
    super.dimensions,
    super.batchSize,
    FirebaseAIEmbeddingsModelOptions? options,
  }) : super(
         defaultOptions:
             options ??
             FirebaseAIEmbeddingsModelOptions(
               dimensions: dimensions,
               batchSize: batchSize ?? 100,
             ),
       );

  static final Logger _logger = Logger('dartantic.embeddings.firebase_ai');

  @override
  Future<EmbeddingsResult> embedQuery(
    String query, {
    FirebaseAIEmbeddingsModelOptions? options,
  }) {
    final taskType = options?.taskType ?? defaultOptions.taskType;
    _logger.warning(
      'Firebase AI embeddings requested for model "$name" '
      '(taskType: $taskType), but embeddings are not available in '
      'firebase_ai yet.',
    );

    throw UnsupportedError(
      'Firebase AI embeddings are not supported by the current firebase_ai '
      'Flutter SDK. Requested model: $name.',
    );
  }

  @override
  Future<BatchEmbeddingsResult> embedDocuments(
    List<String> texts, {
    FirebaseAIEmbeddingsModelOptions? options,
  }) {
    final taskType = options?.taskType ?? defaultOptions.taskType;
    _logger.warning(
      'Firebase AI batch embeddings requested for model "$name" '
      '(texts: ${texts.length}, taskType: $taskType), but embeddings are not '
      'available in firebase_ai yet.',
    );

    throw UnsupportedError(
      'Firebase AI embeddings are not supported by the current firebase_ai '
      'Flutter SDK. Requested model: $name.',
    );
  }

  @override
  void dispose() {}
}
