// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('McpClient Tests', () {
    group('remote server configuration', () {
      test('creates remote server with required parameters', () {
        final server = McpClient.remote(
          'test-server',
          url: Uri.parse('https://example.com/mcp'),
        );

        expect(server.name, equals('test-server'));
        expect(server.kind, equals(McpServerKind.remote));
        expect(server.url, equals(Uri.parse('https://example.com/mcp')));
      });

      test('creates remote server with headers', () {
        final server = McpClient.remote(
          'test-server',
          url: Uri.parse('https://example.com/mcp'),
          headers: {'Authorization': 'Bearer token'},
        );

        expect(server.headers, containsPair('Authorization', 'Bearer token'));
      });
    });

    group('local server configuration', () {
      test('creates local server with required parameters', () {
        final server = McpClient.local(
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
        final server = McpClient.local(
          'local-server',
          command: 'node',
          environment: {'NODE_ENV': 'test'},
        );

        expect(server.environment, containsPair('NODE_ENV', 'test'));
      });
    });

    group('Hugging Face MCP server integration', () {
      late McpClient huggingFaceServer;

      setUp(() {
        huggingFaceServer = McpClient.remote(
          'huggingface',
          url: Uri.parse('https://huggingface.co/mcp'),
        );
      });

      tearDown(() async {
        await huggingFaceServer.disconnect();
      });

      test('can connect to Hugging Face MCP server', () async {
        final tools = await huggingFaceServer.listTools();
        expect(tools, isA<List<Tool>>());
      });

      test('properly parses all tool schemas with required fields', () async {
        final tools = await huggingFaceServer.listTools();

        // Verify we got the expected number of tools
        expect(tools.length, equals(9));

        // Test specific tools and their schemas
        final toolMap = {for (final tool in tools) tool.name: tool};

        // Test hf_whoami tool (no required fields)
        expect(toolMap.containsKey('hf_whoami'), isTrue);
        final whoamiTool = toolMap['hf_whoami']!;
        expect(whoamiTool.description, contains('anonymously'));
        expect(whoamiTool.inputSchema!.requiredProperties ?? [], isEmpty);

        // Test space_search tool (has required field: query)
        expect(toolMap.containsKey('space_search'), isTrue);
        final spaceSearchTool = toolMap['space_search']!;
        expect(
          spaceSearchTool.description,
          contains('Find Hugging Face Spaces'),
        );

        expect(
          spaceSearchTool.inputSchema!.requiredProperties,
          contains('query'),
        );
        expect(
          spaceSearchTool.inputSchema!.requiredProperties?.length,
          equals(1),
        );

        // Test model_details tool (has required field: model_id)
        expect(toolMap.containsKey('model_details'), isTrue);
        final modelDetailsTool = toolMap['model_details']!;
        expect(
          modelDetailsTool.description,
          contains('Get detailed information about a specific model'),
        );
        expect(
          modelDetailsTool.inputSchema!.requiredProperties,
          contains('model_id'),
        );
        expect(
          modelDetailsTool.inputSchema!.requiredProperties?.length,
          equals(1),
        );

        // Test paper_search tool (has required field: query)
        expect(toolMap.containsKey('paper_search'), isTrue);
        final paperSearchTool = toolMap['paper_search']!;
        expect(
          paperSearchTool.description,
          contains('Find Machine Learning research papers'),
        );
        expect(
          paperSearchTool.inputSchema!.requiredProperties,
          contains('query'),
        );

        // Test dataset_details tool (has required field: dataset_id)
        expect(toolMap.containsKey('dataset_details'), isTrue);
        final datasetDetailsTool = toolMap['dataset_details']!;
        expect(
          datasetDetailsTool.description,
          contains('Get detailed information about a specific dataset'),
        );
        expect(
          datasetDetailsTool.inputSchema!.requiredProperties,
          contains('dataset_id'),
        );

        // Test image generation tools exist
        expect(toolMap.containsKey('gr1_evalstate_flux1_schnell'), isTrue);
        expect(toolMap.containsKey('gr2_abidlabs_easyghibli'), isTrue);

        // Verify all tools have proper schemas
        for (final tool in tools) {
          expect(tool.inputSchema, isNotNull);
          expect(tool.name, isNotEmpty);
          expect(tool.description, isNotEmpty);
          expect(tool.description, startsWith('[huggingface]'));
        }
      });

      test('handles connection errors gracefully', () async {
        final badServer = McpClient.remote(
          'bad-server',
          url: Uri.parse('https://nonexistent.invalid/mcp'),
        );

        expect(
          () async => badServer.listTools(),
          throwsA(anyOf([isA<Exception>(), isA<StateError>()])),
        );

        await badServer.disconnect();
      });

      test('can call MCP tools', () async {
        final tools = await huggingFaceServer.listTools();
        expect(tools.isNotEmpty, isTrue);

        final firstTool = tools.first;
        final result = await firstTool.onCall({});
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('local MCP server tests', () {
      test('creates local server with correct configuration', () {
        final localServer = McpClient.local(
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
        final localServer = McpClient.local(
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
        final localServer = McpClient.local(
          'state-test-server',
          command: 'echo',
          args: ['test'],
        );

        expect(localServer.isConnected, isFalse);

        // Note: We don't actually connect here since echo is not an MCP server
        // This test just validates the state management
      });

      test('can connect to local MCP server directly', () async {
        final localServer = McpClient.local(
          'test-mcp-server',
          command: 'dart',
          args: ['test/test_mcp_server/bin/test_mcp_server.dart'],
        );

        // Test that we can get tools from the local server
        final tools = await localServer.listTools();
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

        expect(result['result'], contains('Result: 8'));
        await localServer.disconnect();
      });

      test('preserves required fields for raw MCP server schemas', () async {
        final rawServer = McpClient.local(
          'raw-mcp-server',
          command: 'dart',
          args: ['test/raw_mcp_server/bin/raw_mcp_server.dart'],
        );

        final tools = await rawServer.listTools();
        expect(tools, isNotEmpty);
        expect(tools.length, equals(2));

        final toolMap = {for (final tool in tools) tool.name: tool};

        // Test calculate tool (all fields required)
        expect(toolMap.containsKey('calculate'), isTrue);
        final calculateTool = toolMap['calculate']!;
        expect(
          calculateTool.description,
          contains('arithmetic operations with required fields'),
        );
        expect(
          calculateTool.inputSchema!.requiredProperties,
          containsAll(['operation', 'a', 'b']),
        );
        expect(
          calculateTool.inputSchema!.requiredProperties?.length,
          equals(3),
        );

        // Test greet tool (only name required)
        expect(toolMap.containsKey('greet'), isTrue);
        final greetTool = toolMap['greet']!;
        expect(greetTool.description, contains('optional message'));
        expect(greetTool.inputSchema!.requiredProperties, contains('name'));
        expect(greetTool.inputSchema!.requiredProperties?.length, equals(1));

        await rawServer.disconnect();
      });

      test('mcp_dart server limitation - drops required fields', () async {
        final mcpDartServer = McpClient.local(
          'mcp-dart-server',
          command: 'dart',
          args: ['test/test_mcp_server/bin/test_mcp_server.dart'],
        );

        final tools = await mcpDartServer.listTools();
        final calculateTool = tools.firstWhere(
          (tool) => tool.name == 'calculate',
        );

        // This documents the mcp_dart limitation
        expect(
          calculateTool.inputSchema!.requiredProperties,
          isNull,
          reason: 'mcp_dart intentionally drops required fields',
        );

        await mcpDartServer.disconnect();
      });

      test(
        'can call tools on raw MCP server with required field validation',
        () async {
          final rawServer = McpClient.local(
            'raw-mcp-server',
            command: 'dart',
            args: ['test/raw_mcp_server/bin/raw_mcp_server.dart'],
          );

          final tools = await rawServer.listTools();
          final calculateTool = tools.firstWhere(
            (tool) => tool.name == 'calculate',
          );
          final greetTool = tools.firstWhere((tool) => tool.name == 'greet');

          // Test calculate tool with all required parameters
          final calcResult = await calculateTool.onCall({
            'operation': 'add',
            'a': 15,
            'b': 27,
          });
          expect(calcResult['result'], contains('Result: 42'));

          // Test greet tool with required parameter
          final greetResult = await greetTool.onCall({'name': 'Alice'});
          expect(greetResult['result'], contains('Hello, Alice!'));

          // Test greet tool with optional parameter
          final customGreetResult = await greetTool.onCall({
            'name': 'Bob',
            'message': 'Welcome',
          });
          expect(customGreetResult['result'], contains('Welcome, Bob!'));

          await rawServer.disconnect();
        },
      );

      test('can use local MCP server via Agent with prompt', () async {
        final localServer = McpClient.local(
          'test-mcp-server',
          command: 'dart',
          args: ['test/test_mcp_server/bin/test_mcp_server.dart'],
        );

        // Get tools from the local server
        final mcpTools = await localServer.listTools();
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

        final huggingFaceServer = McpClient.remote(
          'huggingface',
          url: Uri.parse('https://huggingface.co/mcp'),
        );

        final mcpTools = await huggingFaceServer.listTools();
        final allTools = [localTool, ...mcpTools];

        expect(allTools, contains(localTool));
        expect(allTools.length, greaterThanOrEqualTo(1));

        await huggingFaceServer.disconnect();
      });

      test('validates MCP server schema parsing edge cases', () async {
        final huggingFaceServer = McpClient.remote(
          'huggingface',
          url: Uri.parse('https://huggingface.co/mcp'),
        );

        final tools = await huggingFaceServer.listTools();

        // Test that all tools have valid input schemas
        for (final tool in tools) {
          expect(tool.inputSchema, isNotNull);
          expect(tool.inputSchema!.schemaMap, isA<Map<String, dynamic>>());

          // Check that schema has expected structure
          final schemaMap = tool.inputSchema!.schemaMap!;
          expect(schemaMap['type'], equals('object'));
          expect(schemaMap.containsKey('properties'), isTrue);

          // Verify required fields are properly handled
          if (schemaMap.containsKey('required')) {
            expect(schemaMap['required'], isA<List>());
            final required = schemaMap['required'] as List;
            expect(tool.inputSchema!.requiredProperties, isNotNull);
            expect(
              tool.inputSchema!.requiredProperties!.length,
              equals(required.length),
            );
          }
        }

        await huggingFaceServer.disconnect();
      });

      test('verifies SSE vs JSON format detection with real servers', () async {
        // DeepWiki should use SSE format
        final deepWikiServer = McpClient.remote(
          'deepwiki',
          url: Uri.parse('https://mcp.deepwiki.com/mcp'),
        );

        // Hugging Face should use direct JSON format
        final huggingFaceServer = McpClient.remote(
          'huggingface',
          url: Uri.parse('https://huggingface.co/mcp'),
        );

        // Both should work despite different response formats
        final deepWikiTools = await deepWikiServer.listTools();
        final hfTools = await huggingFaceServer.listTools();

        // Verify both return tools
        expect(deepWikiTools.isNotEmpty, isTrue);
        expect(hfTools.isNotEmpty, isTrue);

        // Verify proper prefixing was applied (shows parsing worked)
        expect(deepWikiTools.first.description, startsWith('[deepwiki]'));
        expect(hfTools.first.description, startsWith('[huggingface]'));

        await Future.wait([
          deepWikiServer.disconnect(),
          huggingFaceServer.disconnect(),
        ]);
      });

      test(
        'can connect to DeepWiki MCP server with session management',
        () async {
          final deepWikiServer = McpClient.remote(
            'deepwiki',
            url: Uri.parse('https://mcp.deepwiki.com/mcp'),
          );

          final tools = await deepWikiServer.listTools();

          // Verify we got the expected DeepWiki tools
          expect(tools.length, equals(3));

          // Verify this actually used the SSE code path by checking tool descriptions
          // DeepWiki tools should have [deepwiki] prefix added by our system
          for (final tool in tools) {
            expect(tool.description, startsWith('[deepwiki]'));
          }

          final toolMap = {for (final tool in tools) tool.name: tool};

          // Test read_wiki_structure tool
          expect(toolMap.containsKey('read_wiki_structure'), isTrue);
          final wikiStructureTool = toolMap['read_wiki_structure']!;
          expect(
            wikiStructureTool.description,
            contains('Get a list of documentation topics'),
          );
          expect(
            wikiStructureTool.inputSchema!.requiredProperties,
            contains('repoName'),
          );
          expect(
            wikiStructureTool.inputSchema!.requiredProperties?.length,
            equals(1),
          );

          // Test read_wiki_contents tool
          expect(toolMap.containsKey('read_wiki_contents'), isTrue);
          final wikiContentsTool = toolMap['read_wiki_contents']!;
          expect(
            wikiContentsTool.description,
            contains('View documentation about a GitHub repository'),
          );
          expect(
            wikiContentsTool.inputSchema!.requiredProperties,
            contains('repoName'),
          );

          // Test ask_question tool
          expect(toolMap.containsKey('ask_question'), isTrue);
          final askQuestionTool = toolMap['ask_question']!;
          expect(
            askQuestionTool.description,
            contains('Ask any question about a GitHub repository'),
          );
          expect(
            askQuestionTool.inputSchema!.requiredProperties,
            containsAll(['repoName', 'question']),
          );
          expect(
            askQuestionTool.inputSchema!.requiredProperties?.length,
            equals(2),
          );

          // Verify all tools have proper descriptions with server name
          for (final tool in tools) {
            expect(tool.description, startsWith('[deepwiki]'));
            expect(tool.inputSchema, isNotNull);
          }

          await deepWikiServer.disconnect();
        },
      );

      test('can configure local MCP server for Agent integration', () {
        final testServer = McpClient.local(
          'test-agent-server',
          command: Platform.resolvedExecutable,
          args: ['test/test_greeting_server.dart'],
        );

        expect(testServer.name, equals('test-agent-server'));
        expect(testServer.kind, equals(McpServerKind.local));
        expect(testServer.command, equals(Platform.resolvedExecutable));
        expect(testServer.args, equals(['test/test_greeting_server.dart']));
      });

      test('demonstrates local MCP server workflow configuration', () {
        // This test shows how to set up workflow-based local MCP servers
        final testServer = McpClient.local(
          'workflow-test-server',
          command: Platform.resolvedExecutable,
          args: ['test/test_format_server.dart'],
          environment: {'LOG_LEVEL': 'debug'},
        );

        expect(testServer.name, equals('workflow-test-server'));
        expect(testServer.environment, containsPair('LOG_LEVEL', 'debug'));
      });

      test('validates local tool configuration patterns', () {
        // Create a mock local tool to demonstrate mixing patterns
        final localTool = Tool(
          name: 'local_test',
          description: 'A local test tool',
          onCall: (args) async => {'result': 'local'},
        );

        // Configure MCP server (without connecting)
        final client = McpClient.local(
          'config-test-server',
          command: 'dart',
          args: ['mcp_server.dart'],
        );

        // Demonstrate how tools would be combined
        final allTools = [localTool];
        expect(allTools, contains(localTool));
        expect(allTools.length, equals(1));
        expect(client.isConnected, isFalse);
      });

      test(
        'can combine multiple MCP servers and local tools in Agent',
        () async {
          final localTime = Tool(
            name: 'local_time',
            description: 'Returns the current local time in ISO 8601 format.',
            onCall:
                (args) async => {'result': DateTime.now().toIso8601String()},
          );

          final location = Tool(
            name: 'location',
            description: 'Returns the current location.',
            onCall: (args) async => {'result': 'Portland, OR'},
          );

          final deepwiki = McpClient.remote(
            'deepwiki',
            url: Uri.parse('https://mcp.deepwiki.com/mcp'),
          );

          final huggingFace = McpClient.remote(
            'huggingface',
            url: Uri.parse('https://huggingface.co/mcp'),
          );

          final deepwikiTools = await deepwiki.listTools();
          final huggingFaceTools = await huggingFace.listTools();

          // Verify we got tools from both servers
          expect(deepwikiTools.length, equals(3));
          expect(huggingFaceTools.length, equals(9));

          final allTools = [
            localTime,
            location,
            ...deepwikiTools,
            ...huggingFaceTools,
          ];

          // Verify we have the expected total number of tools
          expect(allTools.length, equals(2 + 3 + 9)); // 14 total tools

          // Verify tool names are properly prefixed
          final deepwikiToolNames = deepwikiTools.map((t) => t.name).toSet();
          final huggingFaceToolNames =
              huggingFaceTools.map((t) => t.name).toSet();

          expect(deepwikiToolNames, contains('read_wiki_structure'));
          expect(huggingFaceToolNames, contains('space_search'));

          // Verify no duplicate tool names
          final allToolNames = allTools.map((t) => t.name).toList();
          final uniqueToolNames = allToolNames.toSet();
          expect(allToolNames.length, equals(uniqueToolNames.length));

          await Future.wait([deepwiki.disconnect(), huggingFace.disconnect()]);
        },
      );
    });
  });
}
