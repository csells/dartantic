import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import 'firebase_ai_chat_model.dart';
import 'firebase_ai_chat_options.dart';
import 'firebase_ai_embeddings_model.dart';
import 'firebase_ai_embeddings_options.dart';
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
          FirebaseAIEmbeddingsModelOptions,
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
  FirebaseAIProvider({
    this.backend = FirebaseAIBackend.googleAI,
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
           ModelKind.media: 'gemini-2.5-flash-image',
         },
         aliases: backend == FirebaseAIBackend.googleAI
             ? const ['firebase-google']
             : const ['firebase-vertex'],
       );

  static final Logger _logger = Logger('dartantic.chat.providers.firebase_ai');

  /// The backend type this provider instance uses.
  final FirebaseAIBackend backend;

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
      enableThinking: enableThinking,
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
        enableThinking: options?.enableThinking,
        thinkingBudgetTokens: options?.thinkingBudgetTokens,
      ),
    );
  }

  @override
  EmbeddingsModel<FirebaseAIEmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    FirebaseAIEmbeddingsModelOptions? options,
  }) {
    final modelName = name ?? 'text-embedding-004';

    _logger.info('Creating Firebase AI embeddings model: $modelName');

    return FirebaseAIEmbeddingsModel(
      name: modelName,
      dimensions: options?.dimensions,
      batchSize: options?.batchSize,
      options: options,
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
      tools: tools,
      defaultOptions: options,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    yield ModelInfo(
      name: 'gemini-2.5-flash',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 2.5 Flash',
      description: 'Fast and versatile next-generation model',
    );
    yield ModelInfo(
      name: 'gemini-2.0-flash',
      providerName: name,
      kinds: {ModelKind.chat},
      displayName: 'Gemini 2.0 Flash',
      description:
          'Fast and versatile performance across a diverse variety of tasks',
    );
    yield ModelInfo(
      name: 'gemini-2.5-flash-image',
      providerName: name,
      kinds: {ModelKind.media},
      displayName: 'Gemini 2.5 Flash Image',
      description: 'Image generation via Gemini multimodal model',
    );
  }
}
