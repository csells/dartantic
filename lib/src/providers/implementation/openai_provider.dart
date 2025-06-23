import 'package:openai_dart/openai_dart.dart' as oai;

import '../../models/implementations/openai_model.dart';
import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import '../../platform/platform.dart' as platform;
import '../interface/provider.dart';
import '../interface/provider_caps.dart';

/// Provider for OpenAI models.
///
/// This provider creates instances of [OpenAiModel] using the specified
/// model name and API key.
class OpenAiProvider extends Provider {
  /// Creates a new [OpenAiProvider] with the given parameters.
  ///
  /// The [modelName] is the name of the OpenAI model to use.
  /// If not provided, [OpenAiModel.defaultModelName] is used.
  /// The [embeddingModelName] is the name of the OpenAI embedding model to use.
  /// If not provided, [OpenAiModel.defaultEmbeddingModelName] is used.
  /// The [apiKey] is the API key to use for authentication.
  /// If not provided, it's retrieved from the environment.
  /// The [parallelToolCalls] determines whether the OpenAI API implementation
  /// supports parallel tool calls (gemini-compat does not).
  OpenAiProvider({
    this.name = 'openai',
    this.modelName,
    this.embeddingModelName,
    String? apiKey,
    this.baseUrl,
    this.caps = ProviderCaps.all,
    this.parallelToolCalls = true,
  }) : apiKey = apiKey ?? platform.getEnv(apiKeyName);

  /// The name of the environment variable that contains the API key.
  static const apiKeyName = 'OPENAI_API_KEY';

  @override
  final String name;

  /// The name of the OpenAI model to use.
  final String? modelName;

  /// The name of the OpenAI embedding model to use.
  final String? embeddingModelName;

  /// The API key to use for authentication with the OpenAI API.
  final String apiKey;

  /// The base URL for the OpenAI API.
  final Uri? baseUrl;

  /// Whether to enable parallel tool calls via the OpenAI API.
  final bool parallelToolCalls;

  /// Creates a [Model] instance using this provider's configuration.
  ///
  /// The [settings] parameter contains additional configuration options
  /// for the model, such as the system prompt and output type.
  @override
  Model createModel(ModelSettings settings) => OpenAiModel(
    modelName: modelName,
    embeddingModelName: embeddingModelName,
    apiKey: apiKey,
    outputSchema: settings.outputSchema,
    systemPrompt: settings.systemPrompt,
    tools: settings.tools,
    toolCallingMode: settings.toolCallingMode,
    baseUrl: baseUrl,
    temperature: settings.temperature,
    caps: caps,
    parallelToolCalls: parallelToolCalls,
  );

  @override
  final Set<ProviderCaps> caps;

  @override
  Future<Iterable<ModelInfo>> listModels() async {
    final client = oai.OpenAIClient(
      apiKey: apiKey,
      baseUrl: baseUrl?.toString(),
    );
    try {
      final res = await client.listModels();
      return res.data.map<ModelInfo>((m) {
        final id = m.id;

        final kind = () {
          if (id.contains('embedding')) return ModelKind.embedding;
          if (id.startsWith('dall-e') || id.contains('gpt-image')) {
            return ModelKind.image;
          }
          if (id.startsWith('whisper')) return ModelKind.audio;
          if (id.startsWith('tts-')) return ModelKind.tts;
          return ModelKind.chat; // default assumption
        }();

        return ModelInfo(
          name: id,
          providerName: name,
          kinds: {kind},
          stable: _isStable(id),
        );
      }).toList();
    } finally {
      client.endSession();
    }
  }

  static bool _isStable(String modelName) {
    final lowerName = modelName.toLowerCase();

    // Check for explicit preview/experimental markers
    final unstableMarkers = [
      'preview',
      'beta',
      'alpha',
      'experimental',
      'latest',
    ];
    for (final marker in unstableMarkers) {
      if (lowerName.contains(marker)) return false;
    }

    // Check for date patterns:
    // - MMDD format (e.g. -0914, -1106, -0125)
    // - YYYY-MM-DD format (e.g. -2024-05-13, -2025-01-31)
    final datePatterns = [
      RegExp(r'-\d{4}$'), // -MMDD at end
      RegExp(r'-\d{4}-\d{2}-\d{2}$'), // -YYYY-MM-DD at end
    ];

    for (final pattern in datePatterns) {
      if (pattern.hasMatch(modelName)) return false;
    }

    return true;
  }
}
