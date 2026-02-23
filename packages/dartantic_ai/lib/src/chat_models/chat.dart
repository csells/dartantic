import 'package:dartantic_interface/dartantic_interface.dart';

import '../agent/agent.dart';

/// A chat session with an agent.
///
/// This class provides a simple interface for running a chat session with an
/// agent. It maintains a history of messages and provides methods to send a
/// prompt with an optional list of attachments to the agent and receive a
/// response.
class Chat {
  /// Creates a new chat session with the given [agent].
  ///
  /// The [agent] is the agent that will be used to run the chat session.
  /// The [history] is the history of messages in the chat session.
  Chat(this.agent, {List<ChatMessage>? history}) {
    this.history.addAll(history ?? []);
  }

  /// The agent that will be used to run the chat session.
  final Agent agent;

  /// The history of messages in the chat session.
  final history = List<ChatMessage>.empty(growable: true);

  /// The display name of the agent.
  String get displayName => agent.displayName;

  /// Sends a prompt to the agent and returns the result.
  ///
  /// The [prompt] is the prompt to run the agent with.
  /// The [attachments] are the attachments to send to the agent.
  /// The [outputSchema] is the output schema to send to the agent.
  Future<ChatResult<String>> send(
    String prompt, {
    List<Part> attachments = const [],
    Schema? outputSchema,
  }) async {
    final result = await agent.send(
      prompt,
      attachments: attachments,
      outputSchema: outputSchema,
      history: history,
    );
    history.addAll(result.messages);
    return result;
  }

  /// Runs the agent with the given prompt and returns the result.
  ///
  /// The [prompt] is the prompt to run the agent with.
  /// The [outputSchema] is the output schema to run the agent with.
  /// The [outputFromJson] is the function to use to convert the output to the
  /// desired type.
  Future<ChatResult<TOutput>> sendFor<TOutput extends Object>(
    String prompt, {
    required Schema outputSchema,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    List<Part> attachments = const [],
  }) async {
    final result = await agent.sendFor<TOutput>(
      prompt,
      attachments: attachments,
      outputSchema: outputSchema,
      outputFromJson: outputFromJson,
      history: history,
    );
    history.addAll(result.messages);
    return result;
  }

  /// Runs the agent with the given prompt and returns the result.
  ///
  /// The [prompt] is the prompt to run the agent with.
  /// The [attachments] are the attachments to run the agent with.
  /// The [outputSchema] is the output schema to run the agent with.
  Stream<ChatResult<String>> sendStream(
    String prompt, {
    List<Part> attachments = const [],
    Schema? outputSchema,
  }) => agent
      .sendStream(
        prompt,
        attachments: attachments,
        outputSchema: outputSchema,
        history: history,
      )
      .map((r) {
        history.addAll(r.messages);
        return r;
      });
}
