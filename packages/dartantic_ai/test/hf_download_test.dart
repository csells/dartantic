import 'dart:io';

import 'package:dartantic_ai/src/chat_models/llamadart_chat/model_resolvers.dart';
import 'package:test/test.dart';

void main() {
  group('HFModelResolver Download', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hf_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses cached model if it exists', () async {
      // Create a fake cached model
      final cacheFile = File('${tempDir.path}/test-model.gguf');
      await cacheFile.writeAsString('fake model data');

      final resolver = HFModelResolver(
        repo: 'test/repo',
        cacheDir: tempDir.path,
      );

      final result = await resolver.resolveModel('test-model');
      expect(result, equals(cacheFile.path));
    });

    test('throws StateError if cacheDir is null for download', () async {
      const resolver = HFModelResolver(repo: 'test/repo');

      expect(
        () => resolver.resolveModel('non-existent-model'),
        throwsA(isA<StateError>()),
      );
    });

    test('auto-appends .gguf extension', () async {
      // Create a fake cached model with .gguf extension
      final cacheFile = File('${tempDir.path}/test-model.gguf');
      await cacheFile.writeAsString('fake model data');

      final resolver = HFModelResolver(
        repo: 'test/repo',
        cacheDir: tempDir.path,
      );

      // Request without .gguf extension
      final result = await resolver.resolveModel('test-model');
      expect(result, equals(cacheFile.path));
    });

    test('uses custom revision', () {
      const resolver = HFModelResolver(
        repo: 'test/repo',
        revision: 'custom-branch',
      );

      expect(resolver.revision, equals('custom-branch'));
    });

    test('defaults to main revision', () {
      const resolver = HFModelResolver(repo: 'test/repo');

      expect(resolver.revision, equals('main'));
    });

    // Note: We don't test actual downloads in unit tests to avoid:
    // 1. Network dependencies
    // 2. Long download times
    // 3. Large disk space usage
    // 4. Rate limiting issues
    // Real download testing should be done manually or in integration tests
  });
}
