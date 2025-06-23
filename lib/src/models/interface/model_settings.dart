import 'package:json_schema/json_schema.dart';

import '../../agent/tool.dart';
import '../../providers/interface/provider_caps.dart';

/// The mode in which the model will call tools.
///
/// This also controls whether parallel tool calls are enabled:
/// - [singleStep]: Tools are called sequentially (parallelToolCalls = false)
/// - [multiStep]: Tools can be called in parallel when independent
///   (parallelToolCalls = true)
enum ToolCallingMode {
  /// The model will use the single-step mode. This is the intuitive
  /// request=>response mode. It's meant as an optimization and not the default.
  ///
  /// Tools are called sequentially, one at a time, for predictable execution.
  singleStep,

  /// The model will use the multi-step mode. This is the mode that allows the
  /// model to call tools multiple times in a single request. Because it
  /// sometimes results in multiple tool calls, it is going to result in
  /// multiple round-trips to the LLM. However, it's more correct as it allows
  /// the LLM to complete their work in a single request.
  ///
  /// Tools can be called in parallel when they are independent, improving
  /// efficiency.
  multiStep,
}

/// Settings used to configure a model.
///
/// Contains configuration options that are common across different model
/// implementations.
class ModelSettings {
  /// Creates a new [ModelSettings] instance.
  ///
  /// The [systemPrompt] is the system prompt to use for the model.
  /// The [outputSchema] is an optional JSON schema for structured outputs.
  /// The [extendedProperties] allows provider-specific configuration options.
  ModelSettings({
    required this.systemPrompt,
    required this.outputSchema,
    required Iterable<Tool>? tools,
    required this.toolCallingMode,
    required this.caps,
    required this.temperature,
    this.extendedProperties,
  }) : tools = tools?.toList();

  /// The system prompt to use for the model.
  ///
  /// Provides context and instructions to guide the model's responses.
  final String? systemPrompt;

  /// The output type for structured responses.
  ///
  /// When provided, configures the model to return responses in JSON format
  /// that match this schema.
  final JsonSchema? outputSchema;

  /// The tools to use for the model.
  final List<Tool>? tools;

  /// The mode in which the agent will run.
  final ToolCallingMode? toolCallingMode;

  /// The temperature to use for the model.
  final double? temperature;

  /// The capabilities of the model.
  final Set<ProviderCaps> caps;

  /// Extended properties for provider-specific configuration options.
  final Map<String, dynamic>? extendedProperties;
}
