# dartantic_firebase_ai

Firebase AI provider for [dartantic_ai](https://pub.dev/packages/dartantic_ai).

Provides access to Google's Gemini models through Firebase with flexible backend options for both development and production use.

## Features

- 🔥 **Dual Backend Support** - Google AI (development) and Vertex AI (production)
- 🔒 **Enhanced Security** - App Check and Firebase Auth support (Vertex AI)
- 🎯 **Most Gemini Capabilities** - Chat, media generation, structured output, vision
- 🚀 **Streaming Responses** - Real-time token generation
- 🛠️ **Tool Calling** - Function execution during generation
- 🧠 **Extended Thinking** - Model reasoning with configurable token budgets
- 🔄 **Easy Migration** - Switch backends without code changes

## Platform Support

- ✅ iOS
- ✅ Android
- ✅ macOS
- ✅ Web

**Note:** This is a Flutter-specific package and requires the Flutter SDK.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  dartantic_firebase_ai: ^0.1.0
  firebase_core: ^4.4.0
```

To use with the `Agent` orchestration layer, also add `dartantic_ai`:

```yaml
dependencies:
  dartantic_ai: ^3.0.0
  dartantic_firebase_ai: ^0.1.0
  firebase_core: ^4.4.0
```

## Setup Requirements

**Important:** Both backends require Flutter SDK, Firebase Core initialization, and a Firebase project configuration.

### Common Requirements (Both Backends)
- **Flutter SDK** (not just Dart)
- **Firebase Core initialization** (`Firebase.initializeApp()`)
- **Firebase project configuration** (minimal config acceptable)

### Google AI Backend (Development)
- Uses **Gemini Developer API** through Firebase SDK
- Requires Google AI API key for authentication
- Simpler authentication setup
- Good for prototyping and development

### Vertex AI Backend (Production)  
- Uses **Vertex AI through Firebase** infrastructure
- Requires **full Firebase project setup** with Google Cloud billing enabled
- Follow the [Firebase Flutter setup guide](https://firebase.google.com/docs/flutter/setup) for your platform
- Enable Firebase AI Logic in your Firebase console
- (Optional) Set up [App Check](https://firebase.google.com/docs/app-check) for enhanced security

## Usage

### Backend Selection

Firebase AI supports two backends with different API endpoints but similar setup:

**Google AI Backend** (for development/testing):
- Routes requests to Gemini Developer API
- Good for prototyping and development

**Vertex AI Backend** (for production):
- Requires complete Firebase project setup
- Full Firebase integration with security features
- App Check, Firebase Auth support
- Production-ready infrastructure

### Basic Setup

```dart
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_core/firebase_core.dart';

// Initialize Firebase (required for both backends)
await Firebase.initializeApp();

// Create a provider
final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

// Create a chat model
final chatModel = provider.createChatModel(name: 'gemini-2.5-flash');

// Stream a response
final messages = [ChatMessage.user('Explain quantum computing')];
await for (final chunk in chatModel.sendStream(messages)) {
  print(chunk.output.text);
}
```

### With Agent (requires `dartantic_ai`)

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';

// Register provider factories
Agent.providerFactories['firebase-vertex'] = () =>
    FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
Agent.providerFactories['firebase-google'] = () =>
    FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

// Create agents
final prodAgent = Agent('firebase-vertex:gemini-2.0-flash');
final devAgent = Agent('firebase-google:gemini-2.0-flash');

// Send a message
final result = await prodAgent.send('Explain quantum computing');
print(result.output);

// Stream a response
await for (final chunk in devAgent.sendStream('Tell me a story')) {
  print(chunk.output);
}
```

## Configuration Options

The `FirebaseAIChatModelOptions` class supports:

- `temperature` - Sampling temperature (0.0 to 2.0)
- `topP` - Nucleus sampling threshold
- `topK` - Top-K sampling
- `candidateCount` - Number of generated responses to return
- `maxOutputTokens` - Maximum tokens to generate
- `stopSequences` - Stop generation sequences
- `responseMimeType` - Output response MIME type (e.g., `application/json`)
- `responseSchema` - Output response schema for structured output
- `safetySettings` - Content safety configuration
- `enableCodeExecution` - Enable code execution in the model
- `enableThinking` - Enable model reasoning/thinking content
- `thinkingBudgetTokens` - Token budget for thinking (-1 for dynamic)

## Security Best Practices

1. **Use App Check** to prevent unauthorized API usage
2. **Enable Firebase Auth** for user-based access control
3. **Set up Firebase Security Rules** to protect your data
4. **Monitor usage** in Firebase console to detect anomalies

## Dependencies and Requirements

**This package requires Flutter** - it cannot be used in pure Dart projects due to:
- Flutter-specific Firebase SDK dependencies (`firebase_core`, `firebase_auth`, etc.)
- Platform-specific Firebase initialization code
- Flutter framework dependencies for UI integrations

For pure Dart projects, consider using the `dartantic_google` provider instead.

## Comparison to Google Provider

| Feature | Google Provider | Firebase AI Provider |
|---------|----------------|---------------------|
| API Access | Direct Gemini API | Through Firebase |
| Setup | API key only | Firebase project + API key |
| Security | API key only | App Check + Auth |
| Platforms | All Dart platforms | Flutter only |
| Embeddings | Yes | No |
| Media Generation | Yes | Yes |
| On-Device | No | No (web only) |
| Cost Control | Manual | Firebase quotas |
| Dependencies | HTTP client only | Full Firebase SDK |

> **Note**: On-device inference is available for web apps via [Firebase AI Logic](https://firebase.blog/posts/2025/06/hybrid-inference-firebase-ai-logic/), but not yet supported for Flutter mobile apps.

## Contributing

Contributions welcome! See the [contributing guide](https://github.com/csells/dartantic_ai/blob/main/CONTRIBUTING.md).

## License

MIT License - see [LICENSE](https://github.com/csells/dartantic_ai/blob/main/LICENSE)
