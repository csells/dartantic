import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:ollama_dart/ollama_dart.dart' as o;

import '../chat_models/ollama_chat/ollama_chat_model.dart';
import '../embeddings_models/ollama_embeddings/ollama_embeddings_model.dart';
import '../embeddings_models/ollama_embeddings/ollama_embeddings_model_options.dart';

/// Provider for native Ollama API (local, not OpenAI-compatible).
class OllamaProvider
    extends
        Provider<
          OllamaChatOptions,
          OllamaEmbeddingsModelOptions,
          MediaGenerationModelOptions
        > {
  /// Creates a new Ollama provider instance.
  OllamaProvider({
    super.name = 'ollama',
    super.displayName = 'Ollama',
    super.apiKey,
    super.baseUrl,
    super.apiKeyName,
    super.headers,
  }) : super(
         defaultModelNames: {
           /// Note: llama3.x models have a known issue with spurious content in
           /// tool calling responses, generating unwanted JSON fragments like
           /// '", "parameters": {}}' during streaming. qwen2.5:7b-instruct
           /// provides cleaner tool calling behavior.
           ModelKind.chat: 'qwen2.5:7b-instruct',
           ModelKind.embeddings: 'nomic-embed-text',
         },
       );

  static final Logger _logger = Logger('dartantic.chat.providers.ollama');

  /// The default base URL to use unless another is specified.
  static final defaultBaseUrl = Uri.parse('http://localhost:11434');

  @override
  ChatModel<OllamaChatOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    OllamaChatOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;
    _logger.info(
      'Creating Ollama model: $modelName with ${tools?.length ?? 0} tools, '
      'temp: $temperature, thinking: $enableThinking',
    );

    return OllamaChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      baseUrl: baseUrl,
      headers: headers,
      enableThinking: enableThinking,
      defaultOptions: OllamaChatOptions(
        format: options?.format,
        keepAlive: options?.keepAlive,
        numKeep: options?.numKeep,
        seed: options?.seed,
        numPredict: options?.numPredict,
        topK: options?.topK,
        topP: options?.topP,
        minP: options?.minP,
        tfsZ: options?.tfsZ,
        typicalP: options?.typicalP,
        repeatLastN: options?.repeatLastN,
        repeatPenalty: options?.repeatPenalty,
        presencePenalty: options?.presencePenalty,
        frequencyPenalty: options?.frequencyPenalty,
        mirostat: options?.mirostat,
        mirostatTau: options?.mirostatTau,
        mirostatEta: options?.mirostatEta,
        penalizeNewline: options?.penalizeNewline,
        stop: options?.stop,
        numa: options?.numa,
        numCtx: options?.numCtx,
        numBatch: options?.numBatch,
        numGpu: options?.numGpu,
        mainGpu: options?.mainGpu,
        lowVram: options?.lowVram,
        f16KV: options?.f16KV,
        logitsAll: options?.logitsAll,
        vocabOnly: options?.vocabOnly,
        useMmap: options?.useMmap,
        useMlock: options?.useMlock,
        numThread: options?.numThread,
        logprobs: options?.logprobs,
        topLogprobs: options?.topLogprobs,
      ),
    );
  }

  @override
  EmbeddingsModel<OllamaEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    OllamaEmbeddingsModelOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.embeddings]!;
    _logger.info('Creating Ollama embeddings model: $modelName');

    return OllamaEmbeddingsModel(
      name: modelName,
      baseUrl: baseUrl,
      headers: headers,
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      options: options,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    _logger.info('Fetching models from Ollama API using SDK');
    final resolvedBaseUrl = baseUrl ?? defaultBaseUrl;
    final client = o.OllamaClient(
      config: o.OllamaConfig(
        baseUrl: resolvedBaseUrl.toString(),
        defaultHeaders: headers,
      ),
    );

    try {
      final response = await client.models.list();
      final models = response.models ?? [];
      _logger.info('Successfully fetched ${models.length} models from Ollama');

      for (final m in models) {
        final modelName = m.name ?? '';
        yield ModelInfo(
          name: modelName,
          providerName: name,
          kinds: {ModelKind.chat},
          displayName: modelName,
          description: null,
          extra: {
            if (m.modifiedAt != null) 'modifiedAt': m.modifiedAt,
            if (m.size != null) 'size': m.size,
            if (m.digest != null) 'digest': m.digest,
          },
        );
      }
    } finally {
      client.close();
    }
  }

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
    List<String>? mimeTypes,
  }) {
    throw UnsupportedError('Ollama provider does not support media generation');
  }
}
