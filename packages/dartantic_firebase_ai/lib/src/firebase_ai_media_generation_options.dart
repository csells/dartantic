import 'package:dartantic_interface/dartantic_interface.dart';

import 'firebase_ai_safety_options.dart';

/// Firebase AI-specific media generation options.
///
/// Use one of the concrete subtypes to choose the generation engine:
/// - [FirebaseAIImagenMediaGenerationModelOptions]
/// - [FirebaseAIGeminiMediaGenerationModelOptions]
sealed class FirebaseAIMediaGenerationModelOptions
    extends MediaGenerationModelOptions {
  /// Creates base Firebase AI media generation options.
  const FirebaseAIMediaGenerationModelOptions._();

  /// Creates Imagen-based media generation options.
  const factory FirebaseAIMediaGenerationModelOptions.imagen({
    String? responseMimeType,
    int? imageSampleCount,
    String? aspectRatio,
    FirebaseAIImagenSafetySettings? safetySettings,
  }) = FirebaseAIImagenMediaGenerationModelOptions;

  /// Creates Gemini-based media generation options.
  const factory FirebaseAIMediaGenerationModelOptions.gemini({
    double? temperature,
    int? maxOutputTokens,
    String? responseMimeType,
    int? imageSampleCount,
    List<FirebaseAISafetySetting>? safetySettings,
  }) = FirebaseAIGeminiMediaGenerationModelOptions;
}

/// Media options for Firebase Imagen models.
final class FirebaseAIImagenMediaGenerationModelOptions
    extends FirebaseAIMediaGenerationModelOptions {
  /// Creates Firebase Imagen media generation options.
  const FirebaseAIImagenMediaGenerationModelOptions({
    this.responseMimeType,
    this.imageSampleCount,
    this.aspectRatio,
    this.safetySettings,
  }) : super._();

  /// Explicit image MIME type to request from Imagen.
  ///
  /// Supported values are provider-specific.
  final String? responseMimeType;

  /// Number of images to generate in a single request.
  final int? imageSampleCount;

  /// Target aspect ratio (for example `1:1` or `16:9`) when supported.
  final String? aspectRatio;

  /// Optional Imagen safety settings for this request.
  final FirebaseAIImagenSafetySettings? safetySettings;
}

/// Media options for Firebase Gemini models.
final class FirebaseAIGeminiMediaGenerationModelOptions
    extends FirebaseAIMediaGenerationModelOptions {
  /// Creates Firebase Gemini media generation options.
  const FirebaseAIGeminiMediaGenerationModelOptions({
    this.temperature,
    this.maxOutputTokens,
    this.responseMimeType,
    this.imageSampleCount,
    this.safetySettings,
  }) : super._();

  /// Sampling temperature for generated content.
  final double? temperature;

  /// Maximum output token budget for text/media responses.
  final int? maxOutputTokens;

  /// Explicit MIME type to request from Gemini, if supported.
  final String? responseMimeType;

  /// Number of images/candidates to request when image generation is used.
  final int? imageSampleCount;

  /// Safety settings for Gemini media generation.
  final List<FirebaseAISafetySetting>? safetySettings;
}
