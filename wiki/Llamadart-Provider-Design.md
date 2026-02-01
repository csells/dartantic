# Llamadart Provider Design

## Overview

The Llamadart provider enables local LLM inference in Dartantic using the llamadart package (llama.cpp bindings for Dart). Unlike existing cloud-based providers (OpenAI, Anthropic, Google), Llamadart runs models entirely on-device without API calls, supporting desktop, mobile, and web platforms via WebAssembly.

## Architecture

### Model Resolution via URI Schemes and Resolvers

**Problem**: Local models require different loading strategies across platforms:
- Native platforms (desktop/mobile): Load from filesystem paths
- Web platforms: Load from URLs, assets, or Hugging Face Hub
- Users need flexibility: file paths, asset bundles, remote URLs, or automatic discovery

**Solution**: ModelResolver abstraction with multiple implementations and URI scheme support.

#### URI Scheme Support

Model names can be specified as URIs with platform-specific schemes:

- `file:///absolute/path/model.gguf` - Direct filesystem path (native only)
- `https://example.com/models/llama.gguf` - HTTP(S) URL (web or download)
- `hf://org/repo/model.gguf` - Hugging Face Hub (web or cached download)
- Plain name: `my-model` - Resolved via ModelResolver chain

**Note**: Asset bundle support (`asset://` URIs) requires Flutter framework integration and is planned for a separate Flutter-specific package.

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

2. **UrlModelResolver** - HTTP(S) URL resolution (web or remote models)
   - Configured with base URL
   - Returns fully-qualified HTTP(S) URL
   - No caching (pure streaming)
   - Listing requires server API support

3. **HFModelResolver** - Hugging Face Hub integration
   - Configured with repo name (e.g., `meta-llama/Llama-2-7b-chat`)
   - Checks local cache first (native platforms)
   - Downloads and caches models to file resolver's location
   - On web: Returns `hf://` URI for llamadart's WebLlamaBackend
   - On native: Downloads via HF API and caches to filesystem

4. **FallbackResolver** - Multi-strategy resolver (default)
   - Tries multiple strategies in order until success
   - Strategy sequence:
     1. **FileResolver**: Check `LLAMADART_MODELS_PATH` env var or current directory (native only)
     2. **HFModelResolver**: Download from Hugging Face Hub and cache (native only)
   - Auto-appends `.gguf` extension at each step
   - Logs all search locations for debugging
   - Throws `ModelNotFoundException` with complete list of searched locations

#### Resolver Configuration

**Three levels of configuration** (from most specific to least):

1. **Per-request**: `LlamadartChatOptions.resolver` - Override resolver for single request
2. **Provider-level**: `LlamadartProvider(defaultChatOptions: LlamadartChatOptions(resolver: ...))` - Provider-wide default
3. **Global fallback**: `FallbackResolver` - Used when no resolver specified

**Custom provider pattern**:
Users create tailored providers with specific resolvers and pass to `Agent.forProvider()`:
- Define resolver with base paths
- Set other defaults (temperature, etc.)
- Create provider with `defaultChatOptions`
- Pass provider to Agent

#### Platform Detection

Platform-specific behavior uses `kIsWeb` constant:
- Web platforms: Skip file operations, use URL/asset/HF resolvers only
- Native platforms: Full resolver support including filesystem access

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
  - Used by FallbackResolver if no `fileBasePath` specified
  - Falls back to current working directory if not set

### Provider Customization

**Default Configuration**:
- Uses FallbackResolver with standard search sequence
- Asset base path: `assets/models`
- File base path: from `LLAMADART_MODELS_PATH` or current directory

**Custom Configuration**:
- Create `LlamadartChatOptions` with custom resolver
- Pass via `defaultChatOptions` to provider constructor
- Use `Agent.forProvider(provider)` to create agent

## Platform-Specific Behavior

### Native Platforms (Desktop/Mobile)

**Capabilities**:
- Full resolver support (File, Asset, URL, HF)
- Filesystem access via `dart:io`
- Model caching to filesystem
- FFI-based llamadart backend

**Typical Flow**:
1. Check assets first
2. Check files in `LLAMADART_MODELS_PATH`
3. Download from Hugging Face and cache

### Web Platform

**Capabilities**:
- Limited to URL, Asset, and HF resolvers (no filesystem)
- WASM-based llamadart backend
- Models loaded via network (HTTP, HF Hub)
- Asset bundles compiled into app

**Typical Flow**:
1. Check assets (bundled with app)
2. Fetch from URL or Hugging Face

**Limitations**:
- No filesystem access
- No local file caching (relies on browser cache)
- Model downloads not persisted across sessions

## Testing Strategy

### Test-Driven Development

**Approach**: Write tests first, implement to pass tests

**Test Categories**:
1. **Unit Tests**: Resolvers, message mappers, individual components
2. **Integration Tests**: End-to-end scenarios with Agent
3. **Platform Tests**: Web vs native behavior

### Resolver Testing

**FileModelResolver**:
- Test path resolution with various base directories
- Test `.gguf` extension appending
- Test file existence checking
- Test model listing with metadata

**FallbackResolver**:
- Test search sequence (assets → files → HF)
- Test logging of all search locations
- Test ModelNotFoundException with complete location list
- Test platform-specific behavior (web vs native)

### Message Mapper Testing

- Test role mapping
- Test ThinkingPart assertion (should throw)
- Test ToolPart filtering
- Test text extraction from various part types

### ChatModel Testing

- Test lazy model loading on first request
- Test URI scheme resolution
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

### Hugging Face Download Implementation

**Approach**:
- Implement HF API integration for downloading GGUF models
- Add progress tracking for large downloads
- Cache models to `LLAMADART_MODELS_PATH` for reuse
- Support model sharding (large models split into chunks)

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
