import 'dart:async';
import 'dart:io';

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
    if (!isConnected) await _connect();

    final result = await _client!.listTools();

    final tools = <Tool>[];
    for (final tool in result.tools) {
      tools.add(
        Tool(
          name: tool.name,
          description: '[$name] ${tool.description ?? ''}',
          inputSchema: tool.inputSchema.toJson().toSchema(),
          onCall: (args) => call(tool.name, args),
        ),
      );
    }
    return tools;
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
