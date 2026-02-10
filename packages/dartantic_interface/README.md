# Welcome to dartantic_interface!

This repo contains the implementation for the
[dartantic_interface](https://pub.dev/packages/dartantic_interface) package. It
forms the base set of interfaces used to implement providers and chat and
embeddings models for [dartantic_ai](https://pub.dev/packages/dartantic_ai).

By implementing a custom provider based on dartantic_interface, you do not need
to depend on all of dartantic_ai. Likewise, your provider does not need to be
multi-platform or support wasm, as is the requirement for providers built into
dartantic_ai.

## Core Types

This package re-exports core message and part types from
[genai_primitives](https://pub.dev/packages/genai_primitives):

- `ChatMessage`, `ChatMessageRole` - Conversation messages
- `Part`, `TextPart`, `DataPart`, `LinkPart`, `ThinkingPart` - Message content
- `ToolPart`, `ToolPartKind` - Tool calls and results
- `ToolDefinition` - Tool schema definitions

Schema construction is provided by
[json_schema_builder](https://pub.dev/packages/json_schema_builder). Use the `S`
builder class:

```dart
import 'package:dartantic_interface/dartantic_interface.dart';

final schema = S.object(properties: {
  'name': S.string(description: 'User name'),
  'age': S.integer(minimum: 0),
});
```
