// Async I/O is intentional for this downloader
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../retry_http_client.dart';
import 'hf_download_progress.dart';

/// Downloads models from Hugging Face with progress tracking
class HFModelDownloader {
  /// Creates a [HFModelDownloader] with the given cache directory
  HFModelDownloader({required String cacheDir, http.Client? httpClient})
    : _cacheDir = cacheDir,
      _httpClient = RetryHttpClient(inner: httpClient ?? http.Client());

  static final Logger _logger = Logger('dartantic.chat.models.hf_downloader');

  final String _cacheDir;
  final RetryHttpClient _httpClient;

  // Progress update interval (~1MB)
  static const _progressUpdateIntervalBytes = 1024 * 1024;

  // Speed calculation window size
  static const _speedCalculationWindowSize = 5;

  /// Checks if a model is already cached
  Future<bool> isModelCached(String repo, String modelName) async {
    final fileName = _ensureGgufExtension(modelName);
    final filePath = _buildCachePath(repo, fileName);
    return File(filePath).exists();
  }

  /// Downloads a model from Hugging Face
  ///
  /// Returns the full absolute path to the downloaded model file.
  /// If the model is already cached and [force] is false, returns immediately.
  /// Progress is reported via [onProgress] callback.
  Future<String> downloadModel(
    String repo,
    String modelName, {
    bool force = false,
    String revision = 'main',
    void Function(DownloadProgress)? onProgress,
  }) async {
    final fileName = _ensureGgufExtension(modelName);
    final filePath = _buildCachePath(repo, fileName);

    // Return immediately if cached and not forcing re-download
    if (!force && await isModelCached(repo, modelName)) {
      _logger.fine('Model already cached at: $filePath');
      return filePath;
    }

    // Download the model
    _logger.info('Downloading model from HF: $repo/$fileName');
    await _downloadFromHF(repo, fileName, filePath, revision, onProgress);

    return filePath;
  }

  /// Builds the cache path for a model file using repo-based structure
  String _buildCachePath(String repo, String fileName) =>
      path.join(_cacheDir, repo, fileName);

  /// Ensures the model name has a .gguf extension
  String _ensureGgufExtension(String modelName) {
    if (modelName.endsWith('.gguf')) {
      return modelName;
    }
    return '$modelName.gguf';
  }

  /// Downloads a model from Hugging Face
  Future<void> _downloadFromHF(
    String repo,
    String fileName,
    String destinationPath,
    String revision,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final url = Uri.parse(
      'https://huggingface.co/$repo/resolve/$revision/$fileName',
    );

    _logger.info('Downloading from: $url');

    final request = http.Request('GET', url);
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to download model: HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength;
    if (contentLength == null) {
      throw Exception('Content-Length header missing from response');
    }

    // Create destination directory
    final destFile = File(destinationPath);
    destFile.parent.createSync(recursive: true);

    // Download to temp file, then rename atomically
    final tempFile = File('$destinationPath.tmp');

    try {
      await _downloadWithProgress(
        response,
        tempFile,
        contentLength,
        onProgress,
      );

      // Atomic rename
      tempFile.renameSync(destinationPath);
      _logger.info('Successfully downloaded to: $destinationPath');
    } catch (e) {
      // Cleanup on failure
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      rethrow;
    }
  }

  /// Downloads response body with progress tracking
  Future<void> _downloadWithProgress(
    http.StreamedResponse response,
    File destinationFile,
    int totalBytes,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final sink = destinationFile.openWrite();
    var downloadedBytes = 0;
    var lastProgressUpdate = 0;
    final startTime = DateTime.now();
    final speedSamples = <double>[];

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        // Update progress every ~1MB
        if (downloadedBytes - lastProgressUpdate >=
                _progressUpdateIntervalBytes ||
            downloadedBytes == totalBytes) {
          lastProgressUpdate = downloadedBytes;

          if (onProgress != null) {
            final elapsed = DateTime.now().difference(startTime);
            final speed = _calculateSpeed(
              downloadedBytes,
              elapsed,
              speedSamples,
            );

            final progress = downloadedBytes / totalBytes;
            final estimatedRemaining = _estimateRemaining(
              downloadedBytes,
              totalBytes,
              speed,
            );

            onProgress(
              DownloadProgress(
                progress: progress,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes,
                elapsed: elapsed,
                speedMBps: speed,
                estimatedRemaining: estimatedRemaining,
              ),
            );
          }
        }
      }
    } finally {
      await sink.close();
    }
  }

  /// Calculates download speed using rolling average
  double _calculateSpeed(
    int downloadedBytes,
    Duration elapsed,
    List<double> speedSamples,
  ) {
    if (elapsed.inMilliseconds == 0) return 0;

    // Calculate instantaneous speed in MB/s
    final speedMBps = (downloadedBytes / (1024 * 1024)) / (elapsed.inSeconds);

    // Add to samples
    speedSamples.add(speedMBps);

    // Keep only last N samples for rolling average
    if (speedSamples.length > _speedCalculationWindowSize) {
      speedSamples.removeAt(0);
    }

    // Return rolling average
    final sum = speedSamples.reduce((a, b) => a + b);
    return sum / speedSamples.length;
  }

  /// Estimates remaining download time
  Duration? _estimateRemaining(
    int downloadedBytes,
    int totalBytes,
    double speedMBps,
  ) {
    if (speedMBps <= 0 || downloadedBytes == 0) {
      return null; // Not enough data yet
    }

    final remainingBytes = totalBytes - downloadedBytes;
    final remainingMB = remainingBytes / (1024 * 1024);
    final remainingSeconds = remainingMB / speedMBps;

    return Duration(seconds: remainingSeconds.round());
  }

  /// Disposes resources
  void dispose() {
    _httpClient.close();
  }
}
