import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';

/// Options for Ollama embeddings models.
@immutable
class OllamaEmbeddingsModelOptions extends EmbeddingsModelOptions {
  /// Creates new Ollama embeddings model options.
  const OllamaEmbeddingsModelOptions({
    super.dimensions,
    super.batchSize,
    this.truncate,
    this.keepAlive,
  });

  /// If true, truncate inputs that exceed the context window.
  final bool? truncate;

  /// How long to keep the model loaded in memory.
  final String? keepAlive;
}
