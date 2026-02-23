import 'dart:async';

import 'package:genai_primitives/genai_primitives.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:logging/logging.dart';

// Re-export schema types for consumers who need to define schemas
export 'package:json_schema_builder/json_schema_builder.dart' show S, Schema;

/// A tool that can be called by the LLM.
class Tool<TInput extends Object> extends ToolDefinition<TInput> {
  /// Creates a [Tool].
  Tool({
    required super.name,
    required super.description,
    required this.onCall,
    Schema? inputSchema,
    TInput Function(Map<String, dynamic>)? inputFromJson,
  }) : super(inputSchema: inputSchema ?? S.object()) {
    // if there are parameters, we need to be able to decode the json
    // from the LLM to the tool's input type.
    if (inputFromJson != null) {
      _inputFromJson = inputFromJson;
    } else if (_hasParameters(this.inputSchema)) {
      if (<String, dynamic>{} is TInput) {
        _inputFromJson = (json) => json as TInput;
      } else {
        throw ArgumentError(
          'Tool "$name" has parameters but no inputFromJson was provided. '
          'Either provide inputFromJson to parse arguments into $TInput, '
          'or use Tool<Map<String, dynamic>> to receive raw arguments.',
        );
      }
    } else {
      _inputFromJson = null;
    }

    final paramCount = _hasParameters(this.inputSchema)
        ? _getPropertiesCount(this.inputSchema)
        : 0;
    _logger.info('Registered tool: $name with $paramCount parameters');
  }

  /// Logger for tool operations.
  static final Logger _logger = Logger('dartantic.tools');

  /// The function that will be called when the tool is run.
  final FutureOr<dynamic> Function(TInput input) onCall;

  /// The function to parse the input JSON to the tool's input type.
  late final TInput Function(Map<String, dynamic> json)? _inputFromJson;

  /// Runs the tool.
  Future<dynamic> call(Map<String, dynamic> arguments) async {
    _logger.fine('Invoking tool: $name with arguments: $arguments');
    try {
      dynamic result;
      final inputFromJson = _inputFromJson; // workaround for web compiler error
      if (inputFromJson != null) {
        final input = inputFromJson(arguments);
        result = await onCall(input);
      } else {
        // No parameters expected - for tools like Tool<String> with no params,
        // we pass an empty string or the Map itself, depending on TInput type
        if (TInput == String) {
          result = await onCall('' as TInput);
        } else {
          result = await onCall(arguments as TInput);
        }
      }
      _logger.fine(
        'Tool $name executed successfully, result type: ${result.runtimeType}',
      );
      return result;
    } on Exception catch (e, stackTrace) {
      _logger.warning('Tool $name failed: $e', e, stackTrace);
      rethrow;
    }
  }

  /// Checks if the schema has parameters that require custom parsing.
  static bool _hasParameters(Schema? schema) {
    if (schema == null) return false;
    final properties = schema['properties'] as Map<String, Object?>?;
    return properties != null && properties.isNotEmpty;
  }

  /// Gets the count of properties in the schema.
  static int _getPropertiesCount(Schema? schema) {
    if (schema == null) return 0;
    final properties = schema['properties'] as Map<String, Object?>?;
    return properties?.length ?? 0;
  }
}
