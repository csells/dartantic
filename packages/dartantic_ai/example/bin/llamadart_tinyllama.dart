// Async I/O is appropriate for example code
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

/// Example demonstrating Llamadart with explicit model downloading.
///
/// This example shows:
/// 0. Downloading a model from Hugging Face with progress tracking
/// 1. Using the downloaded model with Agent
/// 2. Multi-turn conversation
/// 3. Custom provider configuration
void main() async {
  stdout.writeln('=== Llamadart TinyLlama Examples ===\n');

  // Example 0: Download model with progress
  // ignore: unused_local_variable
  final modelPath = await example0DownloadModel();
  stdout.writeln('\n${"=" * 60}\n');

  // Example 1: Simplest path - use downloaded model
  await example1SimplestPath(modelPath);
  stdout.writeln('\n${"=" * 60}\n');

  // Example 2: Multi-turn conversationar
  await example2MultiTurnChat(modelPath);
  stdout.writeln('\n${"=" * 60}\n');

  // Example 3: Custom configuration
  await example3CustomConfiguration(modelPath);
  stdout.writeln('\n=== All Examples Complete ===');

  exit(0);
}

/// Example 0: Download model with progress tracking
Future<String> example0DownloadModel() async {
  stdout.writeln('## Example 0: Download Model with Progress\n');

  final downloader = HFModelDownloader(cacheDir: './hf-model-cache');
  const repo = 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF';
  const model = 'tinyllama-1.1b-chat-v1.0.Q2_K.gguf';

  stdout.writeln('Repository: $repo');
  stdout.writeln('Model: $model');
  stdout.writeln('Cache: ./hf-model-cache/\n');

  // Check cache status
  final isCached = await downloader.isModelCached(repo, model);

  if (isCached) {
    stdout.writeln('✓ Model already cached');
    stdout.writeln(
      '  To force re-download, set force: true in downloadModel()',
    );
    // Return cached path without downloading
    final modelPath = await downloader.downloadModel(repo, model);
    return modelPath;
  }

  // Model not cached - download it
  stdout.writeln('Downloading model (~480MB)...');
  var lastPct = -1;

  final modelPath = await downloader.downloadModel(
    repo,
    model,
    onProgress: (p) {
      final pct = (p.progress * 100).toInt();
      // Only show progress every 10%
      if (pct >= lastPct + 10 || pct == 100) {
        lastPct = pct;
        final mb = (p.downloadedBytes / (1024 * 1024)).toStringAsFixed(0);
        final totalMb = (p.totalBytes / (1024 * 1024)).toStringAsFixed(0);
        final speed = p.speedMBps.toStringAsFixed(1);
        final etaMin = (p.estimatedRemaining?.inSeconds ?? 0) ~/ 60;
        final etaSec = (p.estimatedRemaining?.inSeconds ?? 0) % 60;
        stdout.writeln(
          '$pct% ($mb/$totalMb MB) - $speed MB/s - ETA: ${etaMin}m ${etaSec}s',
        );
      }
    },
  );

  stdout.writeln('✓ Downloaded to: $modelPath');
  return modelPath;
}

/// Example 1: Simplest path using downloaded model
Future<void> example1SimplestPath(String modelPath) async {
  stdout.writeln('## Example 1: Using Downloaded Model\n');
  stdout.writeln('Model path: $modelPath\n');

  // Create agent with downloaded model
  final provider = LlamadartProvider(
    defaultChatOptions: LlamadartChatOptions(
      resolver: FileModelResolver(File(modelPath).parent.parent.path),
    ),
  );
  final relativePath = modelPath.substring(
    File(modelPath).parent.parent.path.length + 1,
  );
  final agent = Agent.forProvider(provider, chatModelName: relativePath);

  stdout.writeln('--- Single-turn chat ---');
  const prompt = 'What is the Dart programming language in one sentence?';
  stdout.writeln('\nUser: $prompt');
  stdout.write('Assistant: ');

  await for (final chunk in agent.sendStream(prompt)) {
    stdout.write(chunk.output);
  }
  stdout.writeln();
}

/// Example 2: Multi-turn conversation
Future<void> example2MultiTurnChat(String modelPath) async {
  stdout.writeln('## Example 2: Multi-Turn Conversation\n');

  final provider = LlamadartProvider(
    defaultChatOptions: LlamadartChatOptions(
      resolver: FileModelResolver(File(modelPath).parent.parent.path),
    ),
  );
  final relativePath = modelPath.substring(
    File(modelPath).parent.parent.path.length + 1,
  );
  final agent = Agent.forProvider(provider, chatModelName: relativePath);
  final chat = Chat(
    agent,
    history: [ChatMessage.system('You are a concise AI assistant.')],
  );

  // Turn 1
  var prompt = 'What are the three primary colors?';
  stdout.writeln('User: $prompt');
  stdout.write('Assistant: ');
  await for (final chunk in chat.sendStream(prompt)) {
    stdout.write(chunk.output);
  }
  stdout.writeln();

  // Turn 2 - references context
  prompt = 'Mix the first two you mentioned. What do you get?';
  stdout.writeln('\nUser: $prompt');
  stdout.write('Assistant: ');
  await for (final chunk in chat.sendStream(prompt)) {
    stdout.write(chunk.output);
  }
  stdout.writeln();
}

/// Example 3: Custom configuration with FileModelResolver
Future<void> example3CustomConfiguration(String modelPath) async {
  stdout.writeln('## Example 3: Custom Configuration\n');
  stdout.writeln('Using FileModelResolver with custom cache directory');

  // Extract cache directory from model path
  final cacheDir = File(modelPath).parent.parent.path;

  // Create custom provider with FileModelResolver
  final provider = LlamadartProvider(
    defaultChatOptions: LlamadartChatOptions(
      resolver: FileModelResolver(cacheDir),
      temperature: 0.7,
      // logLevel: LlamaLogLevel.info, // Enable for verbose logging
    ),
  );

  // Use the model name relative to cache directory
  final relativePath = modelPath.substring(cacheDir.length + 1);
  final agent = Agent.forProvider(provider, chatModelName: relativePath);

  stdout.writeln('Cache directory: $cacheDir');
  stdout.writeln('Relative path: $relativePath\n');

  // Performance test
  stdout.writeln('--- Performance Test ---');
  const prompt = 'Give me a haiku about AI assistants.';

  final startTime = DateTime.now();
  stdout.writeln('Prompt: "$prompt"');
  stdout.write('Response: ');

  await for (final chunk in agent.sendStream(prompt)) {
    stdout.write(chunk.output);
  }
  stdout.writeln();

  final duration = DateTime.now().difference(startTime);
  stdout.writeln('\nTime: ${duration.inMilliseconds}ms');
}
