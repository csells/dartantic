// Async I/O is intentional to avoid blocking the event loop
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:path/path.dart' as path;

/// Exception thrown when a model cannot be resolved
class ModelNotFoundException implements Exception {
  /// Creates a [ModelNotFoundException]
  const ModelNotFoundException(this.message, {required this.searchedLocations});

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
