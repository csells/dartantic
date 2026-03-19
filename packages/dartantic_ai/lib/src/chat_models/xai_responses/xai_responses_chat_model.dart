import 'dart:async';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../../retry_http_client.dart';
import '../../shared/openai_utils.dart';
import '../openai_responses/openai_responses_attachment_types.dart';
import '../openai_responses/openai_responses_chat_options.dart';
import '../openai_responses/openai_responses_invocation_builder.dart';
import '../openai_responses/openai_responses_server_side_tool_mapper.dart';
import '../openai_responses/openai_responses_server_side_tools.dart';
import 'xai_responses_chat_options.dart';
import 'xai_responses_event_mapper.dart';

/// Chat model backed by the xAI Responses API.
///
/// This implementation is intentionally provider-native (not a wrapper around
/// the OpenAI responses model class). It reuses shared low-level primitives
/// (event mapping and invocation builders) while keeping xAI-specific request
/// shaping in this file.
class XAIResponsesChatModel extends ChatModel<XAIResponsesChatModelOptions> {
  /// Creates a new xAI Responses chat model instance.
  XAIResponsesChatModel({
    required super.name,
    required super.defaultOptions,
    super.tools,
    this.baseUrl,
    this.apiKey,
    http.Client? httpClient,
    Map<String, String>? headers,
  }) : _client = openai.OpenAIClient(
         config: openai.OpenAIConfig(
           authProvider: apiKey != null ? openai.ApiKeyProvider(apiKey) : null,
           baseUrl: baseUrl?.toString() ?? 'https://api.x.ai/v1',
           defaultHeaders: headers ?? const {},
           retryPolicy: const openai.RetryPolicy(maxRetries: 0),
         ),
         httpClient: RetryHttpClient(inner: httpClient ?? http.Client()),
       );

  static final Logger _logger = Logger('dartantic.chat.models.xai_responses');

  final openai.OpenAIClient _client;

  /// Base URL override for the xAI API.
  final Uri? baseUrl;

  /// API key used for authentication.
  final String? apiKey;

  /// Maps xAI options to the internal OpenAI SDK options.
  @visibleForTesting
  static OpenAIResponsesChatModelOptions toOpenAIOptionsForTesting(
    XAIResponsesChatModelOptions options,
  ) => _toOpenAIOptionsStatic(options);

  /// Builds raw MCP tool payloads sent to the Responses API.
  @visibleForTesting
  static List<Map<String, Object?>> buildMcpToolsForTesting(
    List<XAIMcpToolConfig>? tools,
  ) => _buildMcpToolsStatic(tools);

  List<openai.ResponseTool> _buildFunctionTools() {
    final registeredTools = tools;
    if (registeredTools == null || registeredTools.isEmpty) {
      return const [];
    }

    return registeredTools
        .map(
          (tool) => openai.FunctionTool(
            name: tool.name,
            description: tool.description,
            parameters: OpenAIUtils.prepareSchemaForOpenAI(
              Map<String, dynamic>.from(tool.inputSchema.value),
            ),
          ),
        )
        .toList(growable: false);
  }

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    XAIResponsesChatModelOptions? options,
    Schema? outputSchema,
  }) async* {
    final invocation = _buildInvocation(messages, options, outputSchema);
    _validateInvocation(invocation);
    final rawStream = _sendRawRequest(invocation, options);
    final mapper = _createMapper(invocation);
    yield* _consumeResponseStream(rawStream, mapper);
  }

  @override
  void dispose() => _client.close();

  Future<ContainerFileData> _downloadContainerFile(
    String containerId,
    String fileId,
  ) async {
    final bytes = await _client.containers.files.retrieveContent(
      containerId,
      fileId,
    );
    return ContainerFileData(bytes: bytes);
  }

  List<openai.ResponseTool> _buildAllTools(
    OpenAIServerSideToolContext context,
  ) => [
    ..._buildFunctionTools(),
    ...OpenAIResponsesServerSideToolMapper.buildServerSideTools(
      serverSideTools: context.enabledTools,
      fileSearchConfig: context.fileSearchConfig,
      webSearchConfig: context.webSearchConfig,
      codeInterpreterConfig: context.codeInterpreterConfig,
    ),
  ];

  OpenAIResponsesInvocation _buildInvocation(
    List<ChatMessage> messages,
    XAIResponsesChatModelOptions? options,
    Schema? outputSchema,
  ) => OpenAIResponsesInvocationBuilder(
    messages: messages,
    options: _toOpenAIOptionsStatic(options),
    defaultOptions: _toOpenAIOptionsStatic(defaultOptions),
    outputSchema: outputSchema,
  ).build();

  void _validateInvocation(OpenAIResponsesInvocation invocation) {
    if ((invocation.serverSide.codeInterpreterConfig?.shouldReuseContainer ??
            false) &&
        !invocation.store) {
      _logger.warning(
        'Code interpreter container reuse requested but store=false; '
        'previous_response_id will not be persisted.',
      );
    }
  }

  Stream<Map<String, dynamic>> _sendRawRequest(
    OpenAIResponsesInvocation invocation,
    XAIResponsesChatModelOptions? options,
  ) {
    final allTools = _buildAllTools(invocation.serverSide);
    final textFormat = invocation.parameters.textFormat;
    final xaiOptions = options ?? defaultOptions;

    final requestBody = openai.CreateResponseRequest(
      model: name,
      input: invocation.history.input ?? const openai.ResponseInputText(''),
      instructions: invocation.history.instructions,
      previousResponseId: invocation.history.previousResponseId,
      store: invocation.store,
      topP: invocation.parameters.topP,
      maxOutputTokens: invocation.parameters.maxOutputTokens,
      reasoning: invocation.parameters.reasoning,
      text: textFormat != null ? openai.TextConfig(format: textFormat) : null,
      toolChoice: null,
      tools: allTools.isEmpty ? null : allTools,
      parallelToolCalls: invocation.parameters.parallelToolCalls,
      metadata: invocation.parameters.metadata,
      include: invocation.parameters.include
          ?.map(openai.Include.fromJson)
          .toList(),
      truncation: invocation.parameters.truncation,
    ).toJson();

    final mcpTools = _buildMcpToolsStatic(xaiOptions.mcpTools);
    if (mcpTools.isNotEmpty) {
      final existing = requestBody['tools'] as List<dynamic>? ?? <dynamic>[];
      requestBody['tools'] = [...existing, ...mcpTools];
    }

    requestBody['stream'] = true;

    return _client.responses.streamSseEvents(
      endpoint: '/responses',
      body: requestBody,
    );
  }

  static List<Map<String, Object?>> _buildMcpToolsStatic(
    List<XAIMcpToolConfig>? tools,
  ) {
    if (tools == null || tools.isEmpty) return const [];
    // xAI MCP tool payload format (native): type=mcp + server_url and optional
    // access-control/auth headers. These entries are appended directly to the
    // outgoing `tools` array.
    return tools
        .map(
          (tool) => <String, Object?>{
            'type': 'mcp',
            'server_url': tool.serverUrl,
            if (tool.serverLabel != null) 'server_label': tool.serverLabel,
            if (tool.serverDescription != null)
              'server_description': tool.serverDescription,
            if (tool.allowedToolNames != null)
              'allowed_tool_names': tool.allowedToolNames,
            if (tool.authorization != null) 'authorization': tool.authorization,
            if (tool.extraHeaders != null) 'extra_headers': tool.extraHeaders,
          },
        )
        .toList(growable: false);
  }

  XAIResponsesEventMapper _createMapper(OpenAIResponsesInvocation invocation) =>
      XAIResponsesEventMapper(
        storeSession: invocation.store,
        downloadContainerFile: _downloadContainerFile,
      );

  Stream<ChatResult<ChatMessage>> _consumeResponseStream(
    Stream<Map<String, dynamic>> rawStream,
    XAIResponsesEventMapper mapper,
  ) async* {
    try {
      await for (final json in rawStream) {
        final type = json['type'] as String?;
        yield* mapper.handleRawJson(json);
        if (type == 'response.output_item.done') {
          final item = json['item'] as Map<String, dynamic>?;
          if (item != null && item['type'] == 'code_interpreter_call') {
            final containerId = item['container_id'] as String?;
            if (containerId != null) {
              mapper.containerId = containerId;
            }
          }
        }
        if (type == 'keepalive') continue;

        late final openai.ResponseStreamEvent event;
        try {
          event = openai.ResponseStreamEvent.fromJson(json);
        } on Object catch (error, stackTrace) {
          if (_shouldSkipStreamParseError(error, stackTrace, json, type)) {
            _logger.fine(
              'Skipping xAI event that openai_dart cannot parse: $type',
            );
            continue;
          }
          _logger.severe(
            'Failed to parse xAI Responses stream event: $type',
            error,
            stackTrace,
          );
          rethrow;
        }
        yield* mapper.handleTyped(event);
      }
    } on Object catch (error, stackTrace) {
      _logger.severe('xAI Responses stream error: $error', error, stackTrace);
      rethrow;
    }
  }

  static bool _looksLikeMcpTypeError(
    TypeError error,
    Map<String, dynamic> json,
    String? type,
  ) {
    final message = error.toString().toLowerCase();
    if (message.contains('mcp')) return true;
    if (type != null && type.contains('mcp')) return true;

    final item = json['item'];
    if (item is Map<String, dynamic>) {
      final itemType = (item['type'] as String?)?.toLowerCase();
      if (itemType != null && itemType.contains('mcp')) {
        return true;
      }
    }

    return false;
  }

  static bool _shouldSkipStreamParseError(
    Object error,
    StackTrace stackTrace,
    Map<String, dynamic> json,
    String? type,
  ) {
    // xAI MCP output item payloads can differ from OpenAI's expected schema
    // in openai_dart (e.g., nullable fields typed as required), which can
    // throw during JSON -> typed event parsing.
    if (error is TypeError &&
        (_looksLikeMcpTypeError(error, json, type) ||
            stackTrace.toString().contains('McpCallOutputItem'))) {
      return true;
    }

    // xAI can emit native "custom_tool_call" output items that are currently
    // unknown to openai_dart. Skip these transport-level events while still
    // processing the rest of the stream.
    if (error is FormatException &&
        _looksLikeUnknownCustomOrMcpOutputItem(error, json, type)) {
      return true;
    }

    return false;
  }

  static bool _looksLikeUnknownCustomOrMcpOutputItem(
    FormatException error,
    Map<String, dynamic> json,
    String? type,
  ) {
    final message = error.message.toLowerCase();
    if (!message.contains('unknown outputitem type')) {
      return false;
    }

    final eventType = type?.toLowerCase();
    if (eventType != null && eventType.contains('custom_tool')) {
      return true;
    }
    if (eventType != null && eventType.contains('mcp')) {
      return true;
    }

    return _containsCustomOrMcpOutputType(json);
  }

  static bool _containsCustomOrMcpOutputType(Object? value) {
    if (value is Map<String, dynamic>) {
      final type = (value['type'] as String?)?.toLowerCase();
      if (type != null &&
          (type.startsWith('custom_') || type.contains('mcp'))) {
        return true;
      }
      for (final entry in value.entries) {
        if (_containsCustomOrMcpOutputType(entry.value)) {
          return true;
        }
      }
      return false;
    }

    if (value is List) {
      for (final item in value) {
        if (_containsCustomOrMcpOutputType(item)) {
          return true;
        }
      }
      return false;
    }

    return false;
  }

  /// Exposes parse skip classification for focused unit tests.
  @visibleForTesting
  static bool shouldSkipStreamParseErrorForTesting({
    required Object error,
    required StackTrace stackTrace,
    required Map<String, dynamic> json,
    required String? type,
  }) => _shouldSkipStreamParseError(error, stackTrace, json, type);

  static OpenAIResponsesChatModelOptions _toOpenAIOptionsStatic(
    XAIResponsesChatModelOptions? options,
  ) {
    final resolved = options ?? const XAIResponsesChatModelOptions();
    final hasMcpTools = (resolved.mcpTools ?? const []).isNotEmpty;
    final baseTools = resolved.serverSideTools ?? const <XAIServerSideTool>{};
    final openAITools = baseTools
        .where((tool) => tool != XAIServerSideTool.mcp)
        .map(_mapToolStatic)
        .toSet();

    return OpenAIResponsesChatModelOptions(
      topP: resolved.topP,
      maxOutputTokens: resolved.maxOutputTokens,
      store: resolved.store,
      metadata: resolved.metadata,
      include: resolved.include,
      parallelToolCalls: resolved.parallelToolCalls,
      reasoning: resolved.reasoning,
      reasoningEffort: _mapReasoningEffortStatic(resolved.reasoningEffort),
      reasoningSummary: _mapReasoningSummaryStatic(resolved.reasoningSummary),
      responseFormat: resolved.responseFormat,
      truncationStrategy: resolved.truncationStrategy,
      user: resolved.user,
      imageDetail: _mapImageDetailStatic(resolved.imageDetail),
      serverSideTools: {
        ...openAITools,
        if (hasMcpTools) ...<OpenAIServerSideTool>{},
      },
      fileSearchConfig: _mapFileSearchConfigStatic(resolved.fileSearchConfig),
      webSearchConfig: _mapWebSearchConfigStatic(resolved.webSearchConfig),
      codeInterpreterConfig: _mapCodeConfigStatic(
        resolved.codeInterpreterConfig,
      ),
    );
  }

  static OpenAIServerSideTool _mapToolStatic(
    XAIServerSideTool tool,
  ) => switch (tool) {
    XAIServerSideTool.webSearch => OpenAIServerSideTool.webSearch,
    XAIServerSideTool.fileSearch => OpenAIServerSideTool.fileSearch,
    XAIServerSideTool.imageGeneration => OpenAIServerSideTool.imageGeneration,
    XAIServerSideTool.codeInterpreter => OpenAIServerSideTool.codeInterpreter,
    XAIServerSideTool.mcp => throw StateError(
      'MCP is handled via request JSON',
    ),
  };

  static OpenAIReasoningEffort? _mapReasoningEffortStatic(
    XAIReasoningEffort? effort,
  ) => switch (effort) {
    XAIReasoningEffort.low => OpenAIReasoningEffort.low,
    XAIReasoningEffort.medium => OpenAIReasoningEffort.medium,
    XAIReasoningEffort.high => OpenAIReasoningEffort.high,
    null => null,
  };

  static OpenAIReasoningSummary? _mapReasoningSummaryStatic(
    XAIReasoningSummary? summary,
  ) => switch (summary) {
    XAIReasoningSummary.detailed => OpenAIReasoningSummary.detailed,
    XAIReasoningSummary.concise => OpenAIReasoningSummary.concise,
    XAIReasoningSummary.auto => OpenAIReasoningSummary.auto,
    XAIReasoningSummary.none => OpenAIReasoningSummary.none,
    null => null,
  };

  static openai.ImageDetail? _mapImageDetailStatic(XAIImageDetail? detail) =>
      switch (detail) {
        XAIImageDetail.auto => openai.ImageDetail.auto,
        XAIImageDetail.low => openai.ImageDetail.low,
        XAIImageDetail.high => openai.ImageDetail.high,
        null => null,
      };

  static FileSearchConfig? _mapFileSearchConfigStatic(
    XAIFileSearchConfig? config,
  ) {
    if (config == null) return null;
    return FileSearchConfig(
      vectorStoreIds: config.vectorStoreIds,
      maxResults: config.maxResults,
      filters: config.filters,
      ranker: config.ranker,
      scoreThreshold: config.scoreThreshold,
    );
  }

  static WebSearchConfig? _mapWebSearchConfigStatic(
    XAIWebSearchConfig? config,
  ) {
    if (config == null) return null;
    return WebSearchConfig(
      contextSize: switch (config.contextSize) {
        XAIWebSearchContextSize.low => WebSearchContextSize.low,
        XAIWebSearchContextSize.medium => WebSearchContextSize.medium,
        XAIWebSearchContextSize.high => WebSearchContextSize.high,
        null => null,
      },
      location: config.location == null
          ? null
          : WebSearchLocation(
              city: config.location!.city,
              region: config.location!.region,
              country: config.location!.country,
              timezone: config.location!.timezone,
            ),
      followupQuestions: config.followupQuestions,
      searchContentTypes: _mapSearchTypesStatic(config.searchContentTypes),
    );
  }

  static List<openai.SearchContentType>? _mapSearchTypesStatic(
    List<String>? types,
  ) {
    if (types == null) return null;
    final mapped = <openai.SearchContentType>[];
    for (final type in types) {
      switch (type.trim().toLowerCase()) {
        case 'text':
          mapped.add(openai.SearchContentType.text);
        case 'image':
          mapped.add(openai.SearchContentType.image);
      }
    }
    return mapped.isEmpty ? null : mapped;
  }

  static CodeInterpreterConfig? _mapCodeConfigStatic(
    XAICodeInterpreterConfig? config,
  ) {
    if (config == null) return null;
    return CodeInterpreterConfig(
      containerId: config.containerId,
      fileIds: config.fileIds,
    );
  }
}
