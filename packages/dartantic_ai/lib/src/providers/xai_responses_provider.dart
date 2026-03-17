import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';

import '../chat_models/xai_responses/xai_responses_chat_model.dart';
import '../chat_models/xai_responses/xai_responses_chat_options.dart';
import '../media_gen_models/xai_responses/xai_responses_media_gen_model.dart';
import '../media_gen_models/xai_responses/xai_responses_media_gen_model_options.dart';
import '../platform/platform.dart';
import '../shared/openai_utils.dart';

/// Provider for xAI Grok via the Responses API.
class XAIResponsesProvider
    extends
        Provider<
          XAIResponsesChatModelOptions,
          EmbeddingsModelOptions,
          XAIResponsesMediaGenerationModelOptions
        > {
  /// Creates a new xAI Responses provider instance.
  XAIResponsesProvider({String? apiKey, super.baseUrl, super.headers})
    : super(
        name: providerName,
        displayName: providerDisplayName,
        defaultModelNames: const {
          ModelKind.chat: defaultChatModel,
          ModelKind.media: defaultMediaModel,
        },
        apiKey: apiKey ?? tryGetEnv(defaultApiKeyName),
        apiKeyName: defaultApiKeyName,
        aliases: const ['grok-responses'],
      );

  static final Logger _logger = Logger(
    'dartantic.chat.providers.xai_responses',
  );

  /// Canonical provider name.
  static const providerName = 'xai-responses';

  /// Human-friendly provider name.
  static const providerDisplayName = 'xAI Responses';

  /// Default chat model identifier.
  static const defaultChatModel = 'grok-4-1-fast-non-reasoning';

  /// Default media generation model identifier.
  static const defaultMediaModel = 'grok-imagine-image';

  /// Environment variable used to read the API key.
  static const defaultApiKeyName = 'XAI_API_KEY';

  /// Default base URL for the xAI API.
  static final defaultBaseUrl = Uri.parse('https://api.x.ai/v1');

  @override
  Stream<ModelInfo> listModels() async* {
    _validateApiKeyPresence();
    yield* OpenAIUtils.listOpenAIModels(
      baseUrl: baseUrl ?? defaultBaseUrl,
      providerName: name,
      logger: _logger,
      apiKey: apiKey,
      headers: headers,
    );
  }

  @override
  ChatModel<XAIResponsesChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    XAIResponsesChatModelOptions? options,
  }) {
    _validateApiKeyPresence();
    final modelName = name ?? defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating xAI Responses chat model: $modelName '
      'with ${(tools ?? const []).length} tools, temp: $temperature, '
      'thinking: $enableThinking',
    );

    return XAIResponsesChatModel(
      name: modelName,
      tools: tools,
      temperature: temperature,
      apiKey: apiKey,
      baseUrl: baseUrl ?? defaultBaseUrl,
      headers: headers,
      defaultOptions: XAIResponsesChatModelOptions(
        temperature: temperature ?? options?.temperature,
        topP: options?.topP,
        maxOutputTokens: options?.maxOutputTokens,
        store: options?.store ?? true,
        metadata: options?.metadata,
        include: options?.include,
        parallelToolCalls: options?.parallelToolCalls,
        reasoning: options?.reasoning,
        reasoningEffort: options?.reasoningEffort,
        reasoningSummary: enableThinking && options?.reasoningSummary == null
            ? XAIReasoningSummary.detailed
            : options?.reasoningSummary,
        responseFormat: options?.responseFormat,
        truncationStrategy: options?.truncationStrategy,
        user: options?.user,
        imageDetail: options?.imageDetail,
        serverSideTools: options?.serverSideTools,
        fileSearchConfig: options?.fileSearchConfig,
        webSearchConfig: options?.webSearchConfig,
        codeInterpreterConfig: options?.codeInterpreterConfig,
        mcpTools: options?.mcpTools,
      ),
    );
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) {
    throw UnsupportedError(
      '$providerDisplayName provider does not currently support embeddings in '
      'dartantic.',
    );
  }

  @override
  MediaGenerationModel<XAIResponsesMediaGenerationModelOptions>
  createMediaModel({
    String? name,
    List<Tool>? tools,
    XAIResponsesMediaGenerationModelOptions? options,
  }) {
    _validateApiKeyPresence();
    final modelName =
        name ??
        defaultModelNames[ModelKind.media] ??
        defaultModelNames[ModelKind.chat]!;

    _logger.info(
      'Creating xAI Responses media model: $modelName '
      'with ${(tools ?? const []).length} tools',
    );

    return XAIResponsesMediaGenerationModel(
      name: modelName,
      tools: tools,
      defaultOptions:
          options ?? const XAIResponsesMediaGenerationModelOptions(),
      apiKey: apiKey!,
      baseUrl: baseUrl ?? defaultBaseUrl,
      headers: headers,
    );
  }

  void _validateApiKeyPresence() {
    if (apiKeyName != null && (apiKey == null || apiKey!.isEmpty)) {
      throw ArgumentError('$apiKeyName is required for $displayName provider');
    }
  }
}
