/// Defines capabilities providers can have.
enum ProviderCaps {
  /// Indicates that the provider supports text generation.
  textGeneration,

  /// Indicates that the provider supports embeddings.
  embeddings,

  /// Indicates that the provider supports chat capabilities.
  chat,

  /// Indicates that the provider supports file uploads.
  fileUploads;

  /// All available capabilities
  static const Iterable<ProviderCaps> all = [
    textGeneration,
    embeddings,
    chat,
    fileUploads,
  ];

  /// Returns all capabilities except those specified in [these].
  static Iterable<ProviderCaps> allExcept(Iterable<ProviderCaps> these) =>
      all.where((c) => !these.contains(c));
}
