import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

import 'mock_firebase.dart';

void main() {
  setUpAll(() async {
    await initializeMockFirebase();
  });

  group('FirebaseAIChatModel', () {
    test('constructs with defaults', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
      );

      expect(model.name, 'gemini-2.5-flash');
      expect(model.backend, FirebaseAIBackend.googleAI);
      expect(model.defaultOptions, isA<FirebaseAIChatModelOptions>());
      expect(model.app, isNull);
      expect(model.appCheck, isNull);
      expect(model.auth, isNull);
      expect(model.useLimitedUseAppCheckTokens, isNull);
    });

    test('filters return_result tool', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
        tools: [
          Tool<Map<String, dynamic>>(
            name: 'return_result',
            description: 'internal',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
          Tool<Map<String, dynamic>>(
            name: 'kept_tool',
            description: 'kept',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
        ],
      );

      expect(model.tools, hasLength(1));
      expect(model.tools!.single.name, 'kept_tool');
    });

    test('sendStream accepts Schema outputSchema', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
      );
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'result': {'type': 'string'},
        },
      });

      final stream = model.sendStream([
        ChatMessage.user('Return JSON'),
      ], outputSchema: schema);
      expect(stream, isA<Stream<ChatResult<ChatMessage>>>());
    });

    test('rejects tools and outputSchema together', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
        tools: [
          Tool<Map<String, dynamic>>(
            name: 'lookup',
            description: 'lookup',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
        ],
      );
      final schema = Schema.fromMap({'type': 'object'});

      expect(
        () => model.sendStream([ChatMessage.user('run')], outputSchema: schema),
        throwsArgumentError,
      );
    });

    test('accepts enableThinking via defaultOptions', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
        defaultOptions: const FirebaseAIChatModelOptions(enableThinking: true),
      );

      expect(model.defaultOptions.enableThinking, isTrue);
    });

    test('accepts thinking budget via defaultOptions', () {
      final model = FirebaseAIChatModel(
        name: 'gemini-2.5-flash',
        backend: FirebaseAIBackend.googleAI,
        defaultOptions: const FirebaseAIChatModelOptions(
          enableThinking: true,
          thinkingBudgetTokens: 4096,
        ),
      );

      expect(model.defaultOptions.thinkingBudgetTokens, 4096);
    });
  });

  group('FirebaseAIChatModelOptions', () {
    test('defaults are all null', () {
      const options = FirebaseAIChatModelOptions();
      expect(options.enableThinking, isNull);
      expect(options.thinkingBudgetTokens, isNull);
      expect(options.responseSchema, isNull);
      expect(options.temperature, isNull);
    });

    test('preserves all thinking-related options', () {
      const options = FirebaseAIChatModelOptions(
        enableThinking: true,
        thinkingBudgetTokens: 8192,
      );
      expect(options.enableThinking, isTrue);
      expect(options.thinkingBudgetTokens, 8192);
    });

    test('responseSchema accepts Schema type', () {
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
        },
      });
      final options = FirebaseAIChatModelOptions(responseSchema: schema);
      expect(options.responseSchema, isNotNull);
      expect(options.responseSchema, isA<Schema>());
    });
  });

  group('FirebaseAIProvider', () {
    test('createChatModel passes enableThinking to model', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      final model = provider.createChatModel(enableThinking: true);

      expect(model, isA<FirebaseAIChatModel>());
      expect(model.defaultOptions.enableThinking, isTrue);
    });

    test('createChatModel passes thinking budget via options', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      final model = provider.createChatModel(
        enableThinking: true,
        options: const FirebaseAIChatModelOptions(thinkingBudgetTokens: 2048),
      );

      expect(model.defaultOptions.thinkingBudgetTokens, 2048);
    });

    test('createChatModel passes enableThinking via options', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      final model = provider.createChatModel(
        options: const FirebaseAIChatModelOptions(enableThinking: true),
      );

      expect(model.defaultOptions.enableThinking, isTrue);
    });

    test('createChatModel validates temperature range', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

      expect(
        () => provider.createChatModel(temperature: 3),
        throwsArgumentError,
      );
      expect(
        () => provider.createChatModel(temperature: -1),
        throwsArgumentError,
      );
    });

    test('createChatModel uses default model name', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      final model = provider.createChatModel();

      expect(model.name, 'gemini-2.5-flash');
    });

    test('createChatModel accepts custom model name', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      final model = provider.createChatModel(name: 'gemini-2.0-flash');

      expect(model.name, 'gemini-2.0-flash');
    });

    test('appCheck defaults to null', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

      expect(provider.app, isNull);
      expect(provider.appCheck, isNull);
      expect(provider.auth, isNull);
      expect(provider.useLimitedUseAppCheckTokens, isNull);
    });
  });
}
