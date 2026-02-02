import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('HFModelDownloader', () {
    late Directory tempDir;
    late HFModelDownloader downloader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hf_test_');
      downloader = HFModelDownloader(cacheDir: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('isModelCached returns false when model not cached', () async {
      final cached = await downloader.isModelCached('repo/model', 'test.gguf');
      expect(cached, isFalse);
    });

    test('isModelCached returns true when model is cached', () async {
      // Create the cache structure manually
      final modelDir = Directory(path.join(tempDir.path, 'repo', 'model'));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, 'test.gguf'));
      modelFile.writeAsStringSync('fake model data');

      final cached = await downloader.isModelCached('repo/model', 'test.gguf');
      expect(cached, isTrue);
    });

    test('repo-based cache structure is correct', () async {
      // Create a cached model
      const repo = 'TheBloke/TinyLlama';
      const model = 'model.gguf';
      final modelDir = Directory(path.join(tempDir.path, repo));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, model));
      modelFile.writeAsStringSync('fake model');

      final cached = await downloader.isModelCached(repo, model);
      expect(cached, isTrue);

      // Verify path structure
      final expectedPath = path.join(tempDir.path, repo, model);
      expect(modelFile.path, expectedPath);
    });

    test('auto-appends .gguf extension if missing', () async {
      // Create a model without extension
      const repo = 'repo/model';
      const modelName = 'test'; // No .gguf extension

      final modelDir = Directory(path.join(tempDir.path, repo));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, '$modelName.gguf'));
      modelFile.writeAsStringSync('fake model');

      // Should find it with auto-appended extension
      final cached = await downloader.isModelCached(repo, modelName);
      expect(cached, isTrue);
    });

    test('returns full absolute path to cached model', () async {
      // Create a cached model
      const repo = 'test/repo';
      const model = 'test.gguf';
      final modelDir = Directory(path.join(tempDir.path, repo));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, model));
      modelFile.writeAsStringSync('fake model');

      // downloadModel should return immediately with cached path
      final modelPath = await downloader.downloadModel(repo, model);

      expect(modelPath, isNotEmpty);
      expect(path.isAbsolute(modelPath), isTrue);
      expect(modelPath, endsWith('test.gguf'));
      expect(File(modelPath).existsSync(), isTrue);
    });

    test(
      'downloadModel returns cached path without download if cached',
      () async {
        // Pre-populate cache
        const repo = 'test/repo';
        const model = 'cached.gguf';
        final modelDir = Directory(path.join(tempDir.path, repo));
        modelDir.createSync(recursive: true);
        final modelFile = File(path.join(modelDir.path, model));
        modelFile.writeAsStringSync('cached data');

        var progressCallbackCount = 0;
        final modelPath = await downloader.downloadModel(
          repo,
          model,
          onProgress: (p) => progressCallbackCount++,
        );

        // Should return path immediately without download
        expect(modelPath, modelFile.path);
        expect(progressCallbackCount, 0); // No progress callbacks
      },
    );

    // Note: The following tests would require actual HTTP mocking
    // or integration testing:
    // - downloadModel() with force re-download
    // - Progress callback receives correct metrics
    // - Cleanup on partial download failure
    // - Error on HTTP 404/network failure
    //
    // These are marked as integration tests and would run in a
    // separate test suite with actual network access or proper
    // HTTP mocking infrastructure.
  }, skip: Platform.environment.containsKey('CI') ? false : null);
}
