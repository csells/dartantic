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
  /// If not provided, [defaultModelName] is used.
  /// The [embeddingModelName] is the name of the OpenAI embedding model to use.
  /// If not provided, [defaultEmbeddingModelName] is used.
  /// The [apiKey] is the API key to use for authentication.
  /// If not provided, it's retrieved from the environment.
  OpenAiProvider({
    this.alias,
    String? modelName,
    String? embeddingModelName,
    String? apiKey,
    this.baseUrl,
    this.temperature,
    this.caps = ProviderCaps.all,
  }) : modelName = modelName ?? defaultModelName,
       embeddingModelName = embeddingModelName ?? defaultEmbeddingModelName,
       apiKey = apiKey ?? platform.getEnv(apiKeyName);

  /// The default model name to use if none is provided.
  static const defaultModelName = 'gpt-4o';

  /// The default embedding model name to use if none is provided.
  static const defaultEmbeddingModelName = 'text-embedding-3-small';

  /// The name of the environment variable that contains the API key.
  static const apiKeyName = 'OPENAI_API_KEY';

  @override
  final String displayName = 'openai';

  @override
  final String? alias;

  /// The name of the OpenAI model to use.
  final String modelName;

  /// The name of the OpenAI embedding model to use.
  final String embeddingModelName;

  /// The API key to use for authentication with the OpenAI API.
  final String apiKey;

  /// The base URL for the OpenAI API.
  final Uri? baseUrl;

  /// The temperature to use for the OpenAI API.
  final double? temperature;

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
    baseUrl: baseUrl,
    temperature: temperature,
    caps: caps,
  );

  @override
  final Iterable<ProviderCaps> caps;
}
