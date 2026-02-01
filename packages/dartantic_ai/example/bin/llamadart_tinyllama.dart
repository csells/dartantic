// Async I/O is appropriate for example code
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

/// Example demonstrating Llamadart with TinyLlama model.
///
/// Shows three different usage patterns:
/// 1. Simplest: Agent('llama') - auto-downloads default model
/// 2. Specific model: Agent('llama:model-name')
/// 3. Custom configuration: custom resolver and cache directory
void main() async {
  stdout.writeln('=== Llamadart TinyLlama Examples ===\n');

  // Example 1: Simplest path - Agent('llama')
  await example1SimplestPath();

  stdout.writeln('\n${"=" * 60}\n');

  // Example 2: Specific model name
  await example2SpecificModel();

  stdout.writeln('\n${"=" * 60}\n');

  // Example 3: Custom configuration
  await example3CustomConfiguration();

  stdout.writeln('\n=== All Examples Complete ===');
  exit(0);
}

/// Example 1: Simplest path using Agent('llama')
///
/// This uses all defaults:
/// - Model: tinyllama-1.1b-chat-v1.0.Q2_K.gguf (~480MB)
/// - Auto-downloads from Hugging Face on first run
/// - Caches to ./hg-model-cache/
/// - Subsequent runs use cached model instantly
Future<void> example1SimplestPath() async {
  stdout.writeln('## Example 1: Simplest Path - Agent("llama")\n');
  stdout.writeln(
    'This will auto-download TinyLlama Q2_K (~480MB) on first run',
  );
  stdout.writeln('Cache location: ./hg-model-cache/');
  stdout.writeln('Model: tinyllama-1.1b-chat-v1.0.Q2_K.gguf\n');

  // Just create an agent with 'llama' - that's it!
  final agent = Agent('llama');

  stdout.writeln('--- Loading model ---');
  final startTime = DateTime.now();

  // Single-turn chat with streaming
  const prompt = 'What is the Dart programming language in one sentence?';
  stdout.writeln('\nUser: $prompt');
  stdout.write('Assistant: ');

  await for (final chunk in agent.sendStream(prompt)) {
    stdout.write(chunk.output);
  }

  final loadTime = DateTime.now().difference(startTime);
  stdout.writeln('\n\n[Model loaded and responded in ${loadTime.inSeconds}s');
}

/// Example 2: Specify a particular model name
///
/// Use Agent('llama:model-name') to select a different quantization
/// or model from the same Hugging Face repository.
Future<void> example2SpecificModel() async {
  stdout.writeln('## Example 2: Specific Model - Agent("llama:model-name")\n');
  stdout.writeln('Specify a different quantization from the TinyLlama repo');

  // You can specify a different GGUF file from the same repo
  // For example, Q4_K_M for better quality (~669MB instead of ~480MB)
  const modelName = 'tinyllama-1.1b-chat-v1.0.Q2_K.gguf';
  final agent = Agent('llama:$modelName');

  stdout.writeln('Model: $modelName\n');

  // Multi-turn conversation to show context retention
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

/// Example 3: Custom configuration
///
/// Advanced: configure your own resolver, cache location, and options.
/// Useful when you need fine-grained control over model resolution.
Future<void> example3CustomConfiguration() async {
  stdout.writeln('## Example 3: Custom Configuration\n');
  stdout.writeln('Full control over resolver, cache, and model source');

  // Use default cache directory (same as examples 1 & 2)
  // This reuses the cached model while still demonstrating custom configuration
  const customCacheDir = './hg-model-cache';

  stdout.writeln('Cache directory: $customCacheDir\n');

  // Create custom provider with HF resolver pointing to specific repo
  final provider = LlamadartProvider(
    defaultChatOptions: const LlamadartChatOptions(
      resolver: HFModelResolver(
        repo: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
        cacheDir: customCacheDir,
      ),
      temperature: 0.7,
      logLevel: LlamaLogLevel.info, // Enable verbose logging
    ),
  );

  final agent = Agent.forProvider(
    provider,
    chatModelName: 'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
  );

  // Performance test
  stdout.writeln('--- Performance Test ---');
  const testPrompt = 'Count from 1 to 5.';

  final startTime = DateTime.now();
  stdout.writeln('Prompt: "$testPrompt"');
  stdout.write('Response: ');

  await for (final chunk in agent.sendStream(testPrompt)) {
    stdout.write(chunk.output);
  }
  stdout.write('');

  final duration = DateTime.now().difference(startTime);

  stdout.writeln('\n\nTime: ${duration.inMilliseconds}ms');
}
