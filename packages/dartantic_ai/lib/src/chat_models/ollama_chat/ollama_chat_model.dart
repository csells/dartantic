import 'dart:async';
import 'dart:convert';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart'
    show ChatResponse, OllamaClient, OllamaConfig;

import 'ollama_chat_options.dart';
import 'ollama_message_mappers.dart' as ollama_mappers;

export 'ollama_chat_options.dart';

/// Wrapper around [Ollama](https://ollama.ai) Chat API that enables to interact
/// with the LLMs in a chat-like fashion.
class OllamaChatModel extends ChatModel<OllamaChatOptions> {
  /// Creates a [OllamaChatModel] instance.
  OllamaChatModel({
    required String name,
    List<Tool>? tools,
    super.temperature,
    OllamaChatOptions? defaultOptions,
    Uri? baseUrl,
    http.Client? client,
    Map<String, String>? headers,
    this.enableThinking = false,
  }) : _client = OllamaClient(
         config: OllamaConfig(
           baseUrl: baseUrl?.toString() ?? 'http://localhost:11434',
           defaultHeaders: headers ?? {},
         ),
         httpClient: client,
       ),
       _baseUrl = baseUrl ?? Uri.parse('http://localhost:11434'),
       _httpClient = client ?? http.Client(),
       _ownsHttpClient = client == null,
       _headers = headers ?? const {},
       super(
         name: name,
         defaultOptions: defaultOptions ?? const OllamaChatOptions(),
         tools: tools,
       ) {
    _logger.info(
      'Creating Ollama model: $name '
      'with ${tools?.length ?? 0} tools, temp: $temperature',
    );
  }

  static final Logger _logger = Logger('dartantic.chat.models.ollama');

  final OllamaClient _client;
  final Uri _baseUrl;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Map<String, String> _headers;

  /// Whether to enable thinking mode for reasoning models.
  final bool enableThinking;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    OllamaChatOptions? options,
    Schema? outputSchema,
  }) {
    // Check if we have both tools and output schema
    if (outputSchema != null &&
        super.tools != null &&
        super.tools!.isNotEmpty) {
      throw ArgumentError(
        'Ollama does not support using tools and typed output '
        '(outputSchema) simultaneously. Either use tools without outputSchema, '
        'or use outputSchema without tools.',
      );
    }

    _logger.info(
      'Starting Ollama chat stream with ${messages.length} '
      'messages for model: $name',
    );

    return _streamChatWithUsage(messages, options, outputSchema);
  }

  /// Streams chat completions using raw HTTP to preserve usage data.
  ///
  /// The ollama_dart SDK's `ChatStreamEvent` does not expose usage fields
  /// (`promptEvalCount`, `evalCount`) that the Ollama API includes in the
  /// final streaming chunk. This method bypasses the SDK's streaming API to
  /// parse each NDJSON line as a [ChatResponse], which preserves all fields
  /// including usage data.
  Stream<ChatResult<ChatMessage>> _streamChatWithUsage(
    List<ChatMessage> messages,
    OllamaChatOptions? options,
    Schema? outputSchema,
  ) async* {
    final request = ollama_mappers.generateChatCompletionRequest(
      messages,
      modelName: name,
      options: options,
      defaultOptions: defaultOptions,
      tools: tools,
      temperature: temperature,
      outputSchema: outputSchema,
      enableThinking: enableThinking,
    );

    final url = _baseUrl.resolve('/api/chat');
    final httpRequest = http.Request('POST', url)
      ..headers.addAll({
        'Content-Type': 'application/json',
        ..._headers,
      })
      ..body = jsonEncode(request.toJson());

    final streamedResponse = await _httpClient.send(httpRequest);
    var chunkCount = 0;

    // Parse NDJSON stream, using ChatResponse.fromJson to preserve usage
    await for (final line in streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final json = jsonDecode(line) as Map<String, dynamic>;
      final chatResponse = ChatResponse.fromJson(json);

      chunkCount++;
      _logger.fine('Received Ollama stream chunk $chunkCount');

      yield ollama_mappers.chatResponseToChatResult(chatResponse);
    }
  }

  @override
  void dispose() {
    _client.close();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}
