import 'dart:convert';

import 'package:dotprompt_dart/dotprompt_dart.dart';
import 'package:json_schema/json_schema.dart';

import '../models/interface/model.dart';
import '../models/interface/model_settings.dart';
import '../models/message.dart';
import '../providers/implementation/provider_table.dart';
import '../providers/interface/provider.dart';
import '../providers/interface/provider_settings.dart';
import 'agent_response.dart';
import 'tool.dart';

export 'agent_response.dart';
export 'tool.dart';

/// An agent that can run prompts through an AI model and return responses.
///
/// This class provides a unified interface for interacting with different
/// AI model providers and handling both string and typed responses.
class Agent {
  /// Factory constructor to create an [Agent] for a specific model.
  ///
  /// Creates an [Agent] by specifying the model in the format "providerName",
  /// "providerName:modelName", or "providerName/modelName". Automatically
  /// resolves the appropriate provider for the given model.
  ///
  /// - [model]: The model identifier in "providerName",
  ///   "providerName:modelName", or "providerName/modelName" format.
  /// - [systemPrompt]: (Optional) A system prompt to guide the agent's
  ///   behavior.
  /// - [outputType]: (Optional) A [JsonSchema] defining the expected output
  ///   type.
  /// - [outputFromJson]: (Optional) A function to convert JSON output to a
  ///   typed object.
  /// - [tools]: (Optional) A collection of [Tool]s the agent can use.
  factory Agent(
    String model, {
    String? systemPrompt,
    JsonSchema? outputType,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    Iterable<Tool>? tools,
  }) => Agent.provider(
    providerFor(model),
    systemPrompt: systemPrompt,
    outputType: outputType,
    outputFromJson: outputFromJson,
    tools: tools,
  );

  /// Creates a new [Agent] with the given [provider].
  ///
  /// - [provider]: The [Provider] to use for the agent.
  /// - [systemPrompt]: (Optional) The system prompt to use for the agent.
  /// - [outputType]: (Optional) The [JsonSchema] for the expected output type.
  /// - [outputFromJson]: (Optional) A function to convert JSON output to a
  ///   typed object.
  /// - [tools]: (Optional) A collection of [Tool]s the agent can use.
  Agent.provider(
    Provider provider, {
    String? systemPrompt,
    JsonSchema? outputType,
    this.outputFromJson,
    Iterable<Tool>? tools,
  }) : _model = provider.createModel(
         ModelSettings(
           systemPrompt: systemPrompt,
           outputType: outputType,
           tools: tools,
         ),
       );

  final Model _model;

  /// Function to convert JSON output to a typed object.
  ///
  /// When provided, this function is used to convert the JSON response from the
  /// model into a strongly-typed object when using [runFor].
  final dynamic Function(Map<String, dynamic> json)? outputFromJson;

  /// Executes the given [prompt] using the model and returns the complete
  /// response.
  ///
  /// This method processes the prompt through the model, collects the output
  /// from the resulting stream, and returns it as a single [AgentResponse].
  ///
  /// - [prompt]: The input string to be processed by the model.
  ///
  /// Returns an [AgentResponse] containing the concatenated output from the
  /// model.
  Future<AgentResponse> run(
    String prompt, {
    List<Message> messages = const [],
  }) async {
    final stream = _model.runStream(prompt: prompt, messages: messages);
    final output = StringBuffer();
    var outputMessages = <Message>[];
    await for (final chunk in stream) {
      output.write(chunk.output);
      outputMessages = chunk.messages;
    }
    return AgentResponse(output: output.toString(), messages: outputMessages);
  }

  /// Runs the given [prompt] through the model and returns the response as a
  /// stream.
  ///
  /// Returns a [Stream] of [AgentResponse] containing the raw string output.
  Stream<AgentResponse> runStream(
    String prompt, {
    List<Message> messages = const [],
  }) => _model.runStream(prompt: prompt, messages: messages);

  /// Runs the given [prompt] through the model and returns a typed response.
  ///
  /// Returns an [AgentResponseFor<T>] containing the output converted to type
  /// [T]. Uses [outputFromJson] to convert the JSON response if provided,
  /// otherwise returns the decoded JSON.
  Future<AgentResponseFor<T>> runFor<T>(
    String prompt, {
    List<Message> messages = const [],
  }) async {
    final response = await run(prompt, messages: messages);
    final outputJson = jsonDecode(response.output);
    final outputTyped = outputFromJson?.call(outputJson) ?? outputJson;
    return AgentResponseFor(output: outputTyped, messages: response.messages);
  }

  /// Executes a given [DotPrompt] and returns the complete response.
  ///
  /// This method processes the [DotPrompt] through the model specified in the
  /// prompt's front matter or defaults to 'google' if not specified. It
  /// collects the output and returns it as a single [AgentResponse].
  ///
  /// - [prompt]: The [DotPrompt] to be executed.
  /// - [systemPrompt]: (Optional) A system prompt to guide the agent's
  ///   behavior.
  /// - [outputType]: (Optional) A [JsonSchema] defining the expected output
  ///   type.
  /// - [outputFromJson]: (Optional) A function to convert JSON output to a
  ///   typed object.
  /// - [tools]: (Optional) A collection of [Tool]s the agent can use.
  /// - [input]: (Optional) A map of input values to render the prompt with.
  ///   Defaults to an empty map.
  ///
  /// Returns a [Future] of [AgentResponse] containing the concatenated output
  /// from the agent.
  static Future<AgentResponse> runPrompt(
    DotPrompt prompt, {
    String? systemPrompt,
    JsonSchema? outputType,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    Iterable<Tool>? tools,
    Map<String, dynamic> input = const {},
    List<Message> messages = const [],
  }) => Agent(
    prompt.frontMatter.model ?? 'google',
    systemPrompt: systemPrompt,
    outputType: outputType,
    outputFromJson: outputFromJson,
    tools: tools,
  ).run(prompt.render(input), messages: messages);

  /// Executes a [DotPrompt] and returns a typed response.
  ///
  /// This method processes the [DotPrompt] through the model specified in the
  /// prompt's front matter, or defaults to 'google' if not specified. It
  /// renders the prompt with the provided [input] map, sends it to the model,
  /// and returns the output as an [AgentResponseFor<T>] containing the output
  /// converted to type [T].
  ///
  /// - [prompt]: The [DotPrompt] to execute.
  /// - [systemPrompt]: (Optional) A system prompt to guide the agent's
  ///   behavior.
  /// - [outputType]: (Optional) A [JsonSchema] defining the expected output
  ///   type.
  /// - [outputFromJson]: (Optional) A function to convert JSON output to a
  ///   typed object.
  /// - [tools]: (Optional) A collection of [Tool]s the agent can use.
  /// - [input]: (Optional) A map of input values to render the prompt with.
  ///   Defaults to an empty map.
  ///
  /// Returns a [Future] of [AgentResponseFor<T>] containing the output
  /// converted to type [T].
  static Future<AgentResponseFor<T>> runPromptFor<T>(
    DotPrompt prompt, {
    String? systemPrompt,
    JsonSchema? outputType,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    Iterable<Tool>? tools,
    Map<String, dynamic> input = const {},
    List<Message> messages = const [],
  }) => Agent(
    prompt.frontMatter.model ?? 'google',
    systemPrompt: systemPrompt,
    outputType: outputType,
    outputFromJson: outputFromJson,
    tools: tools,
  ).runFor<T>(prompt.render(input), messages: messages);

  /// Executes a given [DotPrompt] using the specified parameters and returns
  /// the response as a [Stream] of [AgentResponse].
  ///
  /// - [prompt]: The [DotPrompt] to be executed.
  /// - [systemPrompt]: (Optional) A system prompt to guide the agent's
  ///   behavior.
  /// - [outputType]: (Optional) A [JsonSchema] defining the expected output
  ///   type.
  /// - [outputFromJson]: (Optional) A function to convert JSON output to a
  ///   typed object.
  /// - [tools]: (Optional) A collection of [Tool]s the agent can use.
  /// - [input]: (Optional) A map of input values to render the prompt with.
  ///   Defaults to an empty map.
  ///
  /// Returns a [Stream] of [AgentResponse] containing the raw string output
  /// from the agent.
  static Stream<AgentResponse> runPromptStream(
    DotPrompt prompt, {
    String? systemPrompt,
    JsonSchema? outputType,
    dynamic Function(Map<String, dynamic> json)? outputFromJson,
    Iterable<Tool>? tools,
    Map<String, dynamic> input = const {},
    List<Message> messages = const [],
  }) => Agent(
    prompt.frontMatter.model ?? 'google',
    systemPrompt: systemPrompt,
    outputType: outputType,
    outputFromJson: outputFromJson,
    tools: tools,
  ).runStream(prompt.render(input), messages: messages);

  /// Resolves the [Provider] for the given [model] string.
  ///
  /// [model] should be in the format "providerName", "providerName:modelName",
  /// or "providerName/modelName".
  ///
  /// Throws [ArgumentError] if [model] is empty.
  static Provider providerFor(String model) {
    if (model.isEmpty) throw ArgumentError('Model must be provided');

    final modelParts = model.split(RegExp('[:/]'));
    final providerName = modelParts[0];
    final modelName = modelParts.length != 1 ? modelParts[1] : null;

    return ProviderTable.providerFor(
      ProviderSettings(
        providerName: providerName,
        modelName: modelName,
        apiKey: null,
      ),
    );
  }
}
