# Welcome to Dartantic!

The [dartantic_ai](https://pub.dev/packages/dartantic_ai) package provides an
agent framework designed to make building client and server-side apps in Dart 
with generative AI easier and more fun!

## Goals

- **Agentic behavior with multi-step tool calling:** Let your AI agents
  autonomously chain tool calls together to solve multi-step problems without
  human intervention.
- **Multi-Provider Support**: Works with OpenAI, Google Gemini, Anthropic, and more
- **Type Safety**: Leverage Dart's strong typing with automatic JSON schema
  generation
- **Production Ready**: Built-in logging, error handling, and provider
  capabilities detection
- **Extensible**: Easy to add custom providers and tools

## Quick Start

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  // Create an agent with your preferred provider
  final agent = Agent(
    'openai',  // or 'google', 'anthropic', 'ollama', etc.
    history: [ChatMessage.system('You are a helpful assistant.')],
  );

  // Generate text
  final result = await agent.send('Explain quantum computing in simple terms');
  print(result.output);

  // Use typed outputs
  final location = await agent.sendFor<TownAndCountry>(
    'The windy city in the US',
    outputSchema: JsonSchema.create({
      'type': 'object',
      'properties': {
        'town': {'type': 'string'},
        'country': {'type': 'string'},
      },
      'required': ['town', 'country'],
    }),
    outputFromJson: TownAndCountry.fromJson,
  );
  print('${location.output.town}, ${location.output.country}');
}
```

## Key Features

- **11 Provider Support** - OpenAI, Google, Anthropic, Mistral, Cohere, Ollama, and more
- **Streaming Output** - Real-time response generation
- **Typed Tool Calling** - Type-safe function definitions and execution
- **Multi-Media Input** - Process text, images, and files
- **Embeddings** - Vector generation and semantic search
- **MCP Support** - Model Context Protocol server integration
- **Provider Switching** - Switch between AI providers mid-conversation
- **Automatic Retry** - Built-in retry logic for rate limits

## Documentation

**[Read the full documentation at docs.dartantic.ai](https://docs.dartantic.ai)**

The documentation includes:
- **Getting Started Guide** - Installation and basic usage
- **Core Features** - JSON output, typed responses, and streaming
- **Advanced Features** - Tool calling, agentic behavior, and embeddings
- **Integration** - Logging, MCP servers, and custom providers
- **Provider Reference** - Detailed info on all supported providers
- **Examples** - Complete working examples for every feature

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dartantic_ai: ^1.0.0
```

## Contributing & Community

Welcome contributions! Feature requests, bug reports and PRs are welcome on [the
dartantic_ai github site](https://github.com/csells/dartantic_ai).

Want to chat about Dartantic? Drop by [the Discussions
forum](https://github.com/davidmigloz/csells/dartantic_ai).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file
for details.

---

**Built with ❤️ for the Dart & Flutter community**
