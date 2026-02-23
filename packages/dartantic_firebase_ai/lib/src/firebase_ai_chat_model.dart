import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:logging/logging.dart';

import 'firebase_ai_chat_options.dart';
import 'firebase_ai_provider.dart';
import 'firebase_message_mappers.dart';

/// Wrapper around Firebase AI (Gemini via Firebase).
class FirebaseAIChatModel extends ChatModel<FirebaseAIChatModelOptions> {
  /// Creates a [FirebaseAIChatModel] instance.
  FirebaseAIChatModel({
    required super.name,
    required this.backend,
    List<Tool>? tools,
    super.temperature,
    super.defaultOptions = const FirebaseAIChatModelOptions(),
  }) : super(
         tools: tools?.where((t) => t.name != kReturnResultToolName).toList(),
       ) {
    _logger.info(
      'Creating Firebase AI model: $name (${backend.name}) '
      'with ${super.tools?.length ?? 0} tools, temp: $temperature',
    );

    _firebaseAiClient = _createFirebaseAiClient();
  }

  static final Logger _logger = Logger('dartantic.chat.models.firebase_ai');

  /// The name of the return_result tool that should be filtered out.
  /// Firebase AI has native typed output support via
  /// `responseMimeType: 'application/json'`.
  static const String kReturnResultToolName = 'return_result';

  /// The Firebase AI backend this model uses.
  final FirebaseAIBackend backend;

  late fai.GenerativeModel _firebaseAiClient;
  String? _currentSystemInstruction;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    FirebaseAIChatModelOptions? options,
    Schema? outputSchema,
  }) {
    if (outputSchema != null &&
        super.tools != null &&
        super.tools!.isNotEmpty) {
      throw ArgumentError(
        'Firebase AI does not support using tools and typed output '
        '(outputSchema) simultaneously. Either use tools without outputSchema, '
        'or use outputSchema without tools.',
      );
    }

    _logger.info(
      'Starting Firebase AI chat stream with ${messages.length} '
      'messages for model: $name',
    );

    final (
      prompt,
      safetySettings,
      generationConfig,
      tools,
      toolConfig,
    ) = _generateCompletionRequest(
      messages,
      options: options,
      outputSchema: outputSchema,
    );

    var chunkCount = 0;
    return _firebaseAiClient
        .generateContentStream(
          prompt,
          safetySettings: safetySettings,
          generationConfig: generationConfig,
          tools: tools,
          toolConfig: toolConfig,
        )
        .handleError((Object error, StackTrace stackTrace) {
          _logger.severe(
            'Firebase AI stream error: ${error.runtimeType}: $error',
            error,
            stackTrace,
          );
          throw error; // ignore: only_throw_errors
        })
        .map((completion) {
          chunkCount++;
          _logger.fine('Received Firebase AI stream chunk $chunkCount');
          return completion.toChatResult(name);
        });
  }

  (
    Iterable<fai.Content> prompt,
    List<fai.SafetySetting>? safetySettings,
    fai.GenerationConfig? generationConfig,
    List<fai.Tool>? tools,
    fai.ToolConfig? toolConfig,
  )
  _generateCompletionRequest(
    List<ChatMessage> messages, {
    FirebaseAIChatModelOptions? options,
    Schema? outputSchema,
  }) {
    _updateClientIfNeeded(messages);

    return (
      messages.toContentList(),
      (options?.safetySettings ?? defaultOptions.safetySettings)
          ?.toSafetySettings(),
      fai.GenerationConfig(
        candidateCount:
            options?.candidateCount ?? defaultOptions.candidateCount,
        stopSequences:
            options?.stopSequences ?? defaultOptions.stopSequences ?? const [],
        maxOutputTokens:
            options?.maxOutputTokens ?? defaultOptions.maxOutputTokens,
        temperature:
            temperature ?? options?.temperature ?? defaultOptions.temperature,
        topP: options?.topP ?? defaultOptions.topP,
        topK: options?.topK ?? defaultOptions.topK,
        responseMimeType: outputSchema != null
            ? 'application/json'
            : options?.responseMimeType ?? defaultOptions.responseMimeType,
        responseSchema:
            _convertOutputSchema(outputSchema) ??
            (options?.responseSchema ?? defaultOptions.responseSchema)
                ?.toSchema(),
      ),
      (tools ?? const []).toToolList(
        enableCodeExecution:
            options?.enableCodeExecution ??
            defaultOptions.enableCodeExecution ??
            false,
      ),
      null,
    );
  }

  @override
  void dispose() {}

  fai.Schema? _convertOutputSchema(Schema? outputSchema) {
    if (outputSchema == null) return null;
    return Map<String, dynamic>.from(outputSchema.value).toSchema();
  }

  fai.GenerativeModel _createFirebaseAiClient({String? systemInstruction}) {
    _logger.fine(
      'Creating Firebase AI client for model: $name (${backend.name})',
    );

    final firebaseAI = switch (backend) {
      FirebaseAIBackend.googleAI => fai.FirebaseAI.googleAI(),
      FirebaseAIBackend.vertexAI => fai.FirebaseAI.vertexAI(),
    };

    return firebaseAI.generativeModel(
      model: name,
      systemInstruction: systemInstruction != null
          ? fai.Content.system(systemInstruction)
          : null,
    );
  }

  void _updateClientIfNeeded(List<ChatMessage> messages) {
    final systemInstruction =
        messages.firstOrNull?.role == ChatMessageRole.system
        ? messages.firstOrNull?.parts
              .whereType<TextPart>()
              .map((p) => p.text)
              .join('\n')
        : null;

    if (systemInstruction != _currentSystemInstruction) {
      _currentSystemInstruction = systemInstruction;
      _firebaseAiClient = _createFirebaseAiClient(
        systemInstruction: systemInstruction,
      );
    }
  }
}
