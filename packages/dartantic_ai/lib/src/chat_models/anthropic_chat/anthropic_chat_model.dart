import 'dart:async';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as a;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../media_gen_models/anthropic/anthropic_files_client.dart';
import '../../media_gen_models/anthropic/anthropic_tool_deliverable_tracker.dart';
import 'anthropic_chat_options.dart';
import 'anthropic_message_mappers.dart';
import 'anthropic_server_side_tools.dart';

/// Wrapper around [Anthropic Messages
/// API](https://docs.anthropic.com/en/api/messages) (aka Claude API).
class AnthropicChatModel extends ChatModel<AnthropicChatOptions> {
  /// Creates a [AnthropicChatModel] instance.
  ///
  /// When [autoDownloadFiles] is true (the default when code execution is
  /// enabled), files created by code execution are automatically downloaded
  /// from the Anthropic Files API and added as DataParts to messages.
  AnthropicChatModel({
    required super.name,
    required String apiKey,
    Uri? baseUrl,
    super.tools,
    super.temperature,
    bool enableThinking = false,
    http.Client? client,
    Map<String, String>? headers,
    AnthropicChatOptions? defaultOptions,
    List<String> betaFeatures = const [],
    bool? autoDownloadFiles,
  }) : _enableThinking = enableThinking,
       _client = _AnthropicStreamingClient(
         apiKey: apiKey,
         baseUrl: baseUrl?.toString(),
         client: client,
         headers: headers,
         betaFeatures: betaFeatures,
       ),
       _filesClient = (autoDownloadFiles ?? _hasCodeExecution(defaultOptions))
           ? AnthropicFilesClient(
               apiKey: apiKey,
               baseUrl: baseUrl,
               betaFeatures: betaFeatures,
             )
           : null,
       super(defaultOptions: defaultOptions ?? const AnthropicChatOptions()) {
    _logger.info(
      'Creating Anthropic model: $name with '
      '${tools?.length ?? 0} tools, temp: $temperature, '
      'thinking: $enableThinking, autoDownloadFiles: ${_filesClient != null}',
    );
  }

  /// Logger for Anthropic chat model operations.
  static final Logger _logger = Logger('dartantic.chat.models.anthropic');

  final _AnthropicStreamingClient _client;
  final bool _enableThinking;
  final AnthropicFilesClient? _filesClient;

  /// Checks if code execution is enabled in the options.
  static bool _hasCodeExecution(AnthropicChatOptions? options) {
    if (options == null) return false;

    // Check serverSideTools enum set
    final serverSideTools = options.serverSideTools;
    if (serverSideTools != null &&
        serverSideTools.contains(AnthropicServerSideTool.codeInterpreter)) {
      return true;
    }

    // Check manual serverTools configs
    final serverTools = options.serverTools;
    if (serverTools != null) {
      for (final tool in serverTools) {
        if (tool.name == 'code_execution' ||
            tool.type.startsWith('code_execution')) {
          return true;
        }
      }
    }

    return false;
  }

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    AnthropicChatOptions? options,
    Schema? outputSchema,
  }) async* {
    _logger.info(
      'Starting Anthropic chat stream with '
      '${messages.length} messages for model: $name',
    );

    final transformer = MessageStreamEventTransformer();
    final request = createMessageRequest(
      messages,
      modelName: name,
      enableThinking: _enableThinking,
      tools: tools,
      temperature: temperature,
      options: options,
      defaultOptions: defaultOptions,
      outputSchema: outputSchema,
    );

    // Create tracker for file downloads if files client is available
    final tracker = _filesClient != null
        ? AnthropicToolDeliverableTracker(
            _filesClient,
            targetMimeTypes: const {'*/*'},
          )
        : null;

    var chunkCount = 0;
    ChatResult<ChatMessage>? lastResult;

    await for (final result in _createMessageEventStream(
      request,
      transformer,
    ).transform(transformer)) {
      chunkCount++;
      _logger.fine('Received Anthropic stream chunk $chunkCount');

      // Process metadata for file deliverables during streaming
      if (tracker != null && result.metadata.isNotEmpty) {
        final emission = await tracker.handleMetadata(result.metadata);
        if (emission.assets.isNotEmpty) {
          // Yield assets discovered from metadata immediately
          yield ChatResult<ChatMessage>(
            id: result.id,
            output: ChatMessage(
              role: ChatMessageRole.model,
              parts: emission.assets,
            ),
            messages: [
              ChatMessage(role: ChatMessageRole.model, parts: emission.assets),
            ],
            finishReason: FinishReason.unspecified,
            metadata: const {},
            usage: null,
          );
        }
      }

      lastResult = result;
      yield ChatResult<ChatMessage>(
        id: result.id,
        output: result.output,
        messages: result.messages,
        finishReason: result.finishReason,
        metadata: result.metadata,
        usage: result.usage,
      );
    }

    // After streaming completes, collect any remaining files from the API
    if (tracker != null && lastResult != null) {
      final remoteFiles = await tracker.collectRecentFiles();
      if (remoteFiles.isNotEmpty) {
        _logger.fine(
          'Downloaded ${remoteFiles.length} files from Anthropic Files API',
        );
        yield ChatResult<ChatMessage>(
          id: lastResult.id,
          output: ChatMessage(role: ChatMessageRole.model, parts: remoteFiles),
          messages: [
            ChatMessage(role: ChatMessageRole.model, parts: remoteFiles),
          ],
          finishReason: FinishReason.unspecified,
          metadata: {'auto_downloaded_files': remoteFiles.length},
          usage: null,
        );
      }
    }
  }

  @override
  void dispose() {
    _client.close();
    _filesClient?.close();
  }

  Stream<a.MessageStreamEvent> _createMessageEventStream(
    a.MessageCreateRequest request,
    MessageStreamEventTransformer transformer,
  ) async* {
    await for (final event in _client.messageStream(request)) {
      // Handle ContentBlockStartEvent for server-side tools
      if (event is a.ContentBlockStartEvent) {
        final cb = event.contentBlock;
        if (cb is a.ServerToolUseBlock) {
          // Register raw tool content for server-side tools
          transformer.registerRawToolContent(cb.id, cb.input);
        }
      }

      // Handle SignatureDelta for extended thinking
      if (event is a.ContentBlockDeltaEvent) {
        final delta = event.delta;
        if (delta is a.SignatureDelta) {
          if (delta.signature.isNotEmpty) {
            _logger.fine('Captured signature delta for thinking block');
            transformer.recordSignatureDelta(delta.signature);
          }
          continue;
        }
        // Skip CitationsDelta as it's not supported yet
        if (delta is a.CitationsDelta) {
          _logger.fine('Skipping unsupported citations_delta event');
          continue;
        }
        if (delta is a.CompactionDelta) {
          _logger.fine('Skipping unsupported compaction_delta event');
          continue;
        }
      }

      yield event;
    }
  }
}

class _AnthropicStreamingClient {
  _AnthropicStreamingClient({
    required String apiKey,
    String? baseUrl,
    http.Client? client,
    Map<String, String>? headers,
    List<String> betaFeatures = const [],
  }) : _client = a.AnthropicClient(
         config: a.AnthropicConfig(
           authProvider: a.ApiKeyProvider(apiKey),
           baseUrl: baseUrl ?? 'https://api.anthropic.com',
           defaultHeaders: {
             'anthropic-beta': _buildBetaHeader(betaFeatures),
             ...?headers,
           },
         ),
         httpClient: client,
       );

  final a.AnthropicClient _client;

  static const List<String> _defaultBetaFeatures = <String>[
    'message-batches-2024-09-24',
    'prompt-caching-2024-07-31',
    'computer-use-2024-10-22',
  ];

  static String _buildBetaHeader(List<String> extras) {
    final features = <String>{..._defaultBetaFeatures, ...extras};
    return features.join(',');
  }

  Stream<a.MessageStreamEvent> messageStream(a.MessageCreateRequest request) =>
      _client.messages.createStream(request);

  void close() => _client.close();
}
