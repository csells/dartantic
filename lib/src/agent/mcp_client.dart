import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mcp_dart/mcp_dart.dart' as mcp;

import '../../pubspec.dart';
import '../json_schema_extension.dart';
import 'tool.dart';

/// Represents the type of MCP server connection.
enum McpServerKind {
  /// Local server accessed via stdio (command line process).
  local,

  /// Remote server accessed via HTTP.
  remote,
}

/// Configuration for connecting to an MCP (Model Context Protocol) server.
///
/// Supports both local servers (accessed via stdio) and remote servers
/// (accessed via HTTP) through factory constructors.
class McpClient {
  McpClient._({
    required this.kind,
    required this.name,
    this.command,
    Iterable<String>? args,
    this.environment,
    this.workingDirectory,
    this.url,
    this.headers,
  }) : args = args?.toList();

  /// Creates a configuration for a local MCP server accessed via stdio.
  ///
  /// - [command]: The executable command to run the server process.
  /// - [args]: Command line arguments to pass to the executable.
  /// - [environment]: Environment variables for the server process.
  /// - [workingDirectory]: Working directory for the server process.
  McpClient.local(
    String name, {
    required String command,
    Iterable<String> args = const [],
    Map<String, String>? environment,
    String? workingDirectory,
  }) : this._(
         kind: McpServerKind.local,
         name: name,
         command: command,
         args: args,
         environment: environment,
         workingDirectory: workingDirectory,
       );

  /// Creates a configuration for a remote MCP server accessed via HTTP.
  ///
  /// - [url]: The HTTP URL of the remote MCP server.
  /// - [headers]: Optional HTTP headers to include in requests.
  McpClient.remote(
    String name, {
    required Uri url,
    Map<String, String>? headers,
  }) : this._(
         kind: McpServerKind.remote,
         name: name,
         url: url,
         headers: headers,
       );

  /// The type of MCP server (local or remote).
  final McpServerKind kind;

  /// The local name of the MCP server.
  final String name;

  // Local server properties (null for remote servers)

  /// The executable command for local servers.
  final String? command;

  /// Command line arguments for local servers.
  final List<String>? args;

  /// Environment variables for local servers.
  final Map<String, String>? environment;

  /// Working directory for local servers.
  final String? workingDirectory;

  // Remote server properties (null for local servers)

  /// The HTTP URL for remote servers.
  final Uri? url;

  /// HTTP headers for remote servers.
  final Map<String, String>? headers;

  // Internal connection state
  mcp.Client? _client;
  mcp.Transport? _transport;
  String? _sessionId;

  /// Whether the server is connected.
  bool get isConnected => _client != null;

  /// Calls a tool on this MCP server.
  /// Automatically connects on first call if not already connected.
  ///
  /// - [toolName]: The name of the tool to call.
  /// - [arguments]: The arguments to pass to the tool.
  ///
  /// Returns the result from the tool execution.
  Future<Map<String, dynamic>> call(
    String toolName, [
    Map<String, dynamic>? arguments = const {},
  ]) async {
    if (!isConnected) await _connect();

    final result = await _client!.callTool(
      mcp.CallToolRequestParams(name: toolName, arguments: arguments),
    );

    // Convert MCP result to simple format
    final resultText = result.content
        .whereType<mcp.TextContent>()
        .map((content) => content.text)
        .join('');

    return {if (resultText.isNotEmpty) 'result': resultText};
  }

  /// Gets all tools from this MCP server as Agent Tool objects.
  /// Automatically connects if not already connected.
  Future<Iterable<Tool>> listTools() async {
    // NOTE: waiting on a fix for this issue:
    // https://github.com/leehack/mcp_dart/issues/11

    // Restore this one line of code, perform the appropriate mapping, including
    // the required parmaters in the inputSchema as before, and remove the rest
    // of the gunk when/if that happens. mcp_dart does it all better anyway!
    // final result = await _client!.listTools();

    if (kind == McpServerKind.remote) {
      return _getToolsViaHttp();
    } else {
      return _getToolsViaMcp();
    }
  }

  /// Gets tools using raw HTTP to preserve required fields.
  Future<Iterable<Tool>> _getToolsViaHttp() async {
    // Try tools/list first - some servers work without initialization
    var response = await _makeHttpRequest('tools/list');

    // If we get a 400 error, try initializing first then retry
    if (response.statusCode == 400) {
      await _initializeSession();
      response = await _makeHttpRequest('tools/list');
    }

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    // Parse the response - handle both SSE and direct JSON
    Map<String, dynamic> json;
    if (response.body.contains('event: message') ||
        response.body.startsWith('data: ')) {
      // Server-Sent Events format (like Zapier and DeepWiki)
      final lines = response.body.split('\n');
      String? jsonData;
      for (final line in lines) {
        if (line.startsWith('data: ') && line.length > 6) {
          final dataContent = line.substring(6).trim();
          if (dataContent.isNotEmpty && dataContent != 'ping') {
            jsonData = dataContent;
            break;
          }
        }
      }
      if (jsonData == null) {
        throw Exception('No data found in SSE response');
      }
      json = jsonDecode(jsonData) as Map<String, dynamic>;
    } else {
      // Direct JSON response (like Hugging Face)
      json = jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (json['error'] != null) {
      throw Exception('MCP Error: ${json['error']}');
    }

    final result = json['result'] as Map<String, dynamic>;
    final toolList = result['tools'] as List<dynamic>;

    final tools = <Tool>[];
    for (final toolJson in toolList) {
      final tool = toolJson as Map<String, dynamic>;
      final schemaJson = tool['inputSchema'] as Map<String, dynamic>;

      // Preserve the required fields from the raw schema
      final inputSchema = schemaJson.toSchema();

      tools.add(
        Tool(
          name: tool['name'] as String,
          description: '[$name] ${tool['description'] as String}',
          inputSchema: inputSchema,
          onCall: (args) => call(tool['name'] as String, args),
        ),
      );
    }
    return tools;
  }

  /// Gets tools using raw transport to preserve required fields for local
  /// servers.
  Future<Iterable<Tool>> _getToolsViaMcp() async {
    if (!isConnected) await _connect();

    // Send raw tools/list request to preserve required fields
    final rawResponse = await _sendRawJsonRpcRequest({
      'jsonrpc': '2.0',
      'id': DateTime.now().millisecondsSinceEpoch,
      'method': 'tools/list',
    });

    if (rawResponse['error'] != null) {
      throw Exception('MCP Error: ${rawResponse['error']}');
    }

    final result = rawResponse['result'] as Map<String, dynamic>;
    final toolList = result['tools'] as List<dynamic>;

    final tools = <Tool>[];
    for (final toolJson in toolList) {
      final tool = toolJson as Map<String, dynamic>;
      final schemaJson = tool['inputSchema'] as Map<String, dynamic>;

      // Preserve the required fields from the raw schema
      final inputSchema = schemaJson.toSchema();

      tools.add(
        Tool(
          name: tool['name'] as String,
          description: '[$name] ${tool['description'] as String}',
          inputSchema: inputSchema,
          onCall: (args) => call(tool['name'] as String, args),
        ),
      );
    }
    return tools;
  }

  /// Sends a raw JSON-RPC request and returns the raw JSON response.
  /// This bypasses mcp_dart's type system to preserve schema information.
  Future<Map<String, dynamic>> _sendRawJsonRpcRequest(
    Map<String, dynamic> request,
  ) async {
    final completer = Completer<Map<String, dynamic>>();
    final requestId = request['id'];

    // Set up a temporary message handler to capture the raw response
    final originalHandler = _transport!.onmessage;

    _transport!.onmessage = (message) {
      // Check if this is our response
      if (message is mcp.JsonRpcResponse && message.id == requestId) {
        // Convert back to raw JSON to preserve all fields
        final rawJson = message.toJson();
        completer.complete(rawJson);

        // Restore original handler
        _transport!.onmessage = originalHandler;
      } else if (originalHandler != null) {
        // Forward other messages to original handler
        originalHandler(message);
      }
    };

    // Send the raw request
    final requestMessage = mcp.JsonRpcRequest(
      id: requestId,
      method: request['method'] as String,
      params: request['params'],
    );

    await _transport!.send(requestMessage);

    return completer.future;
  }

  /// Makes an HTTP request to the MCP server.
  Future<http.Response> _makeHttpRequest(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json, text/event-stream',
      ...?headers,
      if (_sessionId != null) 'mcp-session-id': _sessionId!,
    };

    return http.post(
      url!,
      headers: requestHeaders,
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': DateTime.now().millisecondsSinceEpoch,
        'method': method,
        if (params != null) 'params': params,
      }),
    );
  }

  /// Initialize session for servers that require it.
  Future<void> _initializeSession() async {
    final response = await _makeHttpRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {'name': 'dartantic_ai', 'version': Pubspec.version},
    });

    if (response.statusCode == 200) {
      _sessionId = response.headers['mcp-session-id'];
    } else {
      throw Exception('Failed to initialize session: ${response.statusCode}');
    }
  }

  Future<void> _connect() async {
    if (isConnected) return;

    switch (kind) {
      case McpServerKind.local:
        _transport = mcp.StdioClientTransport(
          mcp.StdioServerParameters(
            command: command!,
            args: args ?? [],
            environment: environment,
            workingDirectory: workingDirectory,
            // Fix mcp_dart bug: must use normal mode to access stdout/stdin pipes
            stderrMode: ProcessStartMode.normal,
          ),
        );

      case McpServerKind.remote:
        _transport = mcp.StreamableHttpClientTransport(
          url!,
          opts:
              headers == null
                  ? null
                  : mcp.StreamableHttpClientTransportOptions(
                    requestInit: {'headers': headers},
                  ),
        );
    }

    _client = mcp.Client(
      const mcp.Implementation(name: 'dartantic_ai', version: Pubspec.version),
    );
    await _client!.connect(_transport!);
  }

  /// Disconnects from the MCP server.
  Future<void> disconnect() async {
    await _transport?.close();
    _client = null;
    _transport = null;
  }
}
