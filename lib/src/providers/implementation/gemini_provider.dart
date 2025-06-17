import '../../models/implementations/gemini_model.dart' show GeminiModel;
import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import '../../platform/platform.dart' as platform;
import '../interface/provider.dart';
import '../interface/provider_caps.dart';

/// Provider for Google's Gemini AI models.
///
/// This provider creates instances of [GeminiModel] using the specified
/// model name and API key.
class GeminiProvider extends Provider {
  /// Creates a new [GeminiProvider] with the given parameters.
  ///
  /// The [modelName] is the name of the Gemini model to use.
  /// If not provided, [GeminiModel.defaultModelName] is used.
  /// The [embeddingModelName] is the name of the Gemini embedding model to use.
  /// If not provided, [GeminiModel.defaultEmbeddingModelName] is used.
  /// The [apiKey] is the API key to use for authentication.
  /// If not provided, it's retrieved from the environment.
  GeminiProvider({
    this.alias,
    this.modelName,
    this.embeddingModelName,
    String? apiKey,
    this.temperature,
  }) : apiKey = apiKey ?? platform.getEnv(apiKeyName);

  /// The name of the environment variable that contains the API key.
  static const apiKeyName = 'GEMINI_API_KEY';

  @override
  String get name => 'google';

  @override
  final String? alias;

  /// The name of the Gemini model to use.
  final String? modelName;

  /// The name of the Gemini embedding model to use.
  final String? embeddingModelName;

  /// The API key to use for authentication with the Gemini API.
  final String apiKey;

  /// The temperature to use for the Gemini API.
  final double? temperature;

  /// Creates a [Model] instance using this provider's configuration.
  ///
  /// The [settings] parameter contains additional configuration options
  /// for the model, such as the system prompt and output type.
  @override
  Model createModel(ModelSettings settings) => GeminiModel(
    modelName: modelName,
    embeddingModelName: embeddingModelName,
    apiKey: apiKey,
    outputSchema: settings.outputSchema,
    systemPrompt: settings.systemPrompt,
    tools: settings.tools,
    temperature: temperature,
  );

  @override
  final caps = ProviderCaps.all;
}
