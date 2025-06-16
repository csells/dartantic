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
class McpServer {
  McpServer._({
    required this.kind,
    required this.name,
    this.command,
    this.args,
    this.environment,
    this.workingDirectory,
    this.url,
    this.headers,
  });

  /// Creates a configuration for a local MCP server accessed via stdio.
  ///
  /// - [command]: The executable command to run the server process.
  /// - [args]: Command line arguments to pass to the executable.
  /// - [environment]: Environment variables for the server process.
  /// - [workingDirectory]: Working directory for the server process.
  McpServer.local(
    String name, {
    required String command,
    List<String> args = const [],
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
  McpServer.remote(
    String name, {
    required String url,
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
  final String? url;

  /// HTTP headers for remote servers.
  final Map<String, String>? headers;

  // Internal connection state
  mcp.Client? _client;
  mcp.Transport? _transport;

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
    String toolName,
    Map<String, dynamic>? arguments,
  ) async {
    if (!isConnected) await _connect();

    final result = await _client!.callTool(
      mcp.CallToolRequestParams(name: toolName, arguments: arguments),
    );

    // Convert MCP result to simple format
    // TODO: Handle different content types (text, image, etc.)
    final resultText = result.content
        .whereType<mcp.TextContent>()
        .map((content) => content.text)
        .join('');

    return {if (resultText.isNotEmpty) 'result': resultText};
  }

  /// Gets all tools from this MCP server as Agent Tool objects.
  /// Automatically connects if not already connected.
  Future<List<Tool>> getTools() async {
    if (!isConnected) await _connect();

    final result = await _client!.listTools();
    return [
      for (final mcpTool in result.tools)
        Tool(
          name: mcpTool.name,
          description: '[$name] ${mcpTool.description}',
          inputSchema: mcpTool.inputSchema.toJson().toSchema(),
          onCall: (args) => call(mcpTool.name, args),
        ),
    ];
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
          ),
        );

      case McpServerKind.remote:
        _transport = mcp.StreamableHttpClientTransport(
          Uri.parse(url!),
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
