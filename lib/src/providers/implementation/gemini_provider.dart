import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/implementations/gemini_model.dart' show GeminiModel;
import '../../models/interface/model.dart';
import '../../models/interface/model_settings.dart';
import '../../platform/platform.dart' as platform;
import '../../utils.dart';
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
    this.modelName,
    this.embeddingModelName,
    String? apiKey,
    this.temperature,
  }) : apiKey = apiKey ?? platform.getEnv(apiKeyName);

  /// The name of the environment variable that contains the API key.
  static const apiKeyName = 'GEMINI_API_KEY';

  @override
  String get name => 'google';

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
    apiKey: apiKey,
    modelName: modelName,
    embeddingModelName: embeddingModelName,
    outputSchema: settings.outputSchema,
    systemPrompt: settings.systemPrompt,
    tools: settings.tools,
    temperature: temperature,
  );

  @override
  final caps = ProviderCaps.all;

  static const _methodToKind = {
    'embedContent': ModelKind.embedding,
    'embedText': ModelKind.embedding,
    'generateImage': ModelKind.image,
    'generateContent': ModelKind.chat,
    'countTokens': ModelKind.countTokens,
    'countTextTokens': ModelKind.countTokens,
  };

  @override
  Future<Iterable<ModelInfo>> listModels() async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models',
      {'key': apiKey},
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Gemini list failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final allModels = <ModelInfo>[];

    for (final model in body['models'] as List<dynamic>) {
      final modelName =
      // ignore: avoid_dynamic_calls
      (model['name'] as String).replaceFirst('models/', '');

      final methods =
          // ignore: avoid_dynamic_calls
          model['supportedGenerationMethods'] as List<dynamic>;
      final remainingMethods = methods.map((m) => m.toString().trim()).toList();

      final kinds = {
        for (final entry in _methodToKind.entries)
          if (remainingMethods.remove(entry.key)) entry.value,
      };

      if (remainingMethods.isNotEmpty) {
        log.finer('Other kind(s): [$modelName] $remainingMethods');
        kinds.add(ModelKind.other);
      }

      allModels.add(
        ModelInfo(
          name: modelName,
          providerName: name,
          kinds: kinds,
          stable: _isStable(modelName),
        ),
      );
    }

    return allModels;
  }

  static bool _isStable(String modelName) {
    final lowerName = modelName.toLowerCase();

    // Check for explicit preview/experimental markers
    final unstableMarkers = ['preview', 'experimental', 'exp', 'latest'];
    for (final marker in unstableMarkers) {
      if (lowerName.contains(marker)) return false;
    }

    // Check for date patterns (MM-DD format at end)
    final datePattern = RegExp(r'-\d{2}-\d{2}$');
    if (datePattern.hasMatch(modelName)) return false;

    // Check for version number suffixes on gemini models only
    // (e.g. gemini-1.5-flash-002, but NOT embedding-001)
    if (lowerName.startsWith('gemini-')) {
      final versionPattern = RegExp(r'-\d{3}$');
      if (versionPattern.hasMatch(modelName)) return false;
    }

    // Check for variant suffixes
    final variantPatterns = [
      RegExp(r'-\d+b$'), // -8b, -16b, etc. (size variants)
      RegExp(r'-lite-\d{3}$'), // -lite-001, etc. (lite with version)
    ];
    for (final pattern in variantPatterns) {
      if (pattern.hasMatch(modelName)) return false;
    }

    return true;
  }
}
