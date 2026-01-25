import 'dart:async';

import 'package:dartantic_interface/dartantic_interface.dart';

import 'tool_executor.dart';

/// Middleware that can intercept tool calls before and after execution.
///
/// Middleware allows you to:
/// - Log tool calls and results
/// - Modify tool arguments before execution
/// - Skip tool execution and return custom results
/// - Modify or replace tool results after execution
/// - Implement custom error handling
///
/// Example:
/// ```dart
/// class LoggingMiddleware implements ToolMiddleware {
///   @override
///   Future<ToolExecutionResult> intercept(
///     ToolPart toolCall,
///     Tool? tool,
///     Future<ToolExecutionResult> Function() next,
///   ) async {
///     print('Before: ${toolCall.name}');
///     final result = await next();
///     print('After: ${toolCall.name} -> ${result.isSuccess}');
///     return result;
///   }
/// }
/// ```
abstract class ToolMiddleware {
  /// Creates a ToolMiddleware
  const ToolMiddleware();

  /// Intercepts a tool call before and/or after execution.
  ///
  /// [toolCall] - The tool call to intercept
  /// [tool] - The matched tool instance, or null if the tool was not found
  /// [next] - Callback to continue to the next middleware or actual execution
  ///
  /// Returns the ToolExecutionResult (can be modified or replaced)
  Future<ToolExecutionResult> intercept(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  );
}

/// Adapter that wraps a function to implement ToolMiddleware.
///
/// This allows you to use a simple function as middleware instead of
/// creating a class.
///
/// Example:
/// ```dart
/// final middleware = FunctionToolMiddleware(
///   (toolCall, tool, next) async {
///     print('Executing ${toolCall.name}');
///     return next();
///   },
/// );
/// ```
class FunctionToolMiddleware implements ToolMiddleware {
  /// Creates a FunctionToolMiddleware that wraps the given handler function.
  const FunctionToolMiddleware(this.handler);

  /// The function that handles the middleware logic
  final Future<ToolExecutionResult> Function(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  )
  handler;

  @override
  Future<ToolExecutionResult> intercept(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  ) => handler(toolCall, tool, next);
}
