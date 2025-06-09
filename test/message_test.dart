import 'dart:convert';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_ai/src/models/message.dart';
import 'package:test/test.dart';

// NOTE: some of these tests require environment variables to be set.
// I recommend using .vscode/settings.json like so:
//
// {
//   "dart.env": {
//     "GEMINI_API_KEY": "your_gemini_api_key",
//     "OPENAI_API_KEY": "your_openai_api_key"
//   }
// }

void main() {
  group('Message serialization', () {
    test('deserializes and reserializes to the same JSON structure', () {
      const jsonString = '''
[
        {
          "role": "system",
          "content": [
            {"text": "You are a helpful AI assistant."}
          ]
        },
        {
          "role": "user",
          "content": [
            {"text": "Hello, can you help me with a task?"}
          ]
        },
        {
          "role": "model",
          "content": [
            {"text": "Of course! I'd be happy to help you with a task. What kind of task do you need assistance with? Please provide me with more details, and I'll do my best to help you."}
          ]
        },
        {
          "role": "user",
          "content": [
            {"text": "Can you analyze this image and tell me what you see?"},
            {
              "media": {
                "contentType": "image/jpeg",
                "url": "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAg..."
              }
            }
          ]
        }
      ]''';

      final inputJson = jsonDecode(jsonString);
      final messages =
          (inputJson as List).map((e) => Message.fromJson(e)).toList();
      final outputJson = messages.map((m) => m.toJson()).toList();

      // Deep equality check
      expect(outputJson, equals(inputJson));
    });
  });

  Future<void> testEmptyMessagesPromptIncludesUserAndModelMessages(
    Provider provider,
  ) async {
    const prompt = 'What is 2 + 2?';
    final agent = Agent.provider(provider);
    final responses = <AgentResponse>[];
    await agent.runStream(prompt, messages: []).forEach(responses.add);
    final messages =
        responses.isNotEmpty ? responses.last.messages : <Message>[];

    expect(
      messages,
      isNotEmpty,
      reason: '${provider.displayName}: messages should not be empty',
    );
    expect(
      messages.first.role,
      MessageRole.user,
      reason: '${provider.displayName}: first message should be user',
    );

    expect(
      messages.first.content.whereType<TextPart>().any((p) => p.text == prompt),
      isTrue,
      reason:
          '${provider.displayName}: prompt should be present in first user '
          'message',
    );
    expect(
      messages.any((m) => m.role == MessageRole.model),
      isTrue,
      reason: '${provider.displayName}: should contain a model response',
    );
  }

  test(
    'empty history + prompt (OpenAI)',
    () => testEmptyMessagesPromptIncludesUserAndModelMessages(OpenAiProvider()),
  );

  test(
    'empty history + prompt (Gemini)',
    () => testEmptyMessagesPromptIncludesUserAndModelMessages(GeminiProvider()),
  );
}
