import 'package:dartantic_ai/dartantic_ai.dart';

import 'package:test/test.dart';

import 'test_helpers/run_provider_test.dart';

class DummyProvider
    extends
        Provider<
          ChatModelOptions,
          EmbeddingsModelOptions,
          MediaGenerationModelOptions
        > {
  DummyProvider()
    : super(
        name: 'dummy',
        displayName: 'Dummy',
        defaultModelNames: const {ModelKind.chat: 'test-model'},
      );

  DummyChatModel? lastModel;

  @override
  ChatModel<ChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    ChatModelOptions? options,
  }) {
    lastModel = DummyChatModel(
      name: name ?? defaultModelNames[ModelKind.chat]!,
      tools: tools,
      temperature: temperature,
    );
    return lastModel!;
  }

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) => throw UnsupportedError('Embeddings not supported in DummyProvider');

  @override
  Stream<ModelInfo> listModels() async* {}

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
  }) =>
      throw UnsupportedError('Media generation not supported in DummyProvider');
}

class DummyChatModel extends ChatModel<ChatModelOptions> {
  DummyChatModel({required super.name, super.tools, super.temperature})
    : super(defaultOptions: const ChatModelOptions());

  int sendCalls = 0;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    ChatModelOptions? options,
    Schema? outputSchema,
  }) async* {
    sendCalls++;

    // Stage 1: No tool results yet -> issue a single tool call
    final hasToolResults = messages.any(
      (m) => m.parts.whereType<ToolPart>().any(
        (p) => p.kind == ToolPartKind.result,
      ),
    );

    if (!hasToolResults) {
      const toolCall = ToolPart.call(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: {'path': 'lib/x.dart', 'content': 'hello'},
      );
      final msg = ChatMessage(
        role: ChatMessageRole.model,
        parts: const [toolCall],
      );
      yield ChatResult<ChatMessage>(
        output: msg,
        messages: [msg],
        finishReason: FinishReason.toolCalls,
        metadata: const {},
        usage: const LanguageModelUsage(),
      );
      return;
    }

    // Stage 2+: After tool results, return an empty assistant message
    final empty = ChatMessage(role: ChatMessageRole.model, parts: const []);
    yield ChatResult<ChatMessage>(
      output: empty,
      messages: [ChatMessage(role: ChatMessageRole.model, parts: const [])],
      finishReason: FinishReason.stop,
      metadata: const {},
      usage: const LanguageModelUsage(),
    );
  }

  @override
  void dispose() {}
}

// Wrapper around real providers to avoid network; returns in-memory model
class WrapperProvider
    extends
        Provider<
          ChatModelOptions,
          EmbeddingsModelOptions,
          MediaGenerationModelOptions
        > {
  WrapperProvider(Provider base)
    : super(
        name: 'wrap-${base.name}',
        displayName: 'Wrapper(${base.displayName})',
        defaultModelNames: {
          ModelKind.chat: base.defaultModelNames[ModelKind.chat] ?? 'model',
        },
        aliases: base.aliases,
      );

  late DummyModel lastModel;

  @override
  ChatModel<ChatModelOptions> createChatModel({
    String? name,
    List<Tool>? tools,
    double? temperature,
    bool enableThinking = false,
    ChatModelOptions? options,
  }) => lastModel = DummyModel(name: name ?? 'model');

  @override
  EmbeddingsModel<EmbeddingsModelOptions> createEmbeddingsModel({
    String? name,
    EmbeddingsModelOptions? options,
  }) => throw UnsupportedError('Embeddings not supported in WrapperProvider');

  @override
  Stream<ModelInfo> listModels() async* {}

  @override
  MediaGenerationModel<MediaGenerationModelOptions> createMediaModel({
    String? name,
    List<Tool>? tools,
    MediaGenerationModelOptions? options,
  }) => throw UnsupportedError('Media not supported in WrapperProvider');
}

class DummyModel extends ChatModel<ChatModelOptions> {
  DummyModel({required super.name})
    : super(defaultOptions: const ChatModelOptions());

  int sendCalls = 0;

  @override
  Stream<ChatResult<ChatMessage>> sendStream(
    List<ChatMessage> messages, {
    ChatModelOptions? options,
    Schema? outputSchema,
  }) async* {
    sendCalls++;
    final hasToolResults = messages.any(
      (m) => m.parts.whereType<ToolPart>().any(
        (p) => p.kind == ToolPartKind.result,
      ),
    );

    if (!hasToolResults) {
      // Emit a single tool call on first pass
      const toolCall = ToolPart.call(
        callId: 'call_1',
        toolName: 'write_file',
        arguments: {'path': 'lib/x.dart', 'content': 'hello'},
      );
      final msg = ChatMessage(
        role: ChatMessageRole.model,
        parts: const [toolCall],
      );
      yield ChatResult<ChatMessage>(
        output: msg,
        messages: [msg],
        finishReason: FinishReason.toolCalls,
        metadata: const {},
        usage: const LanguageModelUsage(),
      );
      return;
    }

    // After tool results, return an empty assistant message
    final empty = ChatMessage(role: ChatMessageRole.model, parts: const []);
    yield ChatResult<ChatMessage>(
      output: empty,
      messages: [empty],
      finishReason: FinishReason.stop,
      metadata: const {},
      usage: const LanguageModelUsage(),
    );
  }

  @override
  void dispose() {}
}

void main() {
  test('allows one empty-after-tools continuation then stops', () async {
    final provider = DummyProvider();

    final writeFile = Tool(
      name: 'write_file',
      description: 'Create or overwrite a file',
      inputSchema: Schema.fromMap({
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['path', 'content'],
      }),
      onCall: (args) async => {'ok': true},
    );

    final agent = Agent.forProvider(
      provider,
      chatModelName: 'test-model',
      tools: [writeFile],
    );

    final result = await agent.send('minimal');

    // Verify the model was invoked exactly 3 times:
    //  1) tool call, 2) first empty (continue), 3) second empty (stop)
    expect(provider.lastModel, isNotNull);
    expect(provider.lastModel!.sendCalls, equals(3));

    // Verify the final message is the empty assistant message
    expect(result.messages, isNotEmpty);
    final lastMsg = result.messages.last;
    expect(lastMsg.role, equals(ChatMessageRole.model));
    expect(lastMsg.parts, isEmpty);
  });

  group('Cross-provider behavior', () {
    final writeFile = Tool(
      name: 'write_file',
      description: 'Create or overwrite a file',
      inputSchema: Schema.fromMap({
        'type': 'object',
        'properties': {
          'path': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['path', 'content'],
      }),
      onCall: (args) async => {'ok': true},
    );

    runProviderTest(
      'default orchestrator continues once then stops',
      (provider) async {
        final wrapper = WrapperProvider(provider);
        final agent = Agent.forProvider(
          wrapper,
          chatModelName: provider.defaultModelNames[ModelKind.chat],
          tools: [writeFile],
        );

        final result = await agent.send('minimal');

        expect(
          wrapper.lastModel.sendCalls,
          equals(3),
          reason: 'provider=${provider.name}',
        );
        expect(
          result.messages,
          isNotEmpty,
          reason: 'provider=${provider.name}',
        );
        final lastMsg = result.messages.last;
        expect(
          lastMsg.role,
          equals(ChatMessageRole.model),
          reason: 'provider=${provider.name}',
        );
        expect(lastMsg.parts, isEmpty, reason: 'provider=${provider.name}');
      },
      requiredCaps: {ProviderTestCaps.chat, ProviderTestCaps.multiToolCalls},
    );

    final outputSchema = Schema.fromMap({
      'type': 'object',
      'properties': {
        'ok': {'type': 'boolean'},
      },
      'required': ['ok'],
    });

    runProviderTest(
      'typed-output orchestrator path does not loop',
      (provider) async {
        final wrapper = WrapperProvider(provider);
        final agent = Agent.forProvider(
          wrapper,
          chatModelName: provider.defaultModelNames[ModelKind.chat],
          tools: [writeFile],
        );

        final result = await agent.send('minimal', outputSchema: outputSchema);

        expect(
          wrapper.lastModel.sendCalls >= 2,
          isTrue,
          reason: 'provider=${provider.name}',
        );
        final lastMsg = result.messages.last;
        expect(
          lastMsg.role,
          equals(ChatMessageRole.model),
          reason: 'provider=${provider.name}',
        );
        expect(lastMsg.parts, isEmpty, reason: 'provider=${provider.name}');
      },
      requiredCaps: {ProviderTestCaps.chat, ProviderTestCaps.multiToolCalls},
    );
  });
}
