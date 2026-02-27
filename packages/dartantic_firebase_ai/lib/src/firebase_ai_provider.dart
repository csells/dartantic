import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:logging/logging.dart';

import 'firebase_ai_chat_model.dart';
import 'firebase_ai_chat_options.dart';
import 'firebase_ai_media_generation_model.dart';
import 'firebase_ai_media_generation_options.dart';

/// Backend type for Firebase AI provider.
enum FirebaseAIBackend {
  /// Direct Google AI API - simpler setup, good for development/testing.
  googleAI,

  /// Vertex AI through Firebase - production-ready with Firebase features.
  vertexAI,
}

/// Provider for Firebase AI (Gemini via Firebase).
///
/// Firebase AI provides access to Google's Gemini models through Firebase,
/// supporting both GoogleAI (direct API) and VertexAI (through Firebase)
/// backends for flexible development and production deployment.
class FirebaseAIProvider
    extends
        Provider<
          FirebaseAIChatModelOptions,
          EmbeddingsModelOptions,
          FirebaseAIMediaGenerationModelOptions
        > {
  /// Creates a new Firebase AI provider instance.
  ///
  /// [backend] determines which Firebase AI backend to use:
  /// - [FirebaseAIBackend.googleAI]: Direct Google AI API (simpler setup)
  /// - [FirebaseAIBackend.vertexAI]: Vertex AI through Firebase (production)
  ///
  /// Note: Firebase AI doesn't use traditional API keys. Authentication is
  /// handled through Firebase configuration and App Check.
  ///
  /// Pass [appCheck] to enable Firebase App Check verification for all
  /// requests. When provided, App Check tokens are automatically attached
  /// to every API call. Set [useLimitedUseAppCheckTokens] to `true` to use
  /// limited-use tokens for replay protection.
  FirebaseAIProvider({
    required this.backend,
    this.appCheck,
    this.useLimitedUseAppCheckTokens,
    super.headers,
  }) : super(
        apiKey: null,
        apiKeyName: null,
        name: 'firebase_ai',
        displayName: backend == FirebaseAIBackend.googleAI
            ? 'Firebase AI (Google AI)'
            : 'Firebase AI (Vertex AI)',
        defaultModelNames: const {
          ModelKind.chat: 'gemini-2.5-flash',
          ModelKind.media: 'imagen-4.0-generate-001',
        },
        aliases: backend == FirebaseAIBackend.googleAI
            ? const ['firebase-google']
            : const ['firebase-vertex'],
      );

  static final Logger _logger = Logger('dartantic.chat.providers.firebase_ai');

  /// The backend type this provider instance uses.
  final FirebaseAIBackend backend;

  /// Optional Firebase App Check instance for request verification.
  ///
  /// When provided, App Check tokens are automatically attached to every
  /// API call made by models created from this provider.
  final FirebaseAppCheck? appCheck;

  /// Whether to use limited-use App Check tokens for replay protection.
  ///
  /// When `true`, each request uses a single-use token via
  /// [FirebaseAppCheck.getLimitedUseToken]. When `false` or `null`,
  /// standard tokens via [FirebaseAppCheck.getToken] are used.
  final bool? useLimitedUseAppCheckTokens;

  @override
  ChatModel<FirebaseAIChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    FirebaseAIChatModelOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    if (temperature != null && (temperature < 0.0 || temperature > 2.0)) {
      throw ArgumentError(
        'Temperature must be between 0.0 and 2.0, got: $temperature',
      );
    }

    _logger.info(
      'Creating Firebase AI model: $modelName (${backend.name}) with '
      '${tools?.length ?? 0} tools, '
      'temp: $temperature, '
      'thinking: $enableThinking',
    );

    return FirebaseAIChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      backend: backend,
      appCheck: appCheck,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens,
      defaultOptions: FirebaseAIChatModelOptions(
        topP: options?.topP,
        topK: options?.topK,
        candidateCount: options?.candidateCount,
        maxOutputTokens: options?.maxOutputTokens,
        temperature: temperature ?? options?.temperature,
        stopSequences: options?.stopSequences,
        responseMimeType: options?.responseMimeType,
        responseSchema: options?.responseSchema,
        safetySettings: options?.safetySettings,
        enableCodeExecution: options?.enableCodeExecution,
        enableThinking: enableThinking || (options?.enableThinking ?? false),
        thinkingBudgetTokens: options?.thinkingBudgetTokens,
      ),
    );
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) {
    throw UnsupportedError(
      'Firebase AI does not support embeddings. '
      'Use a different provider for embeddings.',
    );
  }

  @override
  MediaGenerationModel<FirebaseAIMediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    FirebaseAIMediaGenerationModelOptions? options,
  }) {
    final modelName = name ?? defaultModelNames[ModelKind.media]!;

    _logger.info(
      'Creating Firebase AI media model: $modelName '
      'with ${(tools ?? const []).length} tools',
    );

    return FirebaseAIMediaGenerationModel(
      name: modelName,
      backend: backend,
      appCheck: appCheck,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens,
      tools: tools,
      defaultOptions: options,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // General Use Models
    yield ModelInfo(
      name: 'gemini-3.1-pro-preview',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 3.1 Pro',
      description:
          'Our best model for multimodal understanding, and our most '
          'powerful agentic and vibe-coding model yet, delivering richer '
          'visuals and deeper interactivity, all built on a foundation of '
          'state-of-the-art reasoning. (billing required)',
    );
    yield ModelInfo(
      name: 'gemini-3-flash-preview',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 3.0 Flash',
      description:
          'Our most intelligent model built for speed, efficiency, '
          'and cost. It enables everyday tasks with improved reasoning, while '
          'still able to tackle the most complex agentic workflows. '
          '(billing not required)',
    );
    yield ModelInfo(
      name: 'gemini-2.5-pro',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 2.5 Pro',
      description:
          'Our state-of-the-art thinking model, capable of reasoning '
          'over complex problems in code, math, and STEM, as well as analyzing '
          'large datasets, codebases, and documents using long context. '
          '(billing not required)',
    );
    yield ModelInfo(
      name: 'gemini-2.5-flash',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 2.5 Flash',
      description:
          'Our best model in terms of price-performance, offering '
          'well-rounded capabilities. 2.5 Flash is best for large scale '
          'processing, low-latency, high volume tasks that require thinking, '
          'and agentic use cases. (billing not required)',
    );
    yield ModelInfo(
      name: 'gemini-2.5-flash-lite',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 2.5 Flash Lite',
      description:
          'Our fastest flash model optimized for cost-efficiency and '
          'high throughput. (billing not required)',
    );

    // Image Generation Models
    yield ModelInfo(
      name: 'gemini-3-pro-image-preview',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Gemini 3 Pro Image (aka nano banana pro)',
      description:
          'Designed for professional asset production and complex '
          'instructions. It features real-world grounding using Google Search, '
          'a default "Thinking" process that refines composition prior to '
          'generation, and can generate images of up to 4K resolution. '
          '(billing required)',
    );
    yield ModelInfo(
      name: 'gemini-2.5-flash-image',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Gemini 2.5 Flash Image (aka nano banana)',
      description:
          "Designed for speed and efficiency. It's optimized for high-volume, "
          'low-latency tasks and generates images at 1024px resolution. '
          '(billing not required)',
    );
    yield ModelInfo(
      name: 'imagen-4.0-generate-001',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Imagen 4.0',
      description:
          'Generates realistic, high-quality images from natural language text '
          'prompts. (billing required)',
    );
    yield ModelInfo(
      name: 'imagen-4.0-fast-generate-001',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Imagen 4.0 Fast',
      description:
          'Generates images for prototyping or low-latency use cases. '
          '(billing required)',
    );
    yield ModelInfo(
      name: 'imagen-4.0-ultra-generate-001',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Imagen 4.0 Ultra',
      description:
          'Generates realistic, high-quality images from natural language text '
          'prompts. (billing required)',
    );
  }
}
