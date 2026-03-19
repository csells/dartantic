import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:meta/meta.dart';

/// Options for configuring the xAI Responses chat model.
@immutable
class XAIResponsesChatModelOptions extends ChatModelOptions {
  /// Creates a new set of options for the xAI Responses chat model.
  const XAIResponsesChatModelOptions({
    this.topP,
    this.maxOutputTokens,
    this.store,
    this.metadata,
    this.include,
    this.parallelToolCalls,
    this.reasoning,
    this.reasoningEffort,
    this.reasoningSummary,
    this.responseFormat,
    this.truncationStrategy,
    this.user,
    this.imageDetail,
    this.serverSideTools,
    this.fileSearchConfig,
    this.webSearchConfig,
    this.codeInterpreterConfig,
    this.xSearchConfig,
    this.mcpTools,
  });

  /// Nucleus sampling parameter.
  final double? topP;

  /// Maximum number of output tokens.
  final int? maxOutputTokens;

  /// Whether to persist server-side session state.
  final bool? store;

  /// Optional metadata forwarded to the API.
  final Map<String, dynamic>? metadata;

  /// Additional response fields to include.
  final List<String>? include;

  /// Whether multiple tool calls can run in parallel.
  final bool? parallelToolCalls;

  /// Reasoning configuration payload.
  final Map<String, dynamic>? reasoning;

  /// Requested reasoning effort level.
  final XAIReasoningEffort? reasoningEffort;

  /// Requested reasoning summary style.
  final XAIReasoningSummary? reasoningSummary;

  /// Response formatting configuration.
  final Map<String, dynamic>? responseFormat;

  /// Truncation configuration.
  final Map<String, dynamic>? truncationStrategy;

  /// End-user identifier.
  final String? user;

  /// Preferred detail for image inputs.
  final XAIImageDetail? imageDetail;

  /// Enabled xAI server-side tools.
  final Set<XAIServerSideTool>? serverSideTools;

  /// Configuration for the `file_search` tool.
  final XAIFileSearchConfig? fileSearchConfig;

  /// Configuration for the `web_search` tool.
  final XAIWebSearchConfig? webSearchConfig;

  /// Configuration for the `code_interpreter` tool.
  final XAICodeInterpreterConfig? codeInterpreterConfig;

  /// Configuration for the `x_search` tool.
  final XAIXSearchConfig? xSearchConfig;

  /// Configuration for one or more remote MCP tools.
  final List<XAIMcpToolConfig>? mcpTools;
}

/// Reasoning effort levels for xAI Responses models.
enum XAIReasoningEffort {
  /// Lower latency, lower reasoning depth.
  low,

  /// Balanced latency and reasoning depth.
  medium,

  /// Highest reasoning depth.
  high,
}

/// Reasoning summary verbosity preference for xAI Responses.
enum XAIReasoningSummary {
  /// Return a detailed summary.
  detailed,

  /// Return a concise summary.
  concise,

  /// Let the model choose.
  auto,

  /// Do not request summary content.
  none,
}

/// Preferred detail level for image inputs.
enum XAIImageDetail {
  /// Automatic detail selection.
  auto,

  /// Lower-detail processing.
  low,

  /// Higher-detail processing.
  high,
}

/// xAI server-side tools for Responses calls.
enum XAIServerSideTool {
  /// Web search tool.
  webSearch,

  /// X Search tool.
  xSearch,

  /// File search tool.
  fileSearch,

  /// Code interpreter tool.
  codeInterpreter,

  /// Remote MCP tool.
  mcp,
}

/// Configuration for the xAI `file_search` tool.
@immutable
class XAIFileSearchConfig {
  /// Creates a file search configuration.
  const XAIFileSearchConfig({
    this.vectorStoreIds = const <String>[],
    this.maxResults,
    this.filters,
    this.ranker,
    this.scoreThreshold,
  });

  /// Vector store IDs to search across.
  final List<String> vectorStoreIds;

  /// Maximum number of result chunks returned by the API.
  final int? maxResults;

  /// Optional server-side filter payload.
  final Map<String, dynamic>? filters;

  /// Optional ranker identifier.
  final String? ranker;

  /// Minimum score threshold for returned chunks.
  final num? scoreThreshold;
}

/// Context size hint for web search.
enum XAIWebSearchContextSize {
  /// Lower context for faster responses.
  low,

  /// Balanced context size.
  medium,

  /// Maximum context collection.
  high,
}

/// Approximate user location for web search.
@immutable
class XAIWebSearchLocation {
  /// Creates a web search location hint.
  const XAIWebSearchLocation({
    this.city,
    this.region,
    this.country,
    this.timezone,
  });

  /// City hint.
  final String? city;

  /// Region/state hint.
  final String? region;

  /// Country hint.
  final String? country;

  /// IANA timezone hint.
  final String? timezone;
}

/// Configuration for the xAI `web_search` tool.
@immutable
class XAIWebSearchConfig {
  /// Creates a web search configuration.
  const XAIWebSearchConfig({
    this.contextSize,
    this.location,
    this.followupQuestions,
    this.searchContentTypes,
  });

  /// Context size hint.
  final XAIWebSearchContextSize? contextSize;

  /// Optional user location hint.
  final XAIWebSearchLocation? location;

  /// Whether follow-up questions are requested.
  final bool? followupQuestions;

  /// Desired content types, e.g. `text` or `image`.
  final List<String>? searchContentTypes;
}

/// Configuration for the xAI `code_interpreter` tool.
@immutable
class XAICodeInterpreterConfig {
  /// Creates a code interpreter configuration.
  const XAICodeInterpreterConfig({this.containerId, this.fileIds});

  /// Existing container ID to reuse.
  final String? containerId;

  /// File IDs to mount into the container.
  final List<String>? fileIds;
}

/// Configuration for the xAI `x_search` tool.
@immutable
class XAIXSearchConfig {
  /// Creates an X Search configuration.
  const XAIXSearchConfig({
    this.allowedXHandles,
    this.excludedXHandles,
    this.fromDate,
    this.toDate,
    this.enableImageUnderstanding,
    this.enableVideoUnderstanding,
  });

  /// Only consider posts from these X handles (max 10).
  ///
  /// Cannot be set together with [excludedXHandles].
  final List<String>? allowedXHandles;

  /// Exclude posts from these X handles (max 10).
  ///
  /// Cannot be set together with [allowedXHandles].
  final List<String>? excludedXHandles;

  /// Start date for the search range (ISO8601 format, e.g. `"2025-10-01"`).
  final String? fromDate;

  /// End date for the search range (ISO8601 format, e.g. `"2025-10-10"`).
  final String? toDate;

  /// Whether to analyse images found in X posts.
  final bool? enableImageUnderstanding;

  /// Whether to analyse videos found in X posts.
  final bool? enableVideoUnderstanding;
}

/// Configuration for a remote MCP server tool.
@immutable
class XAIMcpToolConfig {
  /// Creates an MCP server configuration.
  const XAIMcpToolConfig({
    required this.serverUrl,
    this.serverLabel,
    this.serverDescription,
    this.allowedToolNames,
    this.authorization,
    this.extraHeaders,
  });

  /// MCP server URL.
  final String serverUrl;

  /// Optional display label for the server.
  final String? serverLabel;

  /// Optional server description.
  final String? serverDescription;

  /// Optional allowlist of tools.
  final List<String>? allowedToolNames;

  /// Optional bearer token forwarded as Authorization.
  final String? authorization;

  /// Optional custom headers forwarded to the MCP server.
  final Map<String, String>? extraHeaders;
}
