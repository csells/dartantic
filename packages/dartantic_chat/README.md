Hello and welcome to Dartantic Chat!

The dartantic_chat package provides the widgets to make it easy to add an AI
chat window to your Flutter app. The package is organized around an abstract
chat history provider API that makes it easy to swap out the agentic SDK that
you'd like your chat widget to use. Out of the box, it comes with support for
[dartantic_ai](https://pub.dev/packages/dartantic_ai), which provides access to
multiple LLM providers including Google Gemini, OpenAI, Anthropic, Mistral, and
Ollama.

![alt text](readme/screenshot.png)

## Key features

* **Multi-turn chat:** Maintains context across multiple interactions.
* **Streaming responses:** Displays AI responses in real-time as they're
  generated.
* **Rich text display:** Supports formatted text in chat messages.
* **Voice input:** Allows users to input prompts using speech.
* **Multimedia attachments:** Enables sending and receiving various media types.
* **Custom styling:** Offers extensive customization to match your app's design.
* **Chat serialization/deserialization:** Store and retrieve conversations
  between app sessions.
* **Custom response widgets:** Introduce specialized UI components to present
  LLM responses.
* **Pluggable LLM support:** Implement a simple interface to plug in your own
  LLM.
* **Cross-platform support:** Compatible with the Android, iOS, web, and macOS
  platforms.
* **Function calling/Tools:** Support for LLM function calling via dartantic_ai
  tools.

## Getting started

 1. **Installation**

    Add the following dependencies to your `pubspec.yaml` file:

    ```sh
    $ flutter pub add dartantic_chat
    ```

 2. **Configuration**

    Get your API key from the [Google AI
    Studio](https://aistudio.google.com/apikey) or your preferred LLM provider.

    Run your app with the API key:

    ```bash
    flutter run --dart-define=GEMINI_API_KEY=your-api-key-here
    ```

    In your Dart code, initialize the agent:

    ```dart
    import 'package:dartantic_ai/dartantic_ai.dart';
    import 'package:dartantic_chat/dartantic_chat.dart';

    const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

    void main() {
      assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
      Agent.environment['GEMINI_API_KEY'] = _apiKey;
      runApp(const App());
    }
    ```

    Then create your chat interface:

    ```dart
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

    For a complete usage example, check out the [`gemini.dart` sample][].

 3. **Using other LLM providers**

    dartantic_ai supports multiple providers. Set the appropriate API key and
    configure the Agent:

    ```dart
    // OpenAI
    Agent.environment['OPENAI_API_KEY'] = openaiKey;
    final agent = Agent('openai-responses:gpt-4o');

    // Anthropic
    Agent.environment['ANTHROPIC_API_KEY'] = anthropicKey;
    final agent = Agent('anthropic:claude-3-5-sonnet');

    // Ollama (local, no API key needed)
    final agent = Agent('ollama:llama3.2');
    ```

 4. **Set up device permissions**

To enable your users to take advantage of features like voice input and media
attachments, ensure that your app has the necessary permissions:

- **Network access:**

To enable network access on macOS, add the following to your `*.entitlements`
files:

```xml
<plist version="1.0">
    <dict>
      ...
      <key>com.apple.security.network.client</key>
      <true/>
    </dict>
</plist>
```

To enable network access on Android, ensure that your `AndroidManifest.xml` file
contains the following:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    ...
    <uses-permission android:name="android.permission.INTERNET"/>
</manifest>
```

- **Microphone access:** To enable voice input for users, update configs
  according to the [permission and setup instructions][record-setup] for
  `package:record`.

- **File selection:** To enable users to select and attach files, follow the
  [usage instructions][file-setup] for `package:file_selector`.

- **Image selection:** To enable users to take or select a picture from their
  device, refer to the [installation instructions][image-setup] for
  `package:image_picker`.

[`gemini.dart` sample]:
    https://github.com/csells/dartantic_chat/blob/main/example/lib/gemini/gemini.dart

[record-setup]: https://pub.dev/packages/record#setup-permissions-and-others
[file-setup]: https://pub.dev/packages/file_selector#usage
[image-setup]: https://pub.dev/packages/image_picker#installation

## User experience

The `AgentChatView` widget is the entry point for the interactive chat
experience that dartantic chat provides. Hosting an instance of the `AgentChatView`
enables a number of user experience features that don't require any additional
code to use:

* **Multiline text input**: Allows users to paste long text input or insert new
  lines into their text as they enter it.
* **Voice input**: Allows users to input prompts using speech for ease of use.
* **Multimedia input**: Enables users to take pictures, send images and other
  file types and attach URLs as link to online resources.
* **Image zoom**: Enables users to zoom into image thumbnails.
* **Copy to clipboard**: Allows the user to copy the text of a message or a LLM
  response to the clipboard.
* **Message editing**: Allows the user to edit the most recent message for
  resubmission to the LLM.
* **Material and Cupertino**: Adapts to the best practices of both design
  languages.

### Multiline text input

The user has options when it comes to submitting their prompt once they've
finished composing it, which again differs depending on their platform:

* **Mobile**: Tap the **Submit** button
* **Web**: Press **Enter** or tap the **Submit** button
* **Desktop**: Press **Enter** or tap the **Submit** button

If they'd like to embed newlines into their prompt manually as they enter it:

* **Mobile**: Tap Return key on the virtual keyboard
* **Web**: Press `Shift+Enter`
* **Desktop**: Press `Shift+Enter`

### Voice input

In addition to text input the chat view can take an audio recording as input by
tapping the Mic button, which is visible when no text has yet been entered. Tap
the **Mic** button to start the recording, then select the **Stop** button to
translate the user's voice input into text. This text can then be edited,
augmented and submitted as normal.

### Multimedia input

The chat view can also take images and files as input to pass along to the
underlying LLM. The user can select the **Plus** button to the left of the text
input and choose from the **Take Photo**, **Image Gallery**, **Attach File** and
**Attach Link** icons.

### Image zoom

The user can zoom into an image thumbnail by tapping it. Pressing the **Esc**
key or tapping anywhere outside the image dismisses the zoomed image.

### Copy to clipboard

The user can copy any text prompt or LLM response in their current chat. On
desktop or web, the user can mouse to select the text on their screen and copy
it to the clipboard as normal. In addition, at the bottom of each prompt or
response, the user can select the **Copy** button that pops up when they hover
their mouse. On mobile platforms, the user can long-tap a prompt or response and
choose the Copy option.

### Message editing

If the user would like to edit their last prompt and cause the LLM to take
another run at it, they can do so. On the desktop, the user can tap the **Edit**
button alongside the **Copy** button for their most recent prompt. On a mobile
device, the user can long-tap and get access to the **Edit** option on their
most recent prompt.

### Material and Cupertino

When the `AgentChatView` widget is hosted in a Material app, it uses facilities
provided by the Material design language. Likewise, when hosted in a Cupertino
app, it uses those facilities. However, while the chat view supports both app
types, it doesn't automatically adopt the associated themes. Instead, that's set
by the `style` property of the `AgentChatView`.

## Feature integration

In addition to the features that are provided automatically by the
`AgentChatView`, a number of integration points allow your app to blend
seamlessly with other features to provide additional functionality:

* **Welcome messages**: Display an initial greeting to users.
* **Suggested prompts**: Offer users predefined prompts to guide interactions.
* **System instructions**: Provide the LLM with specific input to influence its
  responses.
* **Disable attachments and audio input**: Remove optional parts of the chat UI.
* **Manage cancel or error behavior**: Change the user cancellation or LLM error
  behavior.
* **Manage history**: Every LLM provider allows for managing chat history.
* **Chat serialization/deserialization**: Store and retrieve conversations
  between app sessions.
* **Custom response widgets**: Introduce specialized UI components to present
  LLM responses.
* **Custom styling**: Define unique visual styles to match the chat appearance
  to the overall app.
* **Chat without UI**: Interact directly with the LLM providers without
  affecting the user's current chat session.
* **Custom LLM providers**: Build your own LLM provider for integration of chat
  with your own model backend.
* **Rerouting prompts**: Debug, log, or reroute messages meant for the provider.

### Welcome messages

The chat view allows you to provide a custom welcome message to set context for
the user:

```dart
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: AgentChatView(
      welcomeMessage: 'Hello and welcome to Dartantic Chat!',
      provider: DartanticProvider(
        agent: Agent('gemini'),
      ),
    ),
  );
}
```

### Suggested prompts

You can provide a set of suggested prompts to give the user some idea of what
the chat session has been optimized for. The suggestions are only shown when
there is no existing chat history. Clicking one sends it immediately as a
request to the underlying LLM:

```dart
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: AgentChatView(
      suggestions: [
        'I\'m a Star Wars fan. What should I wear for Halloween?',
        'I\'m allergic to peanuts. What candy should I avoid at Halloween?',
        'What\'s the difference between a pumpkin and a squash?',
      ],
      provider: DartanticProvider(
        agent: Agent('gemini'),
      ),
    ),
  );
}
```

### LLM instructions

To optimize an LLM's responses based on the needs of your app, you'll want to
give it instructions. Use the `systemPrompt` parameter of `DartanticProvider`:

```dart
DartanticProvider(
  agent: Agent('gemini'),
  systemPrompt: '''
You are a helpful assistant that generates recipes based on the ingredients and
instructions provided as well as my food preferences.

You should keep things casual and friendly.
''',
)
```

### Function calling

To enable the LLM to perform actions on behalf of the user, you can provide a
set of tools (functions) that the LLM can call. dartantic_ai supports function
calling out of the box through the `Agent` class. Check out the [function
calling example][] for details.

[function calling example]:
    https://github.com/csells/dartantic_chat/blob/main/example/lib/function_calls/function_calls.dart

### Disable attachments and audio input

If you'd like to disable attachments (the **+** button) or audio input (the mic
button), you can do so with the `enableAttachments` and `enableVoiceNotes`
parameters:

```dart
AgentChatView(
  provider: DartanticProvider(agent: Agent('gemini')),
  enableAttachments: false,
  enableVoiceNotes: false,
)
```

Both of these flags default to `true`.

### Custom speech-to-text

By default, the dartantic chat uses the `ChatHistoryProvider` passed to the
`AgentChatView` to provide the speech-to-text implementation. If you'd like to
provide your own implementation, you can do so by implementing the
`SpeechToText` interface and passing it to the `AgentChatView` constructor:

```dart
AgentChatView(
  provider: DartanticProvider(agent: Agent('gemini')),
  speechToText: MyCustomSpeechToText(),
)
```

### Manage cancel or error behavior

By default, when the user cancels an LLM request, the LLM's response will be
appended with the string "CANCEL" and a message will pop up that the user has
canceled the request. Likewise, in the event of an LLM error, the LLM's response
will be appended with the string "ERROR" and an alert dialog will pop up with
the details of the error.

You can override the cancel and error behavior:

```dart
AgentChatView(
  provider: DartanticProvider(agent: Agent('gemini')),
  onCancelCallback: (context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat cancelled')),
    );
  },
  cancelMessage: 'Request cancelled',
)
```

### Manage history

The standard interface that defines all LLM providers includes the ability to
get and set history for the provider:

```dart
abstract class ChatHistoryProvider implements Listenable {
  Stream<String> transcribeAudio(XFile audioFile);
  Stream<String> sendMessageStream(String prompt, {Iterable<Part> attachments});
  Iterable<ChatMessage> get history;
  set history(Iterable<ChatMessage> history);
}
```

When the history for a provider changes, it calls the `notifyListener` method.
To see or set the history, you can access the `history` property:

```dart
void _clearHistory() => _provider.history = [];
```

### Chat serialization/deserialization

To save and restore chat history between sessions of an app requires the ability
to serialize and deserialize each user prompt and LLM response. Serialization
can be accomplished by using the `toJson` method of each `ChatMessage` instance:

```dart
Future<void> _saveHistory() async {
  final history = _provider.history.toList();
  for (var i = 0; i != history.length; ++i) {
    final file = await _messageFile(i);
    if (file.existsSync()) continue;
    final map = history[i].toJson();
    final json = JsonEncoder.withIndent('  ').convert(map);
    await file.writeAsString(json);
  }
}
```

Likewise, to deserialize, use the static `fromJson` method:

```dart
Future<void> _loadHistory() async {
  final history = <ChatMessage>[];
  for (var i = 0;; ++i) {
    final file = await _messageFile(i);
    if (!file.existsSync()) break;
    final map = jsonDecode(await file.readAsString());
    history.add(ChatMessage.fromJson(map));
  }
  _provider.history = history;
}
```

### Custom response widgets

By default, the LLM response shown by the chat view is formatted Markdown.
However, you can create a custom widget to show the LLM response by setting the
`responseBuilder` parameter:

```dart
AgentChatView(
  provider: _provider,
  welcomeMessage: _welcomeMessage,
  responseBuilder: (context, response) => RecipeResponseView(response),
)
```

### Custom styling

The chat view comes out of the box with a set of default styles. You can fully
customize those styles by using the `style` parameter:

```dart
AgentChatView(
  provider: DartanticProvider(agent: Agent('gemini')),
  style: ChatViewStyle(...),
)
```

For a complete list of the styles available, check out the [styles example][].

[styles example]:
    https://github.com/csells/dartantic_chat/blob/main/example/lib/styles/styles.dart

### Chat without UI

You don't have to use the chat view to access the functionality of the
underlying provider. You can use it directly with the `ChatHistoryProvider`
interface:

```dart
final _provider = DartanticProvider(agent: Agent('gemini'));

Future<void> _onMagic() async {
  final stream = _provider.sendMessageStream(
    'Generate a modified version of this recipe...',
  );
  var response = await stream.join();
  // Process response...
}
```

### Rerouting prompts

If you'd like to debug, log, or manipulate the connection between the chat view
and the underlying provider, you can do so with an `LlmStreamGenerator` function
passed to the `messageSender` parameter:

```dart
AgentChatView(
  provider: _provider,
  messageSender: _logMessage,
)

Stream<String> _logMessage(
  String prompt, {
  required Iterable<Part> attachments,
}) async* {
  debugPrint('# Sending Message');
  debugPrint('## Prompt\n$prompt');

  final response = _provider.sendMessageStream(prompt, attachments: attachments);
  final text = await response.join();
  debugPrint('## Response\n$text');

  yield text;
}
```

## Custom LLM providers

The protocol connecting an LLM and the `AgentChatView` is expressed in the
`ChatHistoryProvider` interface:

```dart
abstract class ChatHistoryProvider implements Listenable {
  Stream<String> transcribeAudio(XFile audioFile);
  Stream<String> sendMessageStream(String prompt, {Iterable<Part> attachments});
  Iterable<ChatMessage> get history;
  set history(Iterable<ChatMessage> history);
}
```

The LLM could be in the cloud or local, hosted on any cloud provider, or
proprietary or open source. Any LLM or LLM-like endpoint that can implement this
interface can be plugged into the chat view. The dartantic chat comes with two
providers out of the box:

* **DartanticProvider**: Wraps the `dartantic_ai` package for multi-provider
  support
* **EchoProvider**: Useful as a minimal provider example and for testing

### Implementation

To build your own provider, you need to implement the `ChatHistoryProvider`
interface with these things in mind:

1. **Configuration**: Allow the user to create the underlying model and pass it
   as a parameter
2. **History**: Manage history, notify listeners, and support serialization
3. **Messages and attachments**: Map from `ChatMessage` and `Part` types to
   whatever is handled by the underlying LLM
4. **Calling the LLM**: Implement `sendMessageStream` and `transcribeAudio`

Here's a minimal example structure:

```dart
class MyProvider extends ChatHistoryProvider with ChangeNotifier {
  MyProvider({
    required MyLlmModel model,
    Iterable<ChatMessage>? history,
  }) : _model = model,
       _history = history?.toList() ?? [];

  final MyLlmModel _model;
  final List<ChatMessage> _history;

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt);
    _history.add(userMessage);

    // Call your LLM here and stream the response
    final response = await _model.generate(prompt);

    _history.add(ChatMessage.model(response));
    yield response;
    notifyListeners();
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    // Implement audio transcription
    yield 'Transcribed text';
  }
}
```

The [EchoProvider][] implementation provides a good starting point for your own
custom provider.

[EchoProvider]:
    https://github.com/csells/dartantic_chat/blob/main/lib/src/providers/implementations/echo_provider.dart

## Samples

To run the [example apps][] in the `example/lib` directory, provide your API key
via `--dart-define`:

```bash
cd example
flutter run --dart-define=GEMINI_API_KEY=your-api-key-here
```

[example apps]: https://github.com/csells/dartantic_chat/tree/main/example/lib

## Feedback

As you use this package, please [log issues and feature
requests](https://github.com/csells/dartantic_chat/issues) as well as submit any
[code you'd like to contribute](https://github.com/csells/dartantic_chat/pulls).

## License

This project is a fork of [flutter/ai](https://github.com/flutter/ai), which is
licensed under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for
details, and the [original
license](https://github.com/flutter/ai/blob/main/LICENSE).
