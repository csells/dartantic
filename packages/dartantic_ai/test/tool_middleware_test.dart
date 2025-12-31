// ignore_for_file: avoid_dynamic_calls

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_ai/src/agent/tool_executor.dart';
import 'package:test/test.dart';

import 'test_tools.dart';

void main() {
  group('Tool Middleware', () {
    group('ToolMiddleware interface', () {
      test('FunctionToolMiddleware wraps a function correctly', () async {
        var called = false;
        final middleware = FunctionToolMiddleware((toolCall, tool, next) async {
          called = true;
          expect(toolCall.name, equals('string_tool'));
          expect(tool, isNotNull);
          return next();
        });

        final executor = ToolExecutor(middleware: [middleware]);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        expect(called, isTrue);
        expect(result.isSuccess, isTrue);
        expect(result.resultPart.result, contains('test'));
      });

      test('class-based middleware works', () async {
        var beforeCalled = false;
        var afterCalled = false;

        final testMiddleware = _TestMiddleware(
          onIntercept: (toolCall, tool, next) async {
            beforeCalled = true;
            expect(toolCall.name, equals('string_tool'));
            expect(tool, isNotNull);
            final result = await next();
            afterCalled = true;
            return result;
          },
        );

        final executor = ToolExecutor(middleware: [testMiddleware]);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        expect(beforeCalled, isTrue);
        expect(afterCalled, isTrue);
        expect(result.isSuccess, isTrue);
      });
    });

    group('Middleware chain execution', () {
      test('middleware executes in order', () async {
        final executionOrder = <String>[];

        final middleware1 = FunctionToolMiddleware((
          toolCall,
          tool,
          next,
        ) async {
          executionOrder.add('middleware1-before');
          final result = await next();
          executionOrder.add('middleware1-after');
          return result;
        });

        final middleware2 = FunctionToolMiddleware((
          toolCall,
          tool,
          next,
        ) async {
          executionOrder.add('middleware2-before');
          final result = await next();
          executionOrder.add('middleware2-after');
          return result;
        });

        final executor = ToolExecutor(middleware: [middleware1, middleware2]);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        await executor.executeSingle(toolCall, toolMap);

        expect(
          executionOrder,
          equals([
            'middleware1-before',
            'middleware2-before',
            'middleware2-after',
            'middleware1-after',
          ]),
        );
      });

      test('multiple middleware can modify results', () async {
        final middleware1 = FunctionToolMiddleware((
          toolCall,
          tool,
          next,
        ) async {
          final result = await next();
          // Modify result by wrapping it
          final modifiedResult = ToolExecutionResult(
            toolPart: result.toolPart,
            resultPart: ToolPart.result(
              id: result.resultPart.id,
              name: result.resultPart.name,
              result: '[Middleware1] ${result.resultPart.result}',
            ),
          );
          return modifiedResult;
        });

        final middleware2 = FunctionToolMiddleware((
          toolCall,
          tool,
          next,
        ) async {
          final result = await next();
          // Modify result by wrapping it
          final modifiedResult = ToolExecutionResult(
            toolPart: result.toolPart,
            resultPart: ToolPart.result(
              id: result.resultPart.id,
              name: result.resultPart.name,
              result: '[Middleware2] ${result.resultPart.result}',
            ),
          );
          return modifiedResult;
        });

        final executor = ToolExecutor(middleware: [middleware1, middleware2]);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        // Middleware2 wraps first, then middleware1 wraps that
        expect(
          result.resultPart.result,
          equals('[Middleware1] [Middleware2] String result: test'),
        );
      });
    });

    group('Middleware skipping execution', () {
      test(
        'middleware can skip tool execution and return custom result',
        () async {
          var toolExecuted = false;

          final mockTool = Tool<Map<String, dynamic>>(
            name: 'mock_tool',
            description: 'Mock tool',
            onCall: (_) {
              toolExecuted = true;
              return 'should not execute';
            },
          );

          final middleware = FunctionToolMiddleware((
            toolCall,
            tool,
            next,
          ) async {
            // Skip execution, return custom result
            return ToolExecutionResult(
              toolPart: toolCall,
              resultPart: ToolPart.result(
                id: toolCall.id,
                name: toolCall.name,
                result: '{"skipped": true, "reason": "middleware override"}',
              ),
            );
          });

          final executor = ToolExecutor(middleware: [middleware]);
          final toolMap = {'mock_tool': mockTool};
          const toolCall = ToolPart.call(
            id: 'test-id',
            name: 'mock_tool',
            arguments: {},
          );

          final result = await executor.executeSingle(toolCall, toolMap);

          expect(toolExecuted, isFalse);
          expect(result.isSuccess, isTrue);
          expect(result.resultPart.result, contains('skipped'));
        },
      );
    });

    group('Middleware error handling', () {
      test('middleware can catch and modify errors', () async {
        final failingTool = Tool<Map<String, dynamic>>(
          name: 'failing_tool',
          description: 'Tool that throws',
          onCall: (_) {
            throw Exception('Tool execution failed');
          },
        );

        final middleware = FunctionToolMiddleware((toolCall, tool, next) async {
          try {
            return await next();
          } on Exception catch (e) {
            // Catch and return custom error result
            return ToolExecutionResult(
              toolPart: toolCall,
              resultPart: ToolPart.result(
                id: toolCall.id,
                name: toolCall.name,
                result: '{"error": "Caught by middleware: $e"}',
              ),
              error: Exception('Middleware handled error'),
            );
          }
        });

        final executor = ToolExecutor(middleware: [middleware]);
        final toolMap = {'failing_tool': failingTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'failing_tool',
          arguments: {},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        // The tool executor should still catch the error, but middleware
        // could theoretically intercept it
        expect(result.error, isNotNull);
      });

      test('middleware handles missing tools', () async {
        var middlewareCalled = false;

        final middleware = FunctionToolMiddleware((toolCall, tool, next) async {
          middlewareCalled = true;
          expect(tool, isNull);
          // Middleware can handle missing tool case
          return ToolExecutionResult(
            toolPart: toolCall,
            resultPart: ToolPart.result(
              id: toolCall.id,
              name: toolCall.name,
              result: '{"error": "Tool not found, handled by middleware"}',
            ),
            error: Exception('Tool not found'),
          );
        });

        final executor = ToolExecutor(middleware: [middleware]);
        final toolMap = <String, Tool>{};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'nonexistent_tool',
          arguments: {},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        expect(middlewareCalled, isTrue);
        expect(result.error, isNotNull);
      });
    });

    group('Backward compatibility', () {
      test('ToolExecutor works without middleware', () async {
        const executor = ToolExecutor();
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        expect(result.isSuccess, isTrue);
        expect(result.resultPart.result, contains('test'));
      });

      test('ToolExecutor works with empty middleware list', () async {
        const executor = ToolExecutor(middleware: []);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        final result = await executor.executeSingle(toolCall, toolMap);

        expect(result.isSuccess, isTrue);
        expect(result.resultPart.result, contains('test'));
      });
    });

    group('Integration with Agent', () {
      test('Agent accepts middleware parameter', () {
        final middleware = FunctionToolMiddleware(
          (toolCall, tool, next) => next(),
        );

        final agent = Agent(
          'openai:gpt-4o-mini',
          tools: [stringTool],
          middleware: [middleware],
        );

        expect(agent, isNotNull);
      });

      test('Agent.forProvider accepts middleware parameter', () {
        final middleware = FunctionToolMiddleware(
          (toolCall, tool, next) => next(),
        );

        final provider = Agent.getProvider('openai');
        final agent = Agent.forProvider(
          provider,
          tools: [stringTool],
          middleware: [middleware],
        );

        expect(agent, isNotNull);
      });
    });

    group('Logging middleware example', () {
      test('logging middleware logs before and after execution', () async {
        final logs = <String>[];

        final loggingMiddleware = _LoggingMiddleware(
          onIntercept: (toolCall, tool, next) async {
            logs.add('Before: ${toolCall.name}(${toolCall.arguments})');
            final result = await next();
            logs.add('After: ${toolCall.name} -> ${result.isSuccess}');
            return result;
          },
        );

        final executor = ToolExecutor(middleware: [loggingMiddleware]);
        final toolMap = {'string_tool': stringTool};
        const toolCall = ToolPart.call(
          id: 'test-id',
          name: 'string_tool',
          arguments: {'input': 'test'},
        );

        await executor.executeSingle(toolCall, toolMap);

        expect(logs, hasLength(2));
        expect(logs[0], contains('Before:'));
        expect(logs[1], contains('After:'));
        expect(logs[1], contains('true')); // isSuccess
      });
    });

    group('Batch execution with middleware', () {
      test('middleware applies to each tool in batch', () async {
        final callCount = <String, int>{};

        final middleware = FunctionToolMiddleware((toolCall, tool, next) async {
          callCount[toolCall.name] = (callCount[toolCall.name] ?? 0) + 1;
          return next();
        });

        final executor = ToolExecutor(middleware: [middleware]);
        final toolMap = {'string_tool': stringTool, 'int_tool': intTool};
        final toolCalls = [
          const ToolPart.call(
            id: 'id1',
            name: 'string_tool',
            arguments: {'input': 'test1'},
          ),
          const ToolPart.call(
            id: 'id2',
            name: 'int_tool',
            arguments: {'value': 42},
          ),
          const ToolPart.call(
            id: 'id3',
            name: 'string_tool',
            arguments: {'input': 'test2'},
          ),
        ];

        await executor.executeBatch(toolCalls, toolMap);

        expect(callCount['string_tool'], equals(2));
        expect(callCount['int_tool'], equals(1));
      });
    });
  });
}

// Helper classes for testing
class _TestMiddleware implements ToolMiddleware {
  _TestMiddleware({required this.onIntercept});

  final Future<ToolExecutionResult> Function(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  )
  onIntercept;

  @override
  Future<ToolExecutionResult> intercept(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  ) => onIntercept(toolCall, tool, next);
}

class _LoggingMiddleware implements ToolMiddleware {
  _LoggingMiddleware({required this.onIntercept});

  final Future<ToolExecutionResult> Function(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  )
  onIntercept;

  @override
  Future<ToolExecutionResult> intercept(
    ToolPart toolCall,
    Tool? tool,
    Future<ToolExecutionResult> Function() next,
  ) => onIntercept(toolCall, tool, next);
}
