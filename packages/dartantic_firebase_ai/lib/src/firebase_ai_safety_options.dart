/// Safety setting for Firebase AI Gemini requests.
class FirebaseAISafetySetting {
  /// Creates a safety setting.
  const FirebaseAISafetySetting({
    required this.category,
    required this.threshold,
  });

  /// The category for this setting.
  final FirebaseAISafetySettingCategory category;

  /// Controls the probability threshold at which harm is blocked.
  final FirebaseAISafetySettingThreshold threshold;
}

/// Safety setting categories for Gemini requests.
enum FirebaseAISafetySettingCategory {
  /// The harm category is harassment.
  harassment,

  /// The harm category is hate speech.
  hateSpeech,

  /// The harm category is sexually explicit content.
  sexuallyExplicit,

  /// The harm category is dangerous content.
  dangerousContent,
}

/// Controls the probability threshold at which harm is blocked.
enum FirebaseAISafetySettingThreshold {
  /// Block when low, medium or high probability of unsafe content.
  blockLowAndAbove,

  /// Block when medium or high probability of unsafe content.
  blockMediumAndAbove,

  /// Block when high probability of unsafe content.
  blockOnlyHigh,

  /// Always show regardless of probability of unsafe content.
  blockNone,
}

/// Imagen safety settings for Firebase AI media generation.
class FirebaseAIImagenSafetySettings {
  /// Creates Imagen safety settings.
  const FirebaseAIImagenSafetySettings({
    this.safetyFilterLevel,
    this.personFilterLevel,
  });

  /// Controls the strictness of unsafe content filtering.
  final FirebaseAIImagenSafetyFilterLevel? safetyFilterLevel;

  /// Controls whether people are allowed in generated images.
  final FirebaseAIImagenPersonFilterLevel? personFilterLevel;
}

/// Safety filtering level for Imagen requests.
enum FirebaseAIImagenSafetyFilterLevel {
  /// Strongest filtering level.
  blockLowAndAbove,

  /// Block medium and above severity.
  blockMediumAndAbove,

  /// Block only high severity.
  blockOnlyHigh,

  /// Minimal filtering.
  blockNone,
}

/// Person generation level for Imagen requests.
enum FirebaseAIImagenPersonFilterLevel {
  /// Disallow people in generated images.
  blockAll,

  /// Allow adults only.
  allowAdult,

  /// Allow all ages.
  allowAll,
}
