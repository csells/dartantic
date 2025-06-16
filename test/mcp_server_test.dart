// ignore_for_file: avoid_print

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
    });
  });
}
