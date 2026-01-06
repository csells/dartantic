# Welcome to Dartantic Chat!

The [dartantic_chat](https://pub.dev/packages/dartantic_chat) package provides
Flutter chat UI widgets that make it easy to add an AI chat window to your app.
Out of the box, it supports [dartantic_ai](https://pub.dev/packages/dartantic_ai)
for access to multiple LLM providers including Google Gemini, OpenAI, Anthropic,
Mistral, and Ollama.

![Screenshot](readme/screenshot.png)

## Key Features

- **Multi-turn chat** - Maintains context across interactions
- **Streaming responses** - Real-time AI response display
- **Voice input** - Speech-to-text prompt entry
- **Multimedia attachments** - Images, files, and URLs
- **Custom styling** - Match your app's design
- **Chat serialization** - Save and restore conversations
- **Custom response widgets** - Specialized UI for responses
- **Pluggable LLM support** - Easy provider integration
- **Cross-platform** - Android, iOS, web, macOS, Linux, Windows
- **Function calling** - Tool support via dartantic_ai

## Quick Start

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  runApp(const App());
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chat')),
    body: AgentChatView(
      provider: DartanticProvider(
        agent: Agent('gemini'),
      ),
    ),
  );
}
```

Run with your API key:

```bash
flutter run --dart-define=GEMINI_API_KEY=your-api-key-here
```

## Documentation

**[Read the full documentation at docs.dartantic.ai](https://docs.dartantic.ai/dartantic-chat)**

## Contributing & Community

Contributions welcome! Feature requests, bug reports, and PRs are welcome on
[GitHub](https://github.com/csells/dartantic).

Want to chat about Dartantic? Drop by the
[Discussions forum](https://github.com/csells/dartantic/discussions).

## License

This project is a fork of [flutter/ai](https://github.com/flutter/ai), licensed
under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for details.
