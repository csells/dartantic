// ignore_for_file: discarded_futures

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:llamadart/llamadart.dart';
import 'package:logging/logging.dart';

import 'llamadart_chat_options.dart';
import 'llamadart_message_mappers.dart';
import 'model_resolvers.dart' show ModelResolver;

/// Chat model for Llamadart (local llama.cpp inference)
///
/// **Token Usage**: llamadart does not expose token counting in its API,
/// so ChatResult.usage will always be null. The underlying llama.cpp library
/// supports tokenization, but the llamadart Dart bindings (v0.3.0) don't
/// expose this functionality. This is a limitation of llamadart, not Dartantic.
class LlamadartChatModel extends ChatModel<LlamadartChatOptions> {
  /// Creates a [LlamadartChatModel]
  LlamadartChatModel({
    required super.name,
    required ModelResolver resolver,
    super.tools,
    super.temperature,
    LlamadartChatOptions? defaultOptions,
  })  : _modelName = name,
        _resolver = resolver,
        _engine = LlamaEngine(_selectBackend()),
        super(
          defaultOptions: defaultOptions ?? const LlamadartChatOptions(),
        );

  static final Logger _logger = Logger('dartantic.chat.models.llamadart');

  final String _modelName;
  final ModelResolver _resolver;
  final LlamaEngine _engine;
  bool _modelLoaded = false;

  /// Use llamadart's factory which handles platform detection
  static LlamaBackend _selectBackend() => createBackend();

  Future<void> _ensureModelLoaded() async {
    if (!_modelLoaded) {
      final resolvedPath = await _resolveModelPath(_modelName);
      _logger.info('Loading model from: $resolvedPath');
      await _engine.loadModel(resolvedPath);
      _modelLoaded = true;
    }
  }

  Future<String> _resolveModelPath(String name) async {
    // Check if already a URI scheme
    final uri = Uri.tryParse(name);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme == 'file') return uri.path;
      if (uri.scheme == 'asset' ||
          uri.scheme == 'https' ||
          uri.scheme == 'http' ||
          uri.scheme == 'hf') {
        return name; // Pass to llamadart as-is
      }
    }

    // Use resolver
    return _resolver.resolveModel(name);
  }

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    LlamadartChatOptions? options,
    Schema? outputSchema,
  }) async* {
    if (outputSchema != null) {
      throw UnsupportedError('Structured output not supported by Llamadart');
    }

    await _ensureModelLoaded();

    final llamaMessages = messages.toLlamaMessages();
    var chunkCount = 0;

    await for (final token in _engine.chat(llamaMessages)) {
      chunkCount++;
      _logger.fine('Received llamadart stream chunk $chunkCount');

      // ChatModel ONLY maps chunks to ChatResult - NO accumulation
      // Agent/Orchestrator handles accumulation and consolidation
      // Note: usage is null because llamadart doesn't expose token counting
      yield ChatResult<ChatMessage>(
        output: ChatMessage(
          role: ChatMessageRole.model,
          parts: [TextPart(token)],
        ),
        messages: [
          ChatMessage(
            role: ChatMessageRole.model,
            parts: [TextPart(token)],
          ),
        ],
        finishReason: FinishReason.unspecified,
        usage: null, // llamadart API doesn't provide token counts
      );
    }

    // Final chunk with stop reason
    _logger.info('Llamadart stream completed after $chunkCount chunks');
    yield ChatResult<ChatMessage>(
      output: ChatMessage(role: ChatMessageRole.model, parts: const []),
      messages: const [],
      finishReason: FinishReason.stop,
      usage: null, // llamadart API doesn't provide token counts
    );
  }

  @override
  void dispose() {
    _logger.info('Disposing Llamadart model and engine');
    _engine.dispose();
  }
}
