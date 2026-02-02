import 'dart:io';

import 'package:dartantic_ai/src/chat_models/llamadart_chat/model_resolvers.dart';
import 'package:test/test.dart';

void main() {
  group('FileModelResolver', () {
    test('resolves model with .gguf extension', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_models');
      final modelFile = File('${tempDir.path}/test.gguf');
      await modelFile.create();

      final resolver = FileModelResolver(tempDir.path);
      final resolved = await resolver.resolveModel('test.gguf');

      expect(resolved, modelFile.path);

      await tempDir.delete(recursive: true);
    });

    test('auto-appends .gguf extension', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_models');
      final modelFile = File('${tempDir.path}/test.gguf');
      await modelFile.create();

      final resolver = FileModelResolver(tempDir.path);
      final resolved = await resolver.resolveModel('test');

      expect(resolved, modelFile.path);

      await tempDir.delete(recursive: true);
    });

    test('throws ModelNotFoundException when model not found', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_models');

      final resolver = FileModelResolver(tempDir.path);

      expect(
        () => resolver.resolveModel('nonexistent'),
        throwsA(isA<ModelNotFoundException>()),
      );

      await tempDir.delete(recursive: true);
    });

    test('lists all .gguf files in directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_models');
      await File('${tempDir.path}/model1.gguf').create();
      await File('${tempDir.path}/model2.gguf').create();
      await File('${tempDir.path}/other.txt').create();

      final resolver = FileModelResolver(tempDir.path);
      final models = await resolver.listModels().toList();

      expect(models.length, 2);
      expect(models.every((m) => m.name.endsWith('.gguf')), true);

      await tempDir.delete(recursive: true);
    });
  });

  group('UrlModelResolver', () {
    test('returns URL with .gguf extension', () async {
      const resolver = UrlModelResolver('https://example.com/models');
      final resolved = await resolver.resolveModel('test.gguf');

      expect(resolved, 'https://example.com/models/test.gguf');
    });

    test('auto-appends .gguf extension', () async {
      const resolver = UrlModelResolver('https://example.com/models');
      final resolved = await resolver.resolveModel('test');

      expect(resolved, 'https://example.com/models/test.gguf');
    });
  });

  group('ModelNotFoundException', () {
    test('includes message and searched locations', () {
      const exception = ModelNotFoundException(
        'Model not found',
        searchedLocations: ['/path1/model.gguf', '/path2/model.gguf'],
      );

      expect(exception.message, 'Model not found');
      expect(exception.searchedLocations.length, 2);
      expect(exception.toString(), contains('ModelNotFoundException'));
    });
  });
}
