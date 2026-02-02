import 'dart:io';

import 'package:dartantic_ai/src/chat_models/llamadart_chat/hf_model_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  group('HFModelDownloader force parameter', () {
    late Directory tempDir;
    late HFModelDownloader downloader;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hf_force_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('force: false returns cached path without downloading', () async {
      // Create a cached model
      const repo = 'test/repo';
      const model = 'test.gguf';
      final modelDir = Directory(path.join(tempDir.path, repo));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, model));
      modelFile.writeAsStringSync('original content');

      downloader = HFModelDownloader(cacheDir: tempDir.path);

      // Call without force - should return immediately
      var progressCalled = false;
      final resultPath = await downloader.downloadModel(
        repo,
        model,
        force: false,
        onProgress: (_) => progressCalled = true,
      );

      expect(resultPath, modelFile.path);
      expect(File(resultPath).readAsStringSync(), 'original content');
      expect(progressCalled, false, reason: 'Should not download when cached');
    });

    test('force: true re-downloads even when cached', () async {
      // Create a cached model
      const repo = 'test/repo';
      const model = 'test.gguf';
      final modelDir = Directory(path.join(tempDir.path, repo));
      modelDir.createSync(recursive: true);
      final modelFile = File(path.join(modelDir.path, model));
      modelFile.writeAsStringSync('original content');

      // Mock HTTP client that returns new content
      final mockClient = MockClient((request) async {
        return http.Response(
          'new content from download',
          200,
          headers: {'content-length': '25'},
        );
      });

      downloader = HFModelDownloader(
        cacheDir: tempDir.path,
        httpClient: mockClient,
      );

      // Call WITH force - should download and replace
      var progressCalled = false;
      final resultPath = await downloader.downloadModel(
        repo,
        model,
        force: true,
        onProgress: (_) => progressCalled = true,
      );

      expect(resultPath, modelFile.path);
      expect(File(resultPath).readAsStringSync(), 'new content from download');
      expect(progressCalled, true, reason: 'Should download when force=true');
    });

    test('force: true works when model not cached', () async {
      const repo = 'test/repo';
      const model = 'test.gguf';

      // Mock HTTP client
      final mockClient = MockClient((request) async {
        return http.Response(
          'downloaded content',
          200,
          headers: {'content-length': '18'},
        );
      });

      downloader = HFModelDownloader(
        cacheDir: tempDir.path,
        httpClient: mockClient,
      );

      // Model not cached - should download
      var progressCalled = false;
      final resultPath = await downloader.downloadModel(
        repo,
        model,
        force: true,
        onProgress: (_) => progressCalled = true,
      );

      final modelFile = File(resultPath);
      expect(modelFile.existsSync(), true);
      expect(modelFile.readAsStringSync(), 'downloaded content');
      expect(progressCalled, true);
    });
  });
}
