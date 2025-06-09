import '../../agent/agent.dart';
import '../message.dart';

/// Abstract interface for AI model implementations.
///
/// Defines the contract that all model implementations must follow to
/// support running prompts and receiving responses.
abstract class Model {
  /// Runs the given [prompt] through the model and returns the response.
  ///
  /// Returns an [AgentResponse] containing the model's output.
  Stream<AgentResponse> runStream({
    required String prompt,
    required List<Message> messages,
  });
}
