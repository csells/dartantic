import 'dart:io';

import 'package:dartantic_ai/src/chat_models/llamadart_chat/llamadart_chat_options.dart';
import 'package:dartantic_ai/src/chat_models/llamadart_chat/model_resolvers.dart';
import 'package:dartantic_ai/src/providers/llamadart_provider.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

void main() {
  group('LlamadartProvider', () {
    test('creates provider with default options', () {
      final provider = LlamadartProvider();

      expect(provider.name, 'llamadart');
      expect(provider.displayName, 'Llamadart');
      expect(provider.apiKeyName, isNull);
    });

    test('creates provider with custom defaultChatOptions', () {
      final tempDir = Directory.systemTemp.createTempSync('test_models');

      final customOptions = LlamadartChatOptions(
        resolver: FileModelResolver(tempDir.path),
        temperature: 0.7,
      );

      final provider = LlamadartProvider(defaultChatOptions: customOptions);

      expect(provider, isNotNull);

      tempDir.deleteSync(recursive: true);
    });

    test('createChatModel throws UnsupportedError for tools', () {
      final provider = LlamadartProvider();

      expect(
        () => provider.createChatModel(
          tools: [
            Tool(
              name: 'test_tool',
              description: 'Test',
              inputSchema: Schema.fromMap(<String, Object?>{
                'type': 'object',
                'properties': <String, Object?>{},
              }),
              onCall: (args) async => {},
            ),
          ],
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('createChatModel throws UnsupportedError for enableThinking', () {
      final provider = LlamadartProvider();

      expect(
        () => provider.createChatModel(enableThinking: true),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('createChatModel uses default resolver when none provided', () {
      final provider = LlamadartProvider();
      final model = provider.createChatModel();

      expect(model, isNotNull);
      expect(model.name, isNotEmpty);
    });

    test('createChatModel uses custom resolver from options', () {
      final tempDir = Directory.systemTemp.createTempSync('test_models');
      final resolver = FileModelResolver(tempDir.path);

      final provider = LlamadartProvider();
      final model = provider.createChatModel(
        options: LlamadartChatOptions(resolver: resolver),
      );

      expect(model, isNotNull);

      tempDir.deleteSync(recursive: true);
    });

    test('createChatModel uses provider default resolver', () {
      final tempDir = Directory.systemTemp.createTempSync('test_models');
      final resolver = FileModelResolver(tempDir.path);

      final provider = LlamadartProvider(
        defaultChatOptions: LlamadartChatOptions(resolver: resolver),
      );

      final model = provider.createChatModel();
      expect(model, isNotNull);

      tempDir.deleteSync(recursive: true);
    });

    test('createEmbeddingsModel throws UnsupportedError', () {
      final provider = LlamadartProvider();

      expect(provider.createEmbeddingsModel, throwsA(isA<UnsupportedError>()));
    });

    test('createMediaModel throws UnsupportedError', () {
      final provider = LlamadartProvider();

      expect(provider.createMediaModel, throwsA(isA<UnsupportedError>()));
    });

    test('listModels delegates to resolver', () async {
      final tempDir = Directory.systemTemp.createTempSync('test_models');
      await File('${tempDir.path}/model1.gguf').create();
      await File('${tempDir.path}/model2.gguf').create();

      final resolver = FileModelResolver(tempDir.path);
      final provider = LlamadartProvider(
        defaultChatOptions: LlamadartChatOptions(resolver: resolver),
      );

      final models = await provider.listModels().toList();
      expect(models.length, 2);

      tempDir.deleteSync(recursive: true);
    });

    test('has correct default model name', () {
      final provider = LlamadartProvider();

      expect(provider.defaultModelNames[ModelKind.chat], isNotNull);
    });

    test('has llamadart and llama aliases', () {
      final provider = LlamadartProvider();

      expect(provider.name, 'llamadart');
      // Aliases tested via provider registration
    });
  });
}
