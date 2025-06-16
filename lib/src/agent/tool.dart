import 'package:json_schema/json_schema.dart';

/// A function that handles tool calls by processing input parameters and
/// returning a result.
///
/// [input] - A map containing the parameters passed to the tool. Returns a
/// Future that resolves to a map of result values, or null if no result.
typedef ToolCallHandler =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> input);

/// Represents a tool that can be called by an agent to perform a specific
/// function.
///
/// Tools are the primary way for agents to interact with external systems,
/// execute specific operations, or access particular capabilities.
class Tool {
  /// Creates a new tool with the specified properties.
  ///
  /// [name] - The unique identifier for this tool. [onCall] - The function that
  /// will be executed when this tool is called. [description] - Optional
  /// human-readable description of what the tool does. [inputSchema] - Optional
  /// schema definition for the expected input parameters.
  Tool({
    required this.name,
    required this.onCall,
    String? description,
    this.inputSchema,
  }) : description = description ?? inputSchema?.description;

  /// The unique identifier for this tool.
  final String name;

  /// Human-readable description of what the tool does.
  final String? description;

  /// Schema definition for the expected input parameters.
  final JsonSchema? inputSchema;

  /// The function that will be executed when this tool is called.
  final ToolCallHandler onCall;
}
