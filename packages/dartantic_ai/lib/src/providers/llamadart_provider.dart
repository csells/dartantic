import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import '../chat_models/llamadart_chat/llamadart_chat_model.dart';
import '../chat_models/llamadart_chat/llamadart_chat_options.dart';
import '../chat_models/llamadart_chat/model_resolvers.dart';
import '../platform/platform.dart';

/// Provider for Llamadart (local llama.cpp models)
class LlamadartProvider extends Provider<
    LlamadartChatOptions,
    EmbeddingsModelOptions,
    MediaGenerationModelOptions> {
  /// Creates a [LlamadartProvider]
  LlamadartProvider({
    super.baseUrl,
    super.headers,
    LlamadartChatOptions? defaultChatOptions,
  })  : _defaultChatOptions = defaultChatOptions ?? _createDefaultChatOptions(),
        super(
          apiKey: null,
          apiKeyName: null,
          name: 'llamadart',
          displayName: 'Llamadart',
          aliases: const ['llama'],
          defaultModelNames: const {
            ModelKind.chat: 'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
          },
        );

  static final Logger _logger = Logger('dartantic.chat.providers.llamadart');

  /// Default base URL (placeholder for local provider)
  static final defaultBaseUrl = Uri.parse('local://llamadart');

  final LlamadartChatOptions _defaultChatOptions;

  static LlamadartChatOptions _createDefaultChatOptions() {
    // Use LLAMADART_MODELS_PATH for both file resolution and HF caching
    final modelsPath = tryGetEnv('LLAMADART_MODELS_PATH');
    return LlamadartChatOptions(
      resolver: FallbackResolver(
        fileBasePath: modelsPath,
        hfCacheDir: modelsPath ?? './hg-model-cache',
      ),
    );
  }

  @override
  ChatModel<LlamadartChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    LlamadartChatOptions? options,
  }) {
    // Check unsupported features
    if (tools != null && tools.isNotEmpty) {
      throw UnsupportedError(
        'Tool calling is not supported by the $displayName provider. '
        'Llamadart uses llama.cpp which does not natively support '
        'function calling.',
      );
    }

    if (enableThinking) {
      throw UnsupportedError(
        'Extended thinking is not supported by $displayName. '
        'Only OpenAI Responses, Anthropic, and Google providers support '
        'thinking.',
      );
    }

    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    final resolver = options?.resolver ?? _defaultChatOptions.resolver!;

    _logger.info(
      'Creating Llamadart model: $modelName with '
      'temperature: $temperature, resolver: ${resolver.runtimeType}',
    );

    return LlamadartChatModel(
      name: modelName,
      resolver: resolver,
      temperature: temperature,
      defaultOptions: LlamadartChatOptions(
        temperature: temperature ??
            options?.temperature ??
            _defaultChatOptions.temperature,
        topP: options?.topP ?? _defaultChatOptions.topP,
        maxTokens: options?.maxTokens ?? _defaultChatOptions.maxTokens,
        resolver: resolver,
        logLevel: options?.logLevel ?? _defaultChatOptions.logLevel,
      ),
    );
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) {
    throw UnsupportedError(
      'Llamadart provider does not support embeddings models',
    );
  }

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
  }) {
    throw UnsupportedError(
      'Llamadart provider does not support media generation models',
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    final resolver = _defaultChatOptions.resolver!;
    _logger.info('Listing models using ${resolver.runtimeType}');

    try {
      await for (final model in resolver.listModels()) {
        yield model;
      }
    } on Exception catch (e) {
      _logger.warning('Error listing models: $e');
      // Yield empty stream on error
    }
  }
}
