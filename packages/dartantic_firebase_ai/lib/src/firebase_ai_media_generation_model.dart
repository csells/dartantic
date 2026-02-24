import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:logging/logging.dart';

import 'firebase_ai_media_generation_options.dart';
import 'firebase_ai_provider.dart';
import 'firebase_ai_safety_options.dart';
import 'firebase_message_mappers.dart';

/// Media generation model for Firebase AI.
///
/// This model supports both:
/// - Imagen generation via [FirebaseAIImagenMediaGenerationModelOptions]
/// - Gemini generation via [FirebaseAIGeminiMediaGenerationModelOptions]
class FirebaseAIMediaGenerationModel
    extends MediaGenerationModel<FirebaseAIMediaGenerationModelOptions> {
  /// Creates a Firebase AI media generation model.
  FirebaseAIMediaGenerationModel({
    required super.name,
    required FirebaseAIBackend backend,
    FirebaseAIMediaGenerationModelOptions? defaultOptions,
    super.tools,
  }) : _backend = backend,
       _firebaseAI = switch (backend) {
         FirebaseAIBackend.googleAI => fai.FirebaseAI.googleAI(),
         FirebaseAIBackend.vertexAI => fai.FirebaseAI.vertexAI(),
       },
       super(
         defaultOptions:
             defaultOptions ??
             const FirebaseAIImagenMediaGenerationModelOptions(),
       );

  static final Logger _logger = Logger('dartantic.media.firebase_ai');

  static const _supportedImageMimeTypes = <String>{'image/png', 'image/jpeg'};

  final FirebaseAIBackend _backend;
  final fai.FirebaseAI _firebaseAI;

  @override
  Stream<MediaGenerationResult> generateMediaStream(
    String prompt, {
    required List<String> mimeTypes,
    List<ChatMessage> history = const [],
    List<Part> attachments = const [],
    FirebaseAIMediaGenerationModelOptions? options,
    Schema? outputSchema,
  }) async* {
    if (outputSchema != null) {
      throw UnsupportedError(
        'Firebase AI media generation does not support output schemas.',
      );
    }

    if (tools != null && tools!.isNotEmpty) {
      throw UnsupportedError(
        'Firebase AI media generation does not support tools.',
      );
    }

    final resolvedOptions = options ?? defaultOptions;
    final resolvedMimeType = _resolveMimeType(
      mimeTypes,
      switch (resolvedOptions) {
        FirebaseAIImagenMediaGenerationModelOptions(:final responseMimeType) =>
          responseMimeType,
        FirebaseAIGeminiMediaGenerationModelOptions(:final responseMimeType) =>
          responseMimeType,
      },
    );

    switch (resolvedOptions) {
      case FirebaseAIImagenMediaGenerationModelOptions():
        yield* _generateViaImagen(
          prompt,
          resolvedMimeType: resolvedMimeType,
          mimeTypes: mimeTypes,
          history: history,
          attachments: attachments,
          options: resolvedOptions,
        );
      case FirebaseAIGeminiMediaGenerationModelOptions():
        yield* _generateViaGemini(
          prompt,
          resolvedMimeType: resolvedMimeType,
          mimeTypes: mimeTypes,
          history: history,
          attachments: attachments,
          options: resolvedOptions,
        );
    }
  }

  Stream<MediaGenerationResult> _generateViaImagen(
    String prompt, {
    required String resolvedMimeType,
    required List<String> mimeTypes,
    required List<ChatMessage> history,
    required List<Part> attachments,
    required FirebaseAIImagenMediaGenerationModelOptions options,
  }) async* {
    final imagen = _firebaseAI.imagenModel(
      model: name,
      generationConfig: _buildImagenGenerationConfig(options),
      safetySettings: _buildImagenSafetySettings(options.safetySettings),
    );

    final response = await imagen.generateImages(prompt);
    final assets = <DataPart>[];
    for (var i = 0; i < response.images.length; i++) {
      final image = response.images[i];
      assets.add(
        DataPart(
          image.bytesBase64Encoded,
          mimeType: image.mimeType,
          name: _suggestName(image.mimeType, assetsIndex: i),
        ),
      );
    }

    _logger.info(
      'Firebase AI Imagen generated ${assets.length} image(s) '
      'for model "$name" (${_backend.name}).',
    );

    yield MediaGenerationResult(
      assets: assets,
      finishReason: FinishReason.stop,
      isComplete: true,
      metadata: {
        'provider': 'firebase_ai',
        'backend': _backend.name,
        'engine': 'imagen',
        'model': name,
        'requested_mime_types': mimeTypes,
        'resolved_mime_type': resolvedMimeType,
        'history_messages': history.length,
        'attachment_count': attachments.length,
        if (response.filteredReason != null)
          'filtered_reason': response.filteredReason,
      },
    );
  }

  Stream<MediaGenerationResult> _generateViaGemini(
    String prompt, {
    required String resolvedMimeType,
    required List<String> mimeTypes,
    required List<ChatMessage> history,
    required List<Part> attachments,
    required FirebaseAIGeminiMediaGenerationModelOptions options,
  }) async* {
    final model = _firebaseAI.generativeModel(
      model: name,
      safetySettings: options.safetySettings?.toSafetySettings(),
      generationConfig: fai.GenerationConfig(
        temperature: options.temperature,
        maxOutputTokens: options.maxOutputTokens,
        candidateCount: options.imageSampleCount,
        responseMimeType: options.responseMimeType,
        responseModalities: const [fai.ResponseModalities.image],
      ),
    );

    final requestMessages = <ChatMessage>[
      ...history,
      ChatMessage.user(prompt, parts: attachments),
    ];
    final response = await model.generateContent(
      requestMessages.toContentList(),
    );
    final candidate = response.candidates.firstOrNull;
    if (candidate == null) {
      yield MediaGenerationResult(
        assets: const [],
        messages: const [],
        finishReason: FinishReason.unspecified,
        isComplete: true,
        metadata: {
          'provider': 'firebase_ai',
          'backend': _backend.name,
          'engine': 'gemini',
          'model': name,
          'requested_mime_types': mimeTypes,
          'resolved_mime_type': resolvedMimeType,
          'block_reason': response.promptFeedback?.blockReason?.name,
          'block_reason_message': response.promptFeedback?.blockReasonMessage,
        },
      );
      return;
    }

    final assets = <DataPart>[];
    final links = <LinkPart>[];
    final textParts = <TextPart>[];

    for (var i = 0; i < candidate.content.parts.length; i++) {
      final part = candidate.content.parts[i];
      switch (part) {
        case fai.InlineDataPart(:final mimeType, :final bytes):
          assets.add(
            DataPart(
              bytes,
              mimeType: mimeType,
              name: _suggestName(mimeType, assetsIndex: i),
            ),
          );
        case fai.FileData(:final mimeType, :final fileUri):
          final uri = Uri.tryParse(fileUri);
          if (uri != null) {
            links.add(
              LinkPart(
                uri,
                mimeType: mimeType,
                name: uri.pathSegments.isNotEmpty
                    ? uri.pathSegments.last
                    : null,
              ),
            );
          }
        case fai.TextPart(:final text):
          if (text.isNotEmpty) textParts.add(TextPart(text));
        default:
          break;
      }
    }

    _logger.info(
      'Firebase AI Gemini generated ${assets.length} image(s) and '
      '${links.length} link(s) for model "$name" (${_backend.name}).',
    );

    yield MediaGenerationResult(
      assets: assets,
      links: links,
      messages: textParts.isEmpty
          ? const []
          : [
              ChatMessage(
                role: ChatMessageRole.model,
                parts: List<Part>.from(textParts),
              ),
            ],
      finishReason: mapFinishReason(candidate.finishReason),
      isComplete: true,
      usage: LanguageModelUsage(
        promptTokens: response.usageMetadata?.promptTokenCount,
        responseTokens: response.usageMetadata?.candidatesTokenCount,
        totalTokens: response.usageMetadata?.totalTokenCount,
      ),
      metadata: {
        'provider': 'firebase_ai',
        'backend': _backend.name,
        'engine': 'gemini',
        'model': name,
        'requested_mime_types': mimeTypes,
        'resolved_mime_type': resolvedMimeType,
        'history_messages': history.length,
        'attachment_count': attachments.length,
        'finish_message': candidate.finishMessage,
        'block_reason': response.promptFeedback?.blockReason?.name,
        'block_reason_message': response.promptFeedback?.blockReasonMessage,
      },
    );
  }

  fai.ImagenGenerationConfig _buildImagenGenerationConfig(
    FirebaseAIImagenMediaGenerationModelOptions options,
  ) => fai.ImagenGenerationConfig(
    numberOfImages: options.imageSampleCount,
    aspectRatio: _mapAspectRatio(options.aspectRatio),
    imageFormat: _mapImageFormat(options.responseMimeType),
  );

  fai.ImagenSafetySettings? _buildImagenSafetySettings(
    FirebaseAIImagenSafetySettings? settings,
  ) {
    if (settings == null) return null;
    return fai.ImagenSafetySettings(
      _mapImagenSafetyFilterLevel(settings.safetyFilterLevel),
      _mapImagenPersonFilterLevel(settings.personFilterLevel),
    );
  }

  fai.ImagenSafetyFilterLevel? _mapImagenSafetyFilterLevel(
    FirebaseAIImagenSafetyFilterLevel? level,
  ) => switch (level) {
    null => null,
    FirebaseAIImagenSafetyFilterLevel.blockLowAndAbove =>
      fai.ImagenSafetyFilterLevel.blockLowAndAbove,
    FirebaseAIImagenSafetyFilterLevel.blockMediumAndAbove =>
      fai.ImagenSafetyFilterLevel.blockMediumAndAbove,
    FirebaseAIImagenSafetyFilterLevel.blockOnlyHigh =>
      fai.ImagenSafetyFilterLevel.blockOnlyHigh,
    FirebaseAIImagenSafetyFilterLevel.blockNone =>
      fai.ImagenSafetyFilterLevel.blockNone,
  };

  fai.ImagenPersonFilterLevel? _mapImagenPersonFilterLevel(
    FirebaseAIImagenPersonFilterLevel? level,
  ) => switch (level) {
    null => null,
    FirebaseAIImagenPersonFilterLevel.blockAll =>
      fai.ImagenPersonFilterLevel.blockAll,
    FirebaseAIImagenPersonFilterLevel.allowAdult =>
      fai.ImagenPersonFilterLevel.allowAdult,
    FirebaseAIImagenPersonFilterLevel.allowAll =>
      fai.ImagenPersonFilterLevel.allowAll,
  };

  fai.ImagenAspectRatio? _mapAspectRatio(String? value) => switch (value) {
    null => null,
    '1:1' => fai.ImagenAspectRatio.square1x1,
    '9:16' => fai.ImagenAspectRatio.portrait9x16,
    '16:9' => fai.ImagenAspectRatio.landscape16x9,
    '3:4' => fai.ImagenAspectRatio.portrait3x4,
    '4:3' => fai.ImagenAspectRatio.landscape4x3,
    _ => throw UnsupportedError(
      'Unsupported Firebase AI aspect ratio "$value". '
      'Allowed: 1:1, 9:16, 16:9, 3:4, 4:3.',
    ),
  };

  fai.ImagenFormat? _mapImageFormat(String? mimeType) => switch (mimeType) {
    null => null,
    'image/png' => fai.ImagenFormat.png(),
    'image/jpeg' => fai.ImagenFormat.jpeg(),
    _ => throw UnsupportedError(
      'Unsupported Firebase AI response MIME type "$mimeType". '
      'Supported values: image/png, image/jpeg.',
    ),
  };

  String _resolveMimeType(List<String> requested, String? overrideMimeType) {
    if (overrideMimeType != null &&
        _supportedImageMimeTypes.contains(overrideMimeType)) {
      return overrideMimeType;
    }

    for (final mimeType in requested) {
      if (mimeType == 'image/*') return 'image/png';
      if (_supportedImageMimeTypes.contains(mimeType)) return mimeType;
    }

    if (overrideMimeType != null) {
      throw UnsupportedError(
        'Firebase AI media generation does not support MIME type '
        '"$overrideMimeType". Supported values: '
        '${_supportedImageMimeTypes.join(', ')}.',
      );
    }

    throw UnsupportedError(
      'Firebase AI media generation supports only '
      '${_supportedImageMimeTypes.join(', ')}. '
      'Requested: ${requested.join(', ')}',
    );
  }

  String _suggestName(String mimeType, {required int assetsIndex}) {
    final extension = PartHelpers.extensionFromMimeType(mimeType);
    final suffix = extension == null ? '' : '.$extension';
    return 'image_$assetsIndex$suffix';
  }

  @override
  void dispose() {}
}
