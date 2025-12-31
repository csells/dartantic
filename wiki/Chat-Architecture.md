# Chat Architecture

## Overview
The `dartantic_chat` package provides a Flutter UI layer for building AI-powered chat experiences on top of the `dartantic_ai` framework. It handles user input (text, images, voice), message display, and streaming responses.

---

## Core Components

### AgentChatView
The main widget that renders a complete chat interface.

```dart
AgentChatView(
  provider: DartanticProvider(
    agent: Agent.gemini(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
    ),
  ),
)
```

### ChatHistoryProvider
Abstract interface that bridges the UI to an AI backend:

```dart
abstract class ChatHistoryProvider implements Listenable {
  /// Transcribes audio to text using the LLM.
  Stream<String> transcribeAudio(XFile audioFile);

  /// Sends a message and streams the response, maintaining chat history.
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments,
  });

  /// Chat history as dartantic ChatMessage objects.
  Iterable<ChatMessage> get history;
  set history(Iterable<ChatMessage> history);
}
```

### DartanticProvider
Default implementation that wraps a `dartantic_ai` Agent:

```dart
class DartanticProvider extends ChatHistoryProvider with ChangeNotifier {
  DartanticProvider({
    required Agent agent,
    Iterable<ChatMessage>? history,
    String? systemPrompt,
  });
}
```

---

## Type Mappings

The package uses types from `dartantic_interface`:

| UI Concept       | dartantic_interface Type      |
| ---------------- | ----------------------------- |
| User message     | `ChatMessage` with `ChatMessageRole.user` |
| Model response   | `ChatMessage` with `ChatMessageRole.model` |
| File attachment  | `DataPart`                    |
| Image attachment | `DataPart` (with image mimeType) |
| Link attachment  | `LinkPart`                    |
| Text content     | `TextPart`                    |

---

## View Hierarchy

```
AgentChatView
├── ChatHistoryView
│   └── ChatMessageView (per message)
│       ├── TextMessageView
│       └── AttachmentView
│           ├── ImagePartView
│           ├── FilePartView
│           └── LinkPartView
└── ChatInput
    ├── TextInputField
    ├── AttachmentPicker
    └── VoiceRecorder
```

---

## Attachment Handling

Attachments are rendered via pattern matching on `Part` types:

```dart
Widget build(BuildContext context) => switch (part) {
  DataPart(mimeType: final m) when m.startsWith('image/') => ImagePartView(part),
  DataPart() => FilePartView(part),
  LinkPart() => LinkPartView(part),
  _ => const SizedBox.shrink(),
};
```

---

## Usage Example

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  runApp(const App());
}

// In widget:
AgentChatView(
  provider: DartanticProvider(
    agent: Agent.gemini(
      model: 'gemini-3-flash-preview',
      apiKey: _apiKey,
    ),
  ),
)
```

---

## Key Files

| File | Purpose |
| ---- | ------- |
| `lib/src/views/agent_chat_view.dart` | Main chat widget |
| `lib/src/providers/interface/chat_history_provider.dart` | Provider interface |
| `lib/src/providers/implementations/dartantic_provider.dart` | Default dartantic implementation |
| `lib/src/providers/implementations/echo_provider.dart` | Test/demo provider |
| `lib/src/chat_view_model/chat_view_model.dart` | State management |
| `lib/src/views/chat_input/*.dart` | Input components |
| `lib/src/views/chat_message_view/*.dart` | Message rendering |
| `lib/src/views/attachment_view/*.dart` | Attachment rendering |

---

## Exports

The package re-exports needed dartantic_interface types:

```dart
// lib/dartantic_chat.dart
export 'src/providers/providers.dart';
export 'src/styles/styles.dart';
export 'src/views/agent_chat_view.dart';
export 'package:dartantic_interface/dartantic_interface.dart'
    show ChatMessage, ChatMessageRole, Part, DataPart, LinkPart, TextPart;
```
