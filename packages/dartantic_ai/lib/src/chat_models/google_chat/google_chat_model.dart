import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:googleai_dart/googleai_dart.dart' as ga;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../../providers/google_api_utils.dart';
import 'google_chat_options.dart';
import 'google_message_mappers.dart';
import 'google_server_side_tools.dart';
import 'google_thinking_config_mapper.dart';

/// Wrapper around [Google AI for Developers](https://ai.google.dev/) API
/// (aka Gemini API).
class GoogleChatModel extends ChatModel<GoogleChatModelOptions> {
  /// Creates a [GoogleChatModel] instance.
  GoogleChatModel({
    required super.name,
    required String apiKey,
    required Uri baseUrl,
    http.Client? client,
    Map<String, String>? headers,
    super.tools,
    super.temperature,
    bool enableThinking = false,
    super.defaultOptions = const GoogleChatModelOptions(),
  }) : _enableThinking = enableThinking,
       _client = createGoogleAiClient(
         apiKey: apiKey,
         configuredBaseUrl: baseUrl,
         extraHeaders: headers ?? const {},
         httpClient: client,
       ) {
    _logger.info(
      'Creating Google model: $name '
      'with ${super.tools?.length ?? 0} tools, temp: $temperature, '
      'thinking: $enableThinking',
    );
  }

  /// Logger for Google chat model operations.
  static final Logger _logger = Logger('dartantic.chat.models.google');

  final ga.GoogleAIClient _client;
  final bool _enableThinking;

  /// The resolved base URL.
  @visibleForTesting
  Uri get resolvedBaseUrl => Uri.parse(_client.config.baseUrl);

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    GoogleChatModelOptions? options,
    Schema? outputSchema,
  }) {
    final request = _buildRequest(
      messages,
      options: options,
      outputSchema: outputSchema,
    );

    final modelId = googleModelIdForApiRequest(name);
    var chunkCount = 0;
    _logger.info(
      'Starting Google chat stream with ${messages.length} messages '
      'for model: $modelId',
    );

    return _client.models
        .streamGenerateContent(model: modelId, request: request)
        .where(_streamResponseHasCandidates)
        .map((response) {
          chunkCount++;
          _logger.fine('Received Google stream chunk $chunkCount');
          return response.toChatResult(normalizeGoogleModelName(name));
        });
  }

  ga.GenerateContentRequest _buildRequest(
    List<ChatMessage> messages, {
    GoogleChatModelOptions? options,
    Schema? outputSchema,
  }) {
    final safetySettings =
        (options?.safetySettings ?? defaultOptions.safetySettings)
            ?.toSafetySettings();

    final serverSideTools =
        options?.serverSideTools ?? defaultOptions.serverSideTools ?? const {};

    // Google doesn't support server-side tools + outputSchema simultaneously.
    // When outputSchema is provided, exclude server-side tools (double agent
    // phase 2). This matches the behavior for user-defined tools below.
    final enableCodeExecution =
        outputSchema == null &&
        serverSideTools.contains(GoogleServerSideTool.codeExecution);

    final enableGoogleSearch =
        outputSchema == null &&
        serverSideTools.contains(GoogleServerSideTool.googleSearch);

    final enableUrlContext =
        outputSchema == null &&
        serverSideTools.contains(GoogleServerSideTool.urlContext);

    final resolvedFileSearch = options?.fileSearch ?? defaultOptions.fileSearch;
    ga.FileSearch? fileSearchForRequest;
    // File search is supported in Gemini 3+ and can be used with outputSchema
    // so we do not remove it when outputSchema is provided.
    if (resolvedFileSearch != null) {
      if (resolvedFileSearch.fileSearchStoreNames.isEmpty) {
        throw ArgumentError(
          'GoogleFileSearchToolConfig.fileSearchStoreNames must not be empty.',
        );
      }
      fileSearchForRequest = ga.FileSearch(
        fileSearchStoreNames: resolvedFileSearch.fileSearchStoreNames,
        topK: resolvedFileSearch.topK,
        metadataFilter: resolvedFileSearch.metadataFilter,
      );
    }

    final resolvedMapsGrounding =
        options?.mapsGrounding ?? defaultOptions.mapsGrounding;
    final googleMapsForRequest =
        outputSchema == null && resolvedMapsGrounding != null
        ? ga.GoogleMaps(enableWidget: resolvedMapsGrounding.enableWidget)
        : null;

    final generationConfig = _buildGenerationConfig(
      options: options,
      outputSchema: outputSchema,
    );

    final contents = messages.toContentList();

    // Gemini API requires at least one non-empty content item
    if (contents.isEmpty || contents.every((c) => c.parts.isEmpty)) {
      throw ArgumentError(
        'Cannot generate content with empty input. '
        'At least one message with non-empty content is required.',
      );
    }

    // Google doesn't support tools + outputSchema simultaneously.
    // When outputSchema is provided, exclude tools (double agent phase 2).
    final toolsToSend = outputSchema != null
        ? const <Tool>[]
        : (tools ?? const <Tool>[]);

    final toolConfig = _buildToolConfig(options);
    final toolList = toolsToSend.toToolList(
      enableCodeExecution: enableCodeExecution,
      enableGoogleSearch: enableGoogleSearch,
      enableUrlContext: enableUrlContext,
      fileSearch: fileSearchForRequest,
      googleMaps: googleMapsForRequest,
    );

    return ga.GenerateContentRequest(
      systemInstruction: _extractSystemInstruction(messages),
      contents: contents,
      safetySettings: safetySettings,
      generationConfig: generationConfig,
      toolConfig: toolConfig,
      tools: toolList,
    );
  }

  ga.ToolConfig? _buildToolConfig(GoogleChatModelOptions? options) {
    final mode =
        options?.functionCallingMode ?? defaultOptions.functionCallingMode;
    final allowedNames =
        options?.allowedFunctionNames ?? defaultOptions.allowedFunctionNames;

    // If no mode specified and no allowed names, use default behavior
    if (mode == null && allowedNames == null) return null;

    final gaMode = switch (mode) {
      GoogleFunctionCallingMode.auto => ga.FunctionCallingMode.auto,
      GoogleFunctionCallingMode.any => ga.FunctionCallingMode.any,
      GoogleFunctionCallingMode.none => ga.FunctionCallingMode.none,
      GoogleFunctionCallingMode.validated => ga.FunctionCallingMode.validated,
      null => ga.FunctionCallingMode.auto,
    };

    return ga.ToolConfig(
      functionCallingConfig: ga.FunctionCallingConfig(
        mode: gaMode,
        allowedFunctionNames: allowedNames == null || allowedNames.isEmpty
            ? null
            : allowedNames,
      ),
    );
  }

  ga.GenerationConfig _buildGenerationConfig({
    GoogleChatModelOptions? options,
    Schema? outputSchema,
  }) {
    final stopSequences =
        options?.stopSequences ??
        defaultOptions.stopSequences ??
        const <String>[];

    final responseMimeType = outputSchema != null
        ? 'application/json'
        : options?.responseMimeType ?? defaultOptions.responseMimeType;

    final responseJsonSchema = _resolveResponseJsonSchema(
      outputSchema: outputSchema,
      responseSchema: options?.responseSchema ?? defaultOptions.responseSchema,
    );

    final thinkingConfig = _buildThinkingConfig(options);

    return ga.GenerationConfig(
      candidateCount: options?.candidateCount ?? defaultOptions.candidateCount,
      stopSequences: stopSequences,
      maxOutputTokens:
          options?.maxOutputTokens ?? defaultOptions.maxOutputTokens,
      temperature:
          temperature ?? options?.temperature ?? defaultOptions.temperature,
      topP: options?.topP ?? defaultOptions.topP,
      topK: options?.topK ?? defaultOptions.topK,
      responseMimeType: responseMimeType,
      responseJsonSchema: responseJsonSchema,
      thinkingConfig: thinkingConfig,
    );
  }

  ga.ThinkingConfig? _buildThinkingConfig(GoogleChatModelOptions? options) {
    final thinkingLevel =
        options?.thinkingLevel ?? defaultOptions.thinkingLevel;
    final thinkingBudgetTokens =
        options?.thinkingBudgetTokens ?? defaultOptions.thinkingBudgetTokens;

    return buildGoogleGenerationThinkingConfig(
      enableThinking: _enableThinking,
      thinkingBudgetTokens: thinkingBudgetTokens,
      thinkingLevel: thinkingLevel,
    );
  }

  Map<String, dynamic>? _resolveResponseJsonSchema({
    Schema? outputSchema,
    Map<String, dynamic>? responseSchema,
  }) {
    if (outputSchema != null) {
      return Map<String, dynamic>.from(outputSchema.value);
    }
    if (responseSchema != null) {
      return Map<String, dynamic>.from(responseSchema);
    }
    return null;
  }

  ga.Content? _extractSystemInstruction(List<ChatMessage> messages) {
    for (final message in messages) {
      if (message.role == ChatMessageRole.system) {
        final instructions = message.parts
            .whereType<TextPart>()
            .map((part) => part.text)
            .where((text) => text.isNotEmpty)
            .join('\n')
            .trim();
        if (instructions.isEmpty) {
          return null;
        }
        return ga.Content(parts: [ga.TextPart(instructions)]);
      }
    }
    return null;
  }

  @override
  void dispose() {
    _client.close();
  }
}

bool _streamResponseHasCandidates(ga.GenerateContentResponse response) {
  final candidates = response.candidates;
  return candidates != null && candidates.isNotEmpty;
}
