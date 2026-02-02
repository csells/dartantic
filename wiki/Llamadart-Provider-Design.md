# Llamadart Provider Design

## Overview

The Llamadart provider enables local LLM inference in Dartantic using the llamadart package (llama.cpp bindings for Dart). Unlike existing cloud-based providers (OpenAI, Anthropic, Google), Llamadart runs models entirely on-device without API calls, supporting desktop, mobile, and web platforms via WebAssembly.

## Architecture

### Model Downloading and Resolution

**Problem**: Local models require explicit downloading and loading:
- Models are large files (hundreds of MB to several GB)
- Users need visibility into download progress
- Downloaded models must be organized and cached efficiently
- Model files must be resolved to absolute paths for llamadart

**Solution**: Separate downloading (HFModelDownloader) from resolution (FileModelResolver).

#### Two-Phase Workflow

1. **Download Phase**: Use `HFModelDownloader` to explicitly download models from Hugging Face
   - Rich progress tracking (%, speed, ETA)
   - Repo-based cache organization
   - Returns full absolute path to downloaded file

2. **Resolution Phase**: Use downloaded path directly or via `FileModelResolver`
   - Simple file path resolution
   - No automatic downloads
   - Fast, predictable behavior

#### HFModelDownloader - Explicit Model Downloading

**Purpose**: Download GGUF models from Hugging Face Hub with progress tracking.

**Key Features**:
- Checks if model already cached before downloading
- Rich progress callbacks with `DownloadProgress` class
- Repo-based cache structure: `{cacheDir}/{repo}/{model}.gguf`
- Atomic downloads (temp file + rename)
- Automatic retry on network failures via `RetryHttpClient`
- Auto-appends `.gguf` extension if missing
- Returns full absolute path to downloaded file

**API**:
```dart
// Create downloader with cache directory
final downloader = HFModelDownloader(cacheDir: './hf-cache');

// Check if model is cached
final cached = await downloader.isModelCached(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
);

// Download model with progress tracking
final modelPath = await downloader.downloadModel(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',  // repo
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',       // model name
  onProgress: (progress) {
    print('${(progress.progress * 100).toInt()}% - '
          '${progress.speedMBps.toStringAsFixed(1)} MB/s');
  },
);
// Returns: './hf-cache/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/tinyllama-1.1b-chat-v1.0.Q2_K.gguf'
```

**Progress Tracking**:
The `DownloadProgress` class provides comprehensive metrics:
- `progress` (double): 0.0 to 1.0
- `downloadedBytes` (int): Bytes downloaded so far
- `totalBytes` (int): Total file size
- `elapsed` (Duration): Time elapsed since download started
- `speedMBps` (double): Current download speed (MB/s, rolling 5-sample average)
- `estimatedRemaining` (Duration?): Estimated time remaining (nullable initially)

**Cache Directory Structure**:
Models are organized by repository to avoid naming conflicts:
```
hf-cache/
  TheBloke/
    TinyLlama-1.1B-Chat-v1.0-GGUF/
      tinyllama-1.1b-chat-v1.0.Q2_K.gguf
      tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf
  meta-llama/
    Llama-3.2-1B-Instruct-GGUF/
      Llama-3.2-1B-Instruct-Q4_K_M.gguf
```

This structure mirrors Hugging Face's organization and prevents conflicts between models with similar names from different repositories.

#### ModelResolver Abstraction

**Interface**: Abstract class with two operations:
1. `resolveModel(String name)` → `Future<String>` - Converts model name to loadable path/URL
2. `listModels()` → `Stream<ModelInfo>` - Discovers available models

**Implementations**:

1. **FileModelResolver** - Filesystem-based resolution (native platforms only)
   - Configured with base directory path
   - Auto-appends `.gguf` extension if missing
   - Returns full absolute path
   - Lists all `.gguf` files in directory with metadata (size, modified date)
   - **Use Case**: Resolve model names to absolute paths within a directory

2. **UrlModelResolver** - HTTP(S) URL resolution (web or remote models)
   - Configured with base URL
   - Returns fully-qualified HTTP(S) URL
   - No caching (pure streaming)
   - Listing requires server API support
   - **Use Case**: Load models directly from HTTP(S) URLs

#### Resolver Configuration

**Default Configuration**:
LlamadartProvider uses FileModelResolver with `LLAMADART_MODELS_PATH` environment variable or current directory:

```dart
// Default: Uses LLAMADART_MODELS_PATH or current directory
final agent = Agent('llama', chatModelName: 'model.gguf');

// Custom: Specify directory via environment variable
// export LLAMADART_MODELS_PATH=/path/to/models
final agent = Agent('llama', chatModelName: 'model.gguf');
```

**Custom Provider Pattern**:
For more control, create a custom provider with specific resolver:

```dart
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FileModelResolver('./my-models'),
    temperature: 0.7,
  ),
);
final agent = Agent.forProvider(provider, chatModelName: 'model.gguf');
```

**Direct Path Usage**:
Skip resolution entirely by providing the full path:

```dart
// Download first
final downloader = HFModelDownloader(cacheDir: './hf-cache');
final modelPath = await downloader.downloadModel(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
);

// Use path directly
final agent = Agent('llama', chatModelName: modelPath);
```

### Streaming Architecture

#### ChatModel Responsibility

**Core Principle**: ChatModel ONLY streams ChatResult items. NO accumulation, consolidation, or orchestration.

**Behavior**:
- Maps each token/chunk from llamadart to a ChatResult
- Each ChatResult contains a single token in a TextPart
- Yields ChatResult for each chunk
- Final chunk signals `FinishReason.stop`
- Agent/Orchestrator handles accumulation and consolidation

**Token Usage Limitation**:
- `ChatResult.usage` is always `null` - llamadart doesn't expose token counting
- The underlying llama.cpp library supports tokenization, but llamadart's Dart bindings (v0.3.0) don't expose this functionality
- This is a limitation of the llamadart package, not Dartantic
- Other providers (OpenAI, Anthropic, etc.) populate `usage` with `promptTokens` and `responseTokens`

**Rationale**: Follows Dartantic's layered architecture - ChatModel is in Provider Implementation Layer, orchestration belongs in Orchestration Layer.

#### Resource Lifecycle

**LlamaEngine Management**:
- One LlamaEngine instance per ChatModel instance
- Engine created in constructor with platform-specific backend (Native vs Web)
- Model loaded lazily on first `sendStream()` call
- **Critical**: Engine must be disposed via `dispose()` to prevent hanging processes

**Model Loading**:
- Lazy loading defers heavy operation until first request
- Resolved path determined via resolver or URI scheme detection
- First request slower (model loading), subsequent requests fast
- Loading errors propagate (exception transparency)

#### Backend Selection

llamadart supports two backends selected automatically:
- `NativeLlamaBackend`: FFI-based for desktop/mobile
- `WebLlamaBackend`: WASM-based for web browsers

Backend selected via `kIsWeb` platform detection in ChatModel constructor.

### Provider Integration

#### Provider Pattern Compliance

Follows standard Dartantic provider pattern:
- Static fields: `_logger`, `defaultBaseUrl`, `defaultApiKeyName`
- Constructor takes `defaultChatOptions` parameter (includes resolver)
- `createChatModel()` validates unsupported features, creates models with resolver
- `listModels()` delegates to resolver's `listModels()` method

#### Unsupported Features

Llamadart lacks native support for several Dartantic features:

1. **Tool Calling**: No function calling support in llama.cpp Dart wrappers
   - Throws `UnsupportedError` if tools provided
   - Future enhancement: Prompt engineering + JSON parsing

2. **Extended Thinking**: No reasoning mode support
   - Throws `UnsupportedError` if `enableThinking: true`

3. **Structured Output**: Unknown JSON mode support
   - Throws `UnsupportedError` if `outputSchema` provided
   - Future enhancement: Investigate GBNF grammar constraints

4. **Embeddings**: No embeddings mode in llamadart
   - `createEmbeddingsModel()` throws `UnsupportedError`

5. **Media Generation**: No image/video generation
   - `createMediaModel()` throws `UnsupportedError`

### Message Mapping

#### Dartantic to Llamadart Conversion

**Message Format**: Convert Dartantic ChatMessage to llamadart LlamaChatMessage

**Role Mapping**:
- `ChatMessageRole.system` → `'system'`
- `ChatMessageRole.user` → `'user'`
- `ChatMessageRole.model` → `'assistant'`

**Part Handling**:
- Extract text content only via `msg.parts.text` helper
- **CRITICAL**: Assert ThinkingPart never sent to LLM (model-generated output only)
- Skip ToolPart (tool calling not supported)
- Ignore other part types for text-only models

**Invariant**: ThinkingPart assertion MUST be checked before sending messages to prevent protocol violations.

### Error Handling

#### Exception Transparency

**Principle**: Never suppress exceptions. Let errors propagate with full context.

**ModelNotFoundException**:
- Thrown when model not found after all resolver strategies
- Includes complete list of searched locations
- Logs all search attempts for debugging
- Provides actionable error message

**Other Exceptions**:
- Model loading errors propagate unchanged
- llamadart API errors bubble up
- No try-catch blocks in examples or implementation (except for resolver fallback logic)

## Configuration

### Environment Variables

- `LLAMADART_MODELS_PATH`: Default directory for FileModelResolver
  - Used by LlamadartProvider when no custom resolver specified
  - Falls back to current working directory if not set
  - Example: `export LLAMADART_MODELS_PATH=/path/to/models`

### Provider Customization

**Default Configuration**:
- Uses FileModelResolver pointing to `LLAMADART_MODELS_PATH` or current directory
- No automatic downloads
- Simple file path resolution

**Custom Configuration**:
```dart
// Custom resolver with specific directory
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FileModelResolver('/path/to/models'),
    temperature: 0.7,
    maxTokens: 2048,
  ),
);
final agent = Agent.forProvider(provider, chatModelName: 'model.gguf');
```

**Recommended Workflow**:
```dart
// 1. Download model explicitly
final downloader = HFModelDownloader(cacheDir: './hf-cache');
final modelPath = await downloader.downloadModel(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
  onProgress: (p) => print('${(p.progress * 100).toInt()}%'),
);

// 2. Use downloaded model path directly
final agent = Agent('llama', chatModelName: modelPath);

// 3. Chat with model
await agent.send('Hello!');
```

## Platform-Specific Behavior

### Native Platforms (Desktop/Mobile)

**Capabilities**:
- Full resolver support (File, URL)
- Filesystem access via `dart:io`
- Model downloading and caching via `HFModelDownloader`
- FFI-based llamadart backend

**Typical Workflow**:
1. Download model from Hugging Face with `HFModelDownloader`
2. Use downloaded file path directly or via `FileModelResolver`
3. Cached models persist across sessions

**Example**:
```dart
// Download once
final downloader = HFModelDownloader(cacheDir: './hf-cache');
final modelPath = await downloader.downloadModel(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
);

// Use many times
final agent = Agent('llama', chatModelName: modelPath);
```

### Web Platform

**Capabilities**:
- Limited to URL resolver (no filesystem)
- WASM-based llamadart backend
- Models loaded via network (HTTP URLs)
- Asset bundles compiled into app (requires Flutter)

**Typical Workflow**:
1. Load models from HTTP(S) URLs using `UrlModelResolver`
2. Or bundle small models as assets (Flutter only)

**Limitations**:
- No filesystem access
- No `HFModelDownloader` support (no `dart:io`)
- No local file caching (relies on browser cache)
- Model downloads not persisted across sessions

**Example**:
```dart
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: UrlModelResolver('https://example.com/models'),
  ),
);
final agent = Agent.forProvider(provider, chatModelName: 'model.gguf');
```

## Testing Strategy

### Test-Driven Development

**Approach**: Write tests first, implement to pass tests

**Test Categories**:
1. **Unit Tests**: Downloader, resolvers, message mappers, individual components
2. **Integration Tests**: End-to-end scenarios with Agent
3. **Platform Tests**: Web vs native behavior

### HFModelDownloader Testing

**DownloadProgress**:
- Test value object creation and properties
- Test toString() formatting
- Test nullable `estimatedRemaining` handling

**HFModelDownloader**:
- Test `isModelCached()` returns false when not cached
- Test `isModelCached()` returns true when cached
- Test `downloadModel()` returns cached path without download if cached
- Test repo-based cache structure: `{cacheDir}/{repo}/{model}.gguf`
- Test auto-appends `.gguf` extension
- Test returns full absolute path to downloaded file
- Test progress callback receives correct metrics (integration test)
- Test cleanup on partial download failure (integration test)
- Test error on HTTP 404/network failure (integration test)

### Resolver Testing

**FileModelResolver**:
- Test path resolution with various base directories
- Test `.gguf` extension appending
- Test file existence checking
- Test model listing with metadata

**UrlModelResolver**:
- Test URL construction with base URL
- Test `.gguf` extension appending

### Message Mapper Testing

- Test role mapping
- Test ThinkingPart assertion (should throw)
- Test ToolPart filtering
- Test text extraction from various part types

### ChatModel Testing

- Test lazy model loading on first request
- Test resolver delegation
- Test streaming (one ChatResult per chunk)
- Test disposal lifecycle

### Provider Testing

- Test createChatModel with default resolver
- Test createChatModel with custom resolver
- Test listModels() delegation
- Test unsupported feature errors

## Known Limitations

### Backend Initialization Logs Cannot Be Suppressed

**Limitation**: Metal/GPU backend initialization logs (~28 lines) always appear on first model load, even with `logLevel: LlamaLogLevel.none`.

**Root Cause**: llamadart's worker isolate architecture performs backend initialization (`ggml_backend_load_all()`, `llama_backend_init()`) before the logging configuration message can be processed. The initialization happens in `llamaWorkerEntry()` before the message loop starts listening for `LogLevelRequest`.

**Impact**:
- First agent/model initialization outputs unavoidable Metal/GPU logs to stderr
- Subsequent operations are properly silent when `logLevel: none`
- Model loading logs ARE successfully suppressed
- Only affects aesthetic output, not functionality

**Current Behavior**:
- **Backend initialization**: ~28 lines of Metal logs (one-time, unavoidable)
- **Model loading**: Silent ✅ (successfully suppressed via `ModelParams.logLevel`)
- **Inference**: Silent ✅

**Workaround**: None available without modifying llamadart package.

**Upstream Issue**: Requires llamadart changes to default logging to disabled or configure logging before backend initialization. Potential solutions:
1. Set no-op log callback BEFORE `ggml_backend_load_all()` in `llamaWorkerEntry()`
2. Accept log level as parameter during isolate spawn
3. Default to logging disabled, enable on request

### No Token Usage Statistics

**Limitation**: `ChatResult.usage` is always `null` when using llamadart.

**Reason**: The llamadart Dart package (v0.3.0) doesn't expose token counting from the underlying llama.cpp library. While llama.cpp supports tokenization and token counting, these capabilities aren't accessible through llamadart's current API.

**Impact**:
- Cannot track prompt tokens (input)
- Cannot track response tokens (output)
- Cannot calculate total tokens or estimate costs
- Differs from other Dartantic providers (OpenAI, Anthropic, Google) which all provide token usage

**Workaround**: None available without modifying llamadart package.

**Upstream Issue**: llamadart should expose llama.cpp's tokenization methods. Potential API additions:
1. `LlamaTokenizer.countTokens(String text)` → `int`
2. `LlamaEngine.getTokenUsage()` → `{promptTokens: int, responseTokens: int}`
3. Populate token counts in generation response metadata

### No Tool Calling Support

**Limitation**: Tool calling not supported in current implementation.

**Reason**: llamadart doesn't have native tool calling support like cloud providers. While some GGUF models (e.g., Functionary, Hermes) support function calling via prompt engineering, this requires custom orchestration and llamadart doesn't expose the necessary APIs for reliable tool calling.

**Impact**:
- Cannot use Dartantic's tool calling features with local models
- Agent throws `UnsupportedError` if tools are provided
- Limits usefulness for agentic workflows

**Workaround**: Could be implemented via prompt engineering (see Future Enhancements), but requires significant effort and model-specific templates.

**Upstream Issue**: llamadart should provide APIs to support tool calling. Potential additions:
1. **Chat Template Support**: Expose tool/function calling templates from GGUF models
2. **Grammar Constraints**: Allow GBNF grammars to enforce tool call JSON format
3. **Tool Schema Injection**: API to inject tool definitions into system prompt
4. **Response Parsing**: Helpers to parse tool calls from model responses

### No Structured Output Support

**Limitation**: `outputSchema` parameter throws `UnsupportedError`.

**Reason**: Would require grammar constraints (GBNF) or JSON mode, which aren't exposed in llamadart's current API. llama.cpp supports GBNF (Grammar-Based Natural Language Format) for constrained output, but llamadart v0.3.0 doesn't provide access to this feature.

**Impact**:
- Cannot enforce JSON schemas on model output
- Cannot use Dartantic's typed output features with local models
- Must parse and validate unstructured text responses manually

**Workaround**: None available without modifying llamadart package.

**Upstream Issue**: llamadart should expose llama.cpp's GBNF grammar support. Potential API additions:
1. **Grammar API**: `ModelParams.grammar` or `GenerationParams.grammar` to accept GBNF string
2. **Schema to GBNF Converter**: Helper to convert JSON schemas to GBNF format
3. **JSON Mode**: Simple boolean flag for strict JSON output (built-in GBNF grammar)
4. **Validation**: Ensure generated output conforms to grammar

### No Extended Thinking

**Limitation**: `enableThinking` parameter throws `UnsupportedError`.

**Reason**: Extended reasoning is a cloud provider feature not applicable to local GGUF models.

**Impact**: Cannot use Dartantic's thinking mode with local models.

**Upstream Issue**: Not applicable - this is a design choice, not a llamadart limitation.

## Migration Guide

### Changes from Previous Architecture

**What Changed**:
- **Removed**: `HFModelResolver` (automatic Hugging Face downloads)
- **Removed**: `FallbackResolver` (multi-strategy resolution)
- **Added**: `HFModelDownloader` (explicit download utility)
- **Simplified**: Only `FileModelResolver` and `UrlModelResolver` remain

**Why the Change**:
- Explicit downloads provide better user experience (progress visibility, control)
- Simpler architecture with clear separation of concerns
- No automatic network calls hidden in model resolution
- Repo-based cache structure prevents naming conflicts

### Migrating Existing Code

#### Before: Automatic Download via FallbackResolver

```dart
// OLD: Automatic download hidden in resolver
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FallbackResolver(
      fileBasePath: './models',
      hfCacheDir: './hf-cache',
    ),
  ),
);
// This would automatically download from HF if model not found locally
final agent = Agent.forProvider(
  provider,
  chatModelName: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
);
```

#### After: Explicit Download with HFModelDownloader

```dart
// NEW: Explicit download with progress tracking
final downloader = HFModelDownloader(cacheDir: './hf-cache');
final modelPath = await downloader.downloadModel(
  'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
  'tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
  onProgress: (p) {
    print('${(p.progress * 100).toInt()}% - ${p.speedMBps.toStringAsFixed(1)} MB/s');
  },
);

// Use downloaded model path directly (no resolver needed)
final agent = Agent('llama', chatModelName: modelPath);

// Or use FileModelResolver if you prefer relative paths
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FileModelResolver('./hf-cache'),
  ),
);
final agent = Agent.forProvider(
  provider,
  chatModelName: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/tinyllama-1.1b-chat-v1.0.Q2_K.gguf',
);
```

### What Still Works

✅ **Local file paths**: No change if you're already using local files

```dart
// Still works exactly the same
final agent = Agent('llama', chatModelName: '/absolute/path/model.gguf');
```

✅ **FileModelResolver**: Still works for relative paths

```dart
// Still works exactly the same
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FileModelResolver('./models'),
  ),
);
final agent = Agent.forProvider(provider, chatModelName: 'model.gguf');
```

✅ **UrlModelResolver**: Still works for HTTP(S) URLs

```dart
// Still works exactly the same
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: UrlModelResolver('https://example.com/models'),
  ),
);
final agent = Agent.forProvider(provider, chatModelName: 'model.gguf');
```

✅ **LLAMADART_MODELS_PATH environment variable**: Still works as before

```bash
export LLAMADART_MODELS_PATH=/path/to/models
```

### What Requires Changes

❌ **Using HFModelResolver**: Replace with explicit download via `HFModelDownloader`

❌ **Using FallbackResolver**: Replace with explicit download + direct path usage or `FileModelResolver`

❌ **Relying on automatic downloads**: Download models explicitly before use

### Migration Checklist

1. **Install latest version** with `HFModelDownloader` support
2. **Identify automatic download usage**: Search codebase for `HFModelResolver` or `FallbackResolver`
3. **Add explicit download step**: Use `HFModelDownloader` to download models upfront
4. **Update model paths**: Use returned absolute path from downloader or relative path with `FileModelResolver`
5. **Test download progress**: Verify progress callbacks work as expected
6. **Update documentation**: Document where downloaded models are cached

## Future Enhancements

**Note**: Many enhancements require upstream changes to the llamadart package. See "Known Limitations" section for tracked issues.

### Suppress Backend Initialization Logs (Requires Upstream)

**Status**: Blocked by llamadart architecture

**Approach**:
- Submit PR to llamadart to set no-op log callback before backend initialization
- OR: Add isolate spawn parameter for initial log level
- OR: Default to logging disabled in llamadart worker

**Benefit**: Truly silent operation from first use, cleaner CLI output

### Tool Calling Support (Requires Upstream)

**Status**: Blocked by missing llamadart APIs

**Short-term Approach** (without llamadart changes):
- Serialize tool schemas to JSON in system prompt
- Parse model's JSON responses for tool calls
- Requires models with function calling support (e.g., Functionary, Hermes)
- Implement custom orchestrator (similar to Google's double agent pattern)
- Limitation: Unreliable, model-specific, no grammar enforcement

**Long-term Approach** (with llamadart changes):
- Use llamadart's GBNF grammar API to enforce tool call format
- Leverage model's built-in function calling templates
- Reliable parsing via grammar constraints
- See "Upstream Issue" in "No Tool Calling Support" limitation

### Structured Output via GBNF (Requires Upstream)

**Status**: Blocked by missing llamadart GBNF API

**Approach**:
- Wait for llamadart to expose llama.cpp's GBNF grammar support
- Generate GBNF grammar from JSON schema
- Enforce structured output at generation time
- Validate conformance

**Benefit**: Type-safe model outputs, reliable parsing, works with any model

### Token Usage Statistics (Requires Upstream)

**Status**: Blocked by missing llamadart tokenization API

**Approach**:
- Wait for llamadart to expose llama.cpp's tokenization methods
- Populate `ChatResult.usage` with prompt and response token counts
- Enable cost tracking and monitoring for local models

**Benefit**: Parity with cloud providers, usage analytics

### Embeddings Support

**Approach**:
- Investigate if llama.cpp supports embeddings mode
- Implement `createEmbeddingsModel()` if supported
- Use same resolver pattern for model loading

### LoRA Adapter Support

**Approach**:
- Expose llamadart's dynamic LoRA loading
- Add adapter configuration to LlamadartChatOptions
- Support runtime adapter switching

### Advanced Generation Parameters

**Approach**:
- Expose context size, threads, batch size
- Add to LlamadartChatOptions as discovered in llamadart API
- Document performance implications

### Flutter Asset Bundle Support

**Context**:
- Asset bundles (`asset://` URIs) only work with Flutter framework
- Current implementation is pure Dart and doesn't depend on Flutter
- AssetModelResolver requires Flutter's asset system for bundle access

**Approach**:
- Create separate Flutter-specific package (e.g., `dartantic_flutter`)
- Implement AssetModelResolver using Flutter's `rootBundle` API
- Add asset verification using `rootBundle.load()` to check existence
- Support asset listing via `AssetManifest.json` parsing
- Update FallbackResolver to include asset checking as first strategy
- Document asset bundling in `pubspec.yaml` for Flutter apps

**Usage Pattern**:
```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/models/tinyllama.gguf
```

```dart
// Flutter app code
final provider = LlamadartProvider(
  defaultChatOptions: LlamadartChatOptions(
    resolver: FallbackResolver(
      assetBasePath: 'assets/models',
      fileBasePath: '/fallback/path',
    ),
  ),
);
```

## References

- [llamadart package](https://pub.dev/packages/llamadart)
- [llama.cpp](https://github.com/ggml-org/llama.cpp)
- [GGUF format specification](https://github.com/ggml-org/ggml/blob/master/docs/gguf.md)
- Dartantic Provider Implementation Guide (`wiki/Provider-Implementation-Guide.md`)
- Dartantic Architecture Overview (`wiki/Home.md`)
