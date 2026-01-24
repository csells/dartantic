## 3.0.0

### Breaking Change: Migrated to genai_primitives Types

Core message and part types are now provided by the `genai_primitives` package
and re-exported from `dartantic_interface`. This provides better
interoperability with other GenAI tooling in the Dart ecosystem.

Types re-exported from `genai_primitives`:
- `ChatMessage`, `ChatMessageRole`
- `Part`, `TextPart`, `DataPart`, `LinkPart`, `ThinkingPart`
- `ToolPart`, `ToolPartKind`
- `ToolDefinition`

### Breaking Change: Migrated to json_schema_builder for Schemas

The `Schema` type is now provided by the `json_schema_builder` package. Use the
`S` builder class for constructing schemas:

```dart
import 'package:dartantic_interface/dartantic_interface.dart';

// Build schemas with S.*
final schema = S.object(properties: {
  'name': S.string(description: 'User name'),
  'age': S.integer(minimum: 0),
});
```

### New: ThinkingPart for Extended Reasoning

Added `ThinkingPart` to represent extended thinking/reasoning content from LLMs.
This provides a unified representation across providers that support thinking
(OpenAI Responses, Anthropic, Google).

### New Convenience Extensions

Added `MessagePartHelpers` extension on `Iterable<Part>`:
- `thinkingParts` - extracts all `ThinkingPart` instances
- `thinkingText` - concatenates all thinking text

## 2.0.0

- **BREAKING**: Removed `ProviderCaps` enum from the interface. Provider
  capabilities were only meaningful for testing default models and provided no
  provider-wide guarantees. Capability filtering for tests is now handled via
  `ProviderTestCaps` in `dartantic_ai`'s test infrastructure. Consider the
  `Provider.listModels` method for run-time model details, e.g. chat, embedding,
  media, etc.
- Removed `caps` field from `Provider` base class.

## 1.3.0

- introduced media generation primitives (`MediaGenerationModel`,
  `MediaGenerationResult`, `MediaGenerationModelResult`, and
  `MediaGenerationModelOptions`)
- extended `Provider` with media factory support and added
  `ProviderCaps.mediaGeneration`
- added `ModelKind.media` for provider defaults and discovery

## 1.2.0

- added optional 'thinking' field to ChatResult for enhanced reasoning output
- updated Provider to support thinking feature toggle

## 1.1.0

- ProviderCaps.vision => ProviderCaps.chatVision to tighten the meaning

## 1.0.5

- made usage nullable for when there is no usage.

## 1.0.4

- added `ProviderCaps.thinking`

## 1.0.3

- remove custom lint dependency

## 1.0.2

- fixed a compilation error on the web

## 1.0.1

- downgrading meta for wider compatibility

## 1.0.0

- initial release
