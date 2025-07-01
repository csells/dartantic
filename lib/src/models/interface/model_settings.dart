import 'package:json_schema/json_schema.dart';

import '../../agent/tool.dart';
import '../../providers/interface/provider_caps.dart';

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

  /// The temperature to use for the model.
  final double? temperature;

  /// The capabilities of the model.
  final Set<ProviderCaps> caps;

  /// Extended properties for provider-specific configuration options.
  final Map<String, dynamic>? extendedProperties;
}
