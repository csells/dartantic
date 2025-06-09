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

  group('Message history and features', () {
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
        messages.first.content.whereType<TextPart>().any(
          (p) => p.text == prompt,
        ),
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
      () =>
          testEmptyMessagesPromptIncludesUserAndModelMessages(OpenAiProvider()),
    );
    test(
      'empty history + prompt (Gemini)',
      () =>
          testEmptyMessagesPromptIncludesUserAndModelMessages(GeminiProvider()),
    );

    Future<void> testMessageHistoryWithInitialMessages(
      Provider provider,
    ) async {
      final initialMessages = [
        Message(
          role: MessageRole.system,
          content: [const TextPart('You are a test system prompt.')],
        ),
        Message(
          role: MessageRole.user,
          content: [const TextPart('What is the capital of France?')],
        ),
        Message(
          role: MessageRole.model,
          content: [const TextPart('The capital of France is Paris.')],
        ),
        Message(
          role: MessageRole.user,
          content: [const TextPart('And Germany?')],
        ),
      ];
      final agent = Agent.provider(provider);
      final responses = <AgentResponse>[];
      await agent
          .runStream('And Italy?', messages: initialMessages)
          .forEach(responses.add);
      final messages =
          responses.isNotEmpty ? responses.last.messages : <Message>[];

      expect(
        messages,
        isNotEmpty,
        reason: '${provider.displayName}: messages should not be empty',
      );
      expect(
        messages.first.role,
        MessageRole.system,
        reason: '${provider.displayName}: first message should be system',
      );
      expect(
        messages[1].role,
        MessageRole.user,
        reason: '${provider.displayName}: second message should be user',
      );
      expect(
        messages[2].role,
        MessageRole.model,
        reason: '${provider.displayName}: third message should be model',
      );
      expect(
        messages[3].role,
        MessageRole.user,
        reason: '${provider.displayName}: fourth message should be user',
      );
      expect(
        messages.last.role,
        MessageRole.model,
        reason:
            '${provider.displayName}: last message should be model '
            '(response to Italy)',
      );
      expect(
        messages.any(
          (m) => m.content.whereType<TextPart>().any(
            (p) => p.text.contains('Italy'),
          ),
        ),
        isTrue,
        reason: '${provider.displayName}: should mention Italy in response',
      );
    }

    test(
      'history with non-empty initial messages (OpenAI)',
      () => testMessageHistoryWithInitialMessages(OpenAiProvider()),
    );
    test(
      'history with non-empty initial messages (Gemini)',
      () => testMessageHistoryWithInitialMessages(GeminiProvider()),
    );

    Future<void> testSystemPromptPropagation(Provider provider) async {
      const systemPrompt = 'You are a system prompt for testing.';
      final agent = Agent.provider(provider, systemPrompt: systemPrompt);
      final responses = <AgentResponse>[];
      await agent.runStream('Say hello!').forEach(responses.add);
      final messages =
          responses.isNotEmpty ? responses.last.messages : <Message>[];
      expect(messages.first.role, MessageRole.system);
      expect(
        messages.first.content.whereType<TextPart>().any(
          (p) => p.text == systemPrompt,
        ),
        isTrue,
      );
    }

    test(
      'system prompt propagation (OpenAI)',
      () => testSystemPromptPropagation(OpenAiProvider()),
    );
    test(
      'system prompt propagation (Gemini)',
      () => testSystemPromptPropagation(GeminiProvider()),
    );

    Future<void> testTypedOutputWithHistory(Provider provider) async {
      final schema = {
        'type': 'object',
        'properties': {
          'animal': {'type': 'string'},
          'sound': {'type': 'string'},
        },
        'required': ['animal', 'sound'],
        'additionalProperties': false,
      };
      final agent = Agent.provider(
        provider,
        outputType: schema.toSchema(),
        outputFromJson:
            (json) => {'animal': json['animal'], 'sound': json['sound']},
      );
      final initialMessages = [
        Message(
          role: MessageRole.user,
          content: [const TextPart('What animal says "moo"?')],
        ),
        Message(
          role: MessageRole.model,
          content: [
            TextPart(jsonEncode({'animal': 'cow', 'sound': 'moo'})),
          ],
        ),
        Message(
          role: MessageRole.user,
          content: [const TextPart('What animal says "quack"?')],
        ),
      ];
      final result = await agent.runFor<Map<String, String>>(
        'What animal says "neigh"?',
        messages: initialMessages,
      );
      expect(result.output, isA<Map<String, String>>());
      expect(result.output['animal'], isNotEmpty);
      expect(result.output['sound'], isNotEmpty);
    }

    test(
      'typed output with history (OpenAI)',
      () => testTypedOutputWithHistory(OpenAiProvider()),
    );
    test(
      'typed output with history (Gemini)',
      () => testTypedOutputWithHistory(GeminiProvider()),
    );

    Future<void> testToolCallHistory(Provider provider) async {
      final tool = Tool(
        name: 'echo',
        description: 'Echoes the input',
        inputType:
            {
              'type': 'object',
              'properties': {
                'message': {'type': 'string'},
              },
              'required': ['message'],
            }.toSchema(),
        onCall: (input) async => {'echo': input['message']},
      );
      final agent = Agent.provider(
        provider,
        tools: [tool],
        systemPrompt: 'Use the echo tool to repeat the user message.',
      );
      final responses = <AgentResponse>[];
      await agent.runStream('Repeat: hello world').forEach(responses.add);
      final messages =
          responses.isNotEmpty ? responses.last.messages : <Message>[];
      // Should include a tool call and a tool response in the message history
      final hasToolCall = messages.any(
        (m) => m.content.any((p) => p is ToolPart),
      );
      expect(hasToolCall, isTrue, reason: 'Should include a tool call message');
      expect(
        messages.any((m) => m.role == MessageRole.model),
        isTrue,
        reason: 'Should include a model response',
      );
      expect(
        messages.any(
          (m) => m.content.whereType<TextPart>().any(
            (p) => p.text.contains('hello world'),
          ),
        ),
        isTrue,
        reason: 'Should echo the message',
      );
    }

    test(
      'tool call history (OpenAI)',
      () => testToolCallHistory(OpenAiProvider()),
    );
    test(
      'tool call history (Gemini)',
      () => testToolCallHistory(GeminiProvider()),
    );
  });
}
