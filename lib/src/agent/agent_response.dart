import '../models/message.dart';

/// A response from an agent.
///
/// This class represents the response from an agent, containing the output
/// as a string. For typed responses, see [AgentResponseFor].
typedef AgentResponse = AgentResponseFor<String>;

/// A response from an agent.
///
/// This class represents the response from an agent, containing the output
/// as a typed object. For string responses, see [AgentResponse].
class AgentResponseFor<T> {
  /// Creates a new [AgentResponseFor] with the given [output].
  ///
  /// The [output] is the typed object response from the agent.
  AgentResponseFor({required this.output, required this.messages});

  /// The typed object output from the agent.
  final T output;

  /// The list of messages associated with the agent's response.
  final List<Message> messages;
}
