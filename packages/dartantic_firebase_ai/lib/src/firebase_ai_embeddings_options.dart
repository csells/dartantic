import 'package:dartantic_interface/dartantic_interface.dart';

/// Firebase AI-specific embeddings options.
///
/// These options are intentionally lightweight for now and provide a
/// provider-specific extension point as Firebase embeddings support is added.
class FirebaseAIEmbeddingsModelOptions extends EmbeddingsModelOptions {
  /// Creates Firebase AI embeddings options.
  const FirebaseAIEmbeddingsModelOptions({
    super.dimensions,
    super.batchSize = 100,
    this.taskType,
  });

  /// Optional task type hint for embedding generation.
  ///
  /// This is reserved for backend-specific behavior when embeddings are
  /// implemented (for example, query vs document style embeddings).
  final String? taskType;
}
