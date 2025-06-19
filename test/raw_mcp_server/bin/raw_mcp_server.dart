import 'dart:convert';
import 'dart:io';

void main() async {
  // Raw MCP server that properly includes required fields
  final server = RawMcpServer();
  await server.run();
}

class RawMcpServer {
  Future<void> run() async {
    // Listen to stdin for JSON-RPC requests
    await for (final line in stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await handleRequest(request);

        // Send response to stdout
        stdout.writeln(jsonEncode(response));
      } on Exception catch (e) {
        // Send error response
        final errorResponse = {
          'jsonrpc': '2.0',
          'id': null,
          'error': {'code': -32700, 'message': 'Parse error: $e'},
        };
        stdout.writeln(jsonEncode(errorResponse));
      }
    }
  }

  Future<Map<String, dynamic>> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': true},
            },
            'serverInfo': {'name': 'raw-mcp-server', 'version': '1.0.0'},
          },
        };

      case 'initialized':
        // Notification - no response needed
        return {};

      case 'tools/list':
        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'tools': [
              {
                'name': 'calculate',
                'description':
                    'Perform basic arithmetic operations with required fields',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'operation': {
                      'type': 'string',
                      'enum': ['add', 'subtract', 'multiply', 'divide'],
                      'description': 'The arithmetic operation to perform',
                    },
                    'a': {'type': 'number', 'description': 'First number'},
                    'b': {'type': 'number', 'description': 'Second number'},
                  },
                  'required': ['operation', 'a', 'b'], // This is the key!
                  'additionalProperties': false,
                },
              },
              {
                'name': 'greet',
                'description': 'Greet a person with optional message',
                'inputSchema': {
                  'type': 'object',
                  'properties': {
                    'name': {
                      'type': 'string',
                      'description': 'Name of the person to greet',
                    },
                    'message': {
                      'type': 'string',
                      'description': 'Optional custom message',
                    },
                  },
                  'required': ['name'], // Only name is required
                  'additionalProperties': false,
                },
              },
            ],
          },
        };

      case 'tools/call':
        final params = request['params'] as Map<String, dynamic>;
        final toolName = params['name'] as String;
        final arguments = params['arguments'] as Map<String, dynamic>? ?? {};

        return {
          'jsonrpc': '2.0',
          'id': id,
          'result': await callTool(toolName, arguments),
        };

      default:
        return {
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32601, 'message': 'Method not found: $method'},
        };
    }
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> args,
  ) async {
    switch (name) {
      case 'calculate':
        final operation = args['operation'] as String;
        final a = args['a'] as num;
        final b = args['b'] as num;

        final result = switch (operation) {
          'add' => a + b,
          'subtract' => a - b,
          'multiply' => a * b,
          'divide' => a / b,
          _ => throw Exception('Invalid operation: $operation'),
        };

        return {
          'content': [
            {'type': 'text', 'text': 'Result: $result'},
          ],
        };

      case 'greet':
        final name = args['name'] as String;
        final message = args['message'] as String? ?? 'Hello';

        return {
          'content': [
            {'type': 'text', 'text': '$message, $name!'},
          ],
        };

      default:
        throw Exception('Unknown tool: $name');
    }
  }
}
