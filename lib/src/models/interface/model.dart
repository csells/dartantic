import 'dart:typed_data';

import '../../agent/agent.dart';

/// Abstract interface for AI model implementations.
///
/// Defines the contract that all model implementations must follow to
/// support running prompts and receiving responses.
abstract class Model {
  /// The display name of this model.
  ///
  /// Usually includes the provider family and model name (e.g.,
  /// "openai:gpt-4").
  String get displayName;

  /// Runs the given [prompt] through the model and returns the response.
  ///
  /// Returns an [AgentResponse] containing the model's output.
  Stream<AgentResponse> runStream({
    required String prompt,
    required List<Message> messages,
  });

  /// Generates an embedding vector for the given [text].
  ///
  /// The [type] parameter specifies whether this embedding is for a document
  /// (content to be stored and searched) or a query (search input).
  ///
  /// Returns a Float64List of floating-point values representing the text's
  /// position in high-dimensional semantic space, suitable for similarity
  /// calculations.
  Future<Float64List> createEmbedding(
    String text, {
    EmbeddingType type = EmbeddingType.document,
  });
}
