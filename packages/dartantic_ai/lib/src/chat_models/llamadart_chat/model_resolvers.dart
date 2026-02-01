// Async I/O is intentional to avoid blocking the event loop
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import '../../platform/platform.dart';

/// Platform detection - check if running on web
/// On web, identical(0, 0.0) returns true; on VM it returns false
const bool kIsWeb = identical(0, 0.0);

/// Exception thrown when a model cannot be resolved
class ModelNotFoundException implements Exception {
  /// Creates a [ModelNotFoundException]
  const ModelNotFoundException(
    this.message, {
    required this.searchedLocations,
  });

  /// Error message
  final String message;

  /// List of locations that were searched
  final List<String> searchedLocations;

  @override
  String toString() => 'ModelNotFoundException: $message';
}

/// Abstract base class for model resolvers
abstract class ModelResolver {
  /// Creates a [ModelResolver]
  const ModelResolver();

  /// Resolves a model name to a full path/URL that llamadart can load
  /// Adds .gguf extension if not present
  Future<String> resolveModel(String name);

  /// Lists all available models this resolver knows about
  Stream<ModelInfo> listModels();
}

/// Resolves models from the local filesystem
class FileModelResolver extends ModelResolver {
  /// Creates a [FileModelResolver] with the given base directory
  const FileModelResolver(this.baseDirectory);

  /// Base directory where models are stored
  final String baseDirectory;

  @override
  Future<String> resolveModel(String name) async {
    final fileName = name.endsWith('.gguf') ? name : '$name.gguf';
    final fullPath = path.join(baseDirectory, fileName);

    if (await File(fullPath).exists()) {
      return fullPath;
    }

    throw ModelNotFoundException(
      'Model "$name" not found in $baseDirectory',
      searchedLocations: [fullPath],
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    final dir = Directory(baseDirectory);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.gguf')) {
        final stat = await entity.stat();
        yield ModelInfo(
          name: entity.path, // Full path for direct use
          providerName: 'llamadart',
          kinds: {ModelKind.chat},
          displayName: path.basename(entity.path),
          description: 'Local GGUF model',
          extra: {
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
          },
        );
      }
    }
  }
}


/// Resolves models from HTTP(S) URLs
class UrlModelResolver extends ModelResolver {
  /// Creates a [UrlModelResolver] with the given base URL
  const UrlModelResolver(this.baseUrl);

  /// Base URL where models are hosted
  final String baseUrl;

  @override
  Future<String> resolveModel(String name) async {
    final fileName = name.endsWith('.gguf') ? name : '$name.gguf';
    return '$baseUrl/$fileName';
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // URL-based listing would require server API support
    // Return empty stream for now
  }
}

/// Resolves models from Hugging Face Hub
class HFModelResolver extends ModelResolver {
  /// Creates an [HFModelResolver]
  const HFModelResolver({
    required this.repo,
    this.revision = 'main',
    this.cacheDir,
  });

  /// Hugging Face repository (e.g., 'meta-llama/Llama-2-7b-chat')
  final String repo;

  /// Repository revision/branch
  final String revision;

  /// Directory where downloads are cached (native only)
  final String? cacheDir;

  static final Logger _logger =
      Logger('dartantic.chat.models.llamadart.hf');

  @override
  Future<String> resolveModel(String name) async {
    final fileName = name.endsWith('.gguf') ? name : '$name.gguf';

    // Check cache first (native platforms only)
    final cache = cacheDir;
    if (cache != null && !kIsWeb) {
      final cachedPath = path.join(cache, fileName);
      if (await File(cachedPath).exists()) {
        _logger.info('Using cached model: $cachedPath');
        return cachedPath;
      }
    }

    // For web, return hf:// URI for llamadart to handle
    if (kIsWeb) {
      return 'hf://$repo/$fileName';
    }

    // For native, download from HF Hub and cache
    if (cache == null) {
      throw StateError(
        'cacheDir is required for downloading models from Hugging Face',
      );
    }

    return _downloadFromHF(fileName, cache);
  }

  Future<String> _downloadFromHF(String fileName, String cacheDir) async {
    // Construct HF Hub URL
    final url =
        'https://huggingface.co/$repo/resolve/$revision/$fileName';
    _logger.info('Downloading model from Hugging Face: $url');

    final client = http.Client();
    try {
      // Make request
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download model from Hugging Face: '
          'HTTP ${response.statusCode}',
        );
      }

      // Ensure cache directory exists
      final dir = Directory(cacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Download to file
      final filePath = path.join(cacheDir, fileName);
      final file = File(filePath);
      final sink = file.openWrite();

      var downloadedBytes = 0;
      final contentLength = response.contentLength ?? 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        // Log progress every 10MB
        if (downloadedBytes % (10 * 1024 * 1024) < chunk.length) {
          if (contentLength > 0) {
            final progress =
                (downloadedBytes / contentLength * 100).toStringAsFixed(1);
            _logger.info(
              'Download progress: $progress% '
              '($downloadedBytes / $contentLength bytes)',
            );
          } else {
            _logger.info('Downloaded: $downloadedBytes bytes');
          }
        }
      }

      await sink.close();

      _logger.info(
        'Successfully downloaded model to: $filePath '
        '($downloadedBytes bytes)',
      );
      return filePath;
    } finally {
      client.close();
    }
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // HF API query not yet implemented
  }
}

/// Multi-strategy resolver that tries multiple sources in order
class FallbackResolver extends ModelResolver {
  /// Creates a [FallbackResolver]
  FallbackResolver({
    this.fileBasePath,
    this.hfCacheDir,
    this.hfRepo = 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  });

  /// Base path for files (defaults to LLAMADART_MODELS_PATH or cwd)
  final String? fileBasePath;

  /// Cache directory for HF downloads
  final String? hfCacheDir;

  /// Hugging Face repository for model downloads
  final String hfRepo;

  late final FileModelResolver? _fileResolver = _createFileResolver();

  late final HFModelResolver? _hfResolver = _createHFResolver();

  static final Logger _logger =
      Logger('dartantic.chat.models.llamadart.resolver');

  FileModelResolver? _createFileResolver() {
    if (kIsWeb) return null;

    final basePath =
        fileBasePath ?? tryGetEnv('LLAMADART_MODELS_PATH') ?? _getCurrentDir();
    return FileModelResolver(basePath);
  }

  String _getCurrentDir() {
    try {
      return Directory.current.path;
    } on Exception {
      return '.';
    }
  }

  HFModelResolver? _createHFResolver() {
    if (kIsWeb) return null;

    final cacheDir =
        hfCacheDir ?? fileBasePath ?? tryGetEnv('LLAMADART_MODELS_PATH');
    return cacheDir != null
        ? HFModelResolver(repo: hfRepo, cacheDir: cacheDir)
        : null;
  }

  @override
  Future<String> resolveModel(String name) async {
    final fileName = name.endsWith('.gguf') ? name : '$name.gguf';
    final searchedLocations = <String>[];

    _logger.info('Resolving model "$name" with FallbackResolver');

    // 1. Check files (non-web only)
    final fileResolver = _fileResolver;
    if (fileResolver != null) {
      try {
        _logger.fine('Checking files...');
        final filePath = await fileResolver.resolveModel(fileName);
        searchedLocations.add(filePath);
        _logger.info('Found model in files: $filePath');
        return filePath;
      } on Exception catch (e) {
        searchedLocations
            .add('${fileResolver.baseDirectory}/$fileName (not found)');
        _logger.fine('Not found in files: $e');
      }
    }

    // 2. Try Hugging Face download (native only)
    final hfResolver = _hfResolver;
    if (hfResolver != null) {
      try {
        _logger.fine('Attempting Hugging Face download for: $name');
        final hfPath = await hfResolver.resolveModel(fileName);
        searchedLocations.add('hf://${hfResolver.repo}/$fileName (downloaded)');
        _logger.info('Downloaded model from Hugging Face to: $hfPath');
        return hfPath;
      } on Exception catch (e) {
        _logger.fine('Hugging Face download failed: $e');
        searchedLocations
            .add('hf://${hfResolver.repo}/$fileName (download failed: $e)');
      }
    }

    _logger.severe('Model "$name" not found in any location');
    final locationsList =
        searchedLocations.map((l) => '  - $l').join('\n');
    throw ModelNotFoundException(
      'Model "$name" not found after searching:\n$locationsList',
      searchedLocations: searchedLocations,
    );
  }

  @override
  Stream<ModelInfo> listModels() async* {
    // List from file resolver if available
    final fileResolver = _fileResolver;
    if (fileResolver != null) {
      await for (final model in fileResolver.listModels()) {
        yield model;
      }
    }

    // Could also list from assets and HF if implemented
  }
}
