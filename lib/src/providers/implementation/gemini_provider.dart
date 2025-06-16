import '../../models/implementations/gemini_model.dart' show GeminiModel;
import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import '../../platform/platform.dart' as platform;
import '../interface/provider.dart';

/// Provider for Google's Gemini AI models.
///
/// This provider creates instances of [GeminiModel] using the specified
/// model name and API key.
class GeminiProvider extends Provider {
  /// Creates a new [GeminiProvider] with the given parameters.
  ///
  /// The [modelName] is the name of the Gemini model to use.
  /// If not provided, [defaultModelName] is used.
  /// The [embeddingModelName] is the name of the Gemini embedding model to use.
  /// If not provided, [defaultEmbeddingModelName] is used.
  /// The [apiKey] is the API key to use for authentication.
  /// If not provided, it's retrieved from the environment.
  GeminiProvider({
    String? modelName,
    String? embeddingModelName,
    String? apiKey,
  }) : modelName = modelName ?? defaultModelName,
       embeddingModelName = embeddingModelName ?? defaultEmbeddingModelName,
       apiKey = apiKey ?? platform.getEnv(apiKeyName);

  /// The default model name to use if none is provided.
  static const defaultModelName = 'gemini-2.0-flash';

  /// The default embedding model name to use if none is provided.
  static const defaultEmbeddingModelName = 'text-embedding-004';

  /// The name of the environment variable that contains the API key.
  static const apiKeyName = 'GEMINI_API_KEY';

  /// The display name for this provider, in the format "google:modelName".
  @override
  String get displayName => 'google:$modelName';

  /// The name of the Gemini model to use.
  final String modelName;

  /// The name of the Gemini embedding model to use.
  final String embeddingModelName;

  /// The API key to use for authentication with the Gemini API.
  final String apiKey;

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
  );
}
