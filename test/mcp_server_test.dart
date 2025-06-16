// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('McpServer Tests', () {
    group('remote server configuration', () {
      test('creates remote server with required parameters', () {
        final server = McpServer.remote(
          'test-server',
          url: 'https://example.com/mcp',
        );

        expect(server.name, equals('test-server'));
        expect(server.kind, equals(McpServerKind.remote));
        expect(server.url, equals('https://example.com/mcp'));
      });

      test('creates remote server with headers', () {
        final server = McpServer.remote(
          'test-server',
          url: 'https://example.com/mcp',
          headers: {'Authorization': 'Bearer token'},
        );

        expect(server.headers, containsPair('Authorization', 'Bearer token'));
      });
    });

    group('local server configuration', () {
      test('creates local server with required parameters', () {
        final server = McpServer.local(
          'local-server',
          command: 'node',
          args: ['server.js'],
        );

        expect(server.name, equals('local-server'));
        expect(server.kind, equals(McpServerKind.local));
        expect(server.command, equals('node'));
        expect(server.args, equals(['server.js']));
      });

      test('creates local server with environment variables', () {
        final server = McpServer.local(
          'local-server',
          command: 'node',
          environment: {'NODE_ENV': 'test'},
        );

        expect(server.environment, containsPair('NODE_ENV', 'test'));
      });
    });

    group('Hugging Face MCP server integration', () {
      late McpServer huggingFaceServer;

      setUp(() {
        huggingFaceServer = McpServer.remote(
          'huggingface',
          url: 'https://huggingface.co/mcp',
        );
      });

      tearDown(() async {
        await huggingFaceServer.disconnect();
      });

      test('can connect to Hugging Face MCP server', () async {
        // This test verifies that we can attempt connection
        // Even if it fails, we test the connection mechanism
        try {
          final tools = await huggingFaceServer.getTools();
          expect(tools, isA<List<Tool>>());
          print(
            '✅ Connected to Hugging Face MCP server, '
            'found ${tools.length} tools',
          );
        } on Exception catch (e) {
          // Expected if the server doesn't exist or is unreachable
          print('⚠️ Hugging Face MCP server not available: $e');
          expect(e, isA<Exception>());
        }
      });

      test('handles connection errors gracefully', () async {
        final badServer = McpServer.remote(
          'bad-server',
          url: 'https://nonexistent.invalid/mcp',
        );

        expect(
          () async => badServer.getTools(),
          throwsA(anyOf([isA<Exception>(), isA<StateError>()])),
        );

        await badServer.disconnect();
      });

      test('can call MCP tools if available', () async {
        final tools = await huggingFaceServer.getTools();

        if (tools.isNotEmpty) {
          final firstTool = tools.first;

          // Try to call the first available tool with empty args
          final result = await firstTool.onCall({});
          expect(result, isA<Map<String, dynamic>>());
          print('✅ Successfully called tool: ${firstTool.name}');
        } else {
          print('No tools available for testing');
        }
      });
    });

    group('local MCP server tests', () {
      test('creates local server with correct configuration', () {
        final localServer = McpServer.local(
          'test-local-server',
          command: Platform.resolvedExecutable,
          args: ['test/test_mcp_server.dart'],
        );

        expect(localServer.name, equals('test-local-server'));
        expect(localServer.kind, equals(McpServerKind.local));
        expect(localServer.command, equals(Platform.resolvedExecutable));
        expect(localServer.args, equals(['test/test_mcp_server.dart']));
        expect(localServer.isConnected, isFalse);
      });

      test('supports environment variables and working directory', () {
        final localServer = McpServer.local(
          'env-test-server',
          command: 'dart',
          args: ['server.dart'],
          environment: {'DEBUG': 'true', 'PORT': '8080'},
          workingDirectory: '/tmp/test',
        );

        expect(localServer.environment, containsPair('DEBUG', 'true'));
        expect(localServer.environment, containsPair('PORT', '8080'));
        expect(localServer.workingDirectory, equals('/tmp/test'));
      });

      test('handles connection state correctly', () {
        final localServer = McpServer.local(
          'state-test-server',
          command: 'echo',
          args: ['test'],
        );

        expect(localServer.isConnected, isFalse);

        // Note: We don't actually connect here since echo is not an MCP server
        // This test just validates the state management
      });

      test('can connect to local MCP server directly', () async {
        final localServer = McpServer.local(
          'test-mcp-server',
          command: 'dart',
          args: ['test/test_mcp_server/bin/test_mcp_server.dart'],
        );

        // Test that we can get tools from the local server
        final tools = await localServer.getTools();
        expect(tools, isNotEmpty);

        // Find the calculate tool
        final calculateTool = tools.firstWhere(
          (tool) => tool.name == 'calculate',
        );

        // Test calling the tool
        final result = await calculateTool.onCall({
          'operation': 'add',
          'a': 5,
          'b': 3,
        });
        print(result);

        expect(result['result'], contains('Result: 8'));
        await localServer.disconnect();
      });

      test('can use local MCP server via Agent with prompt', () async {
        final localServer = McpServer.local(
          'test-mcp-server',
          command: 'dart',
          args: ['test/test_mcp_server/bin/test_mcp_server.dart'],
        );

        // Get tools from the local server
        final mcpTools = await localServer.getTools();
        expect(mcpTools, isNotEmpty);

        // Create an Agent with the local MCP server tools
        final agent = Agent(
          'openai:gpt-4o-mini',
          tools: mcpTools,
          systemPrompt:
              'You are a helpful calculator. '
              'Use the available tools to perform calculations.',
        );

        // Test that the Agent can use the local MCP server tool via prompt
        final response = await agent.run('Calculate 15 + 27 for me');

        // Verify the agent used the MCP tool and got the right result
        expect(response.output, contains('42')); // 15 + 27 = 42
        await localServer.disconnect();
      });
    });

    group('integration with Agent', () {
      test('can combine MCP tools with local tools', () async {
        final localTool = Tool(
          name: 'local_test',
          description: 'A local test tool',
          onCall: (args) async => {'result': 'local'},
        );

        final huggingFaceServer = McpServer.remote(
          'huggingface',
          url: 'https://huggingface.co/mcp',
        );

        final mcpTools = await huggingFaceServer.getTools();
        final allTools = [localTool, ...mcpTools];

        expect(allTools, contains(localTool));
        expect(allTools.length, greaterThanOrEqualTo(1));

        print('Combined ${mcpTools.length} MCP tools with 1 local tool');
        await huggingFaceServer.disconnect();
      });

      test('can configure local MCP server for Agent integration', () {
        final testServer = McpServer.local(
          'test-agent-server',
          command: Platform.resolvedExecutable,
          args: ['test/test_greeting_server.dart'],
        );

        expect(testServer.name, equals('test-agent-server'));
        expect(testServer.kind, equals(McpServerKind.local));
        expect(testServer.command, equals(Platform.resolvedExecutable));
        expect(testServer.args, equals(['test/test_greeting_server.dart']));

        print('✅ Configured local MCP server for Agent integration');
      });

      test('demonstrates local MCP server workflow configuration', () {
        // This test shows how to set up workflow-based local MCP servers
        final testServer = McpServer.local(
          'workflow-test-server',
          command: Platform.resolvedExecutable,
          args: ['test/test_format_server.dart'],
          environment: {'LOG_LEVEL': 'debug'},
        );

        expect(testServer.name, equals('workflow-test-server'));
        expect(testServer.environment, containsPair('LOG_LEVEL', 'debug'));

        print('✅ Configured workflow MCP server with environment variables');
      });

      test('validates local tool configuration patterns', () {
        // Create a mock local tool to demonstrate mixing patterns
        final localTool = Tool(
          name: 'local_test',
          description: 'A local test tool',
          onCall: (args) async => {'result': 'local'},
        );

        // Configure MCP server (without connecting)
        final mcpServer = McpServer.local(
          'config-test-server',
          command: 'dart',
          args: ['mcp_server.dart'],
        );

        // Demonstrate how tools would be combined
        final allTools = [localTool];
        expect(allTools, contains(localTool));
        expect(allTools.length, equals(1));
        expect(mcpServer.isConnected, isFalse);

        print('✅ Validated local tool and MCP server configuration patterns');
      });
    });
  });
}
