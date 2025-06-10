// ignore_for_file: avoid_print

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
      List<Message> initialMessages,
    ) async {
      final agent = Agent.provider(
        provider,
        systemPrompt:
            initialMessages.isNotEmpty &&
                    initialMessages.first.role == MessageRole.system
                ? (initialMessages.first.content.first as TextPart).text
                : null,
      );

      final response = await agent.run('And Italy?', messages: initialMessages);
      final messages = response.messages;

      // dump the messages to the console
      print('# ${provider.displayName} messages:');
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        print('- ${m.role}: ${m.content.map((p) => p.toJson()).join(' | ')}');
      }

      expect(
        messages,
        isNotEmpty,
        reason: '${provider.displayName}: messages should not be empty',
      );
      final systemPrompt =
          initialMessages.isNotEmpty &&
                  initialMessages.first.role == MessageRole.system
              ? (initialMessages.first.content.first as TextPart).text
              : null;
      if (systemPrompt != null) {
        expect(
          messages.first.role,
          MessageRole.system,
          reason: '${provider.displayName}: first message should be system',
        );
        expect(
          (messages.first.content.first as TextPart).text,
          systemPrompt,
          reason: '${provider.displayName}: system prompt text should match',
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
      } else {
        expect(
          messages.first.role,
          isNot(MessageRole.system),
          reason: '${provider.displayName}: no system prompt should be present',
        );
        expect(
          messages.first.role,
          MessageRole.user,
          reason:
              '${provider.displayName}: first message should be user '
              '(no system message)',
        );
        expect(
          messages[1].role,
          MessageRole.model,
          reason: '${provider.displayName}: second message should be model',
        );
        expect(
          messages[2].role,
          MessageRole.user,
          reason: '${provider.displayName}: third message should be user',
        );
      }
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

    // Shared initial message lists
    final initialNoSystem = <Message>[
      Message(
        role: MessageRole.user,
        content: [const TextPart('What is the capital of France?')],
      ),
      Message(
        role: MessageRole.model,
        content: [const TextPart('The capital of France is Paris.')],
      ),
    ];

    final initialWithSystem = <Message>[
      Message(
        role: MessageRole.system,
        content: [const TextPart('You are a test system prompt.')],
      ),
      ...initialNoSystem,
    ];

    test(
      'history with non-empty initial messages, with system (OpenAI)',
      () => testMessageHistoryWithInitialMessages(
        OpenAiProvider(),
        initialWithSystem,
      ),
    );
    test(
      'history with non-empty initial messages, with system (Gemini)',
      () async {
        await testMessageHistoryWithInitialMessages(
          GeminiProvider(),
          initialWithSystem,
        );
      },
    );
    test(
      'history with non-empty initial messages, no system (OpenAI)',
      () => testMessageHistoryWithInitialMessages(
        OpenAiProvider(),
        initialNoSystem,
      ),
    );
    test(
      'history with non-empty initial messages, no system (Gemini)',
      () => testMessageHistoryWithInitialMessages(
        GeminiProvider(),
        initialNoSystem,
      ),
    );

    Future<void> testSystemPromptPropagation(Provider provider) async {
      const systemPrompt = 'You are a system prompt for testing.';
      final agent = Agent.provider(provider, systemPrompt: systemPrompt);
      final responses = <AgentResponse>[];
      await agent.runStream('Say hello!').forEach(responses.add);
      final messages =
          responses.isNotEmpty ? responses.last.messages : <Message>[];
      if (systemPrompt.isNotEmpty) {
        expect(
          messages.isNotEmpty && messages.first.role == MessageRole.system,
          isTrue,
        );
        expect((messages.first.content.first as TextPart).text, systemPrompt);
      } else {
        expect(
          messages.isEmpty || messages.first.role != MessageRole.system,
          isTrue,
        );
      }
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
      final result = await agent.runFor<Map<String, dynamic>>(
        'What animal says "neigh"?',
        messages: initialMessages,
      );
      expect(result.output, isA<Map<String, dynamic>>());
      expect(result.output['animal'], isNotNull);
      expect(result.output['sound'], isNotNull);
      expect(result.output['animal'], isA<String>());
      expect(result.output['sound'], isA<String>());
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

      // Dump the messages for inspection
      print('--- Dumping messages for provider: ${provider.displayName} ---');
      for (var i = 0; i < messages.length; i++) {
        final m = messages[i];
        print('Message #$i: role=${m.role}, content:');
        for (final part in m.content) {
          print('  $part');
        }
      }

      final hasToolCall = messages.any(
        (m) =>
            m.content.any((p) => p is ToolPart && p.kind == ToolPartKind.call),
      );
      final hasToolResult = messages.any(
        (m) => m.content.any(
          (p) => p is ToolPart && p.kind == ToolPartKind.result,
        ),
      );
      expect(hasToolCall, isTrue, reason: 'Should include a tool call message');
      expect(
        hasToolResult,
        isTrue,
        reason: 'Should include a tool result message',
      );
      expect(
        messages.any((m) => m.role == MessageRole.model),
        isTrue,
        reason: 'Should include a model response',
      );
      expect(
        messages.any(
          (m) =>
              m.content.whereType<TextPart>().any(
                (p) => p.text.contains('hello world'),
              ) ||
              m.content.whereType<ToolPart>().any(
                (p) =>
                    p.kind == ToolPartKind.result &&
                    p.result.toString().contains('hello world'),
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

    test('context is maintained across chat responses (OpenAI)', () async {
      final agent = Agent.provider(
        OpenAiProvider(),
        systemPrompt: 'You are a helpful assistant.',
      );
      // First exchange
      final firstResponse = await agent.run('My favorite color is blue.');
      final firstMessages = firstResponse.messages;
      // Second exchange, referencing the first
      final secondResponse = await agent.run(
        'What color did I say I liked?',
        messages: firstMessages,
      );
      final secondOutput = secondResponse.output.toLowerCase();
      expect(secondOutput, contains('blue'));
    });
    test('context is maintained across chat responses (Gemini)', () async {
      final agent = Agent.provider(
        GeminiProvider(),
        systemPrompt: 'You are a helpful assistant.',
      );
      // First exchange
      final firstResponse = await agent.run('My favorite color is blue.');
      final firstMessages = firstResponse.messages;
      // Second exchange, referencing the first
      final secondResponse = await agent.run(
        'What color did I say I liked?',
        messages: firstMessages,
      );
      final secondOutput = secondResponse.output.toLowerCase();
      expect(secondOutput, contains('blue'));
    });

    Future<void> testGrowingHistoryWithProviders(
      List<Provider> providers,
      String testName,
    ) async {
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
      final schema = {
        'type': 'object',
        'properties': {
          'animal': {'type': 'string'},
          'sound': {'type': 'string'},
        },
        'required': ['animal', 'sound'],
        'additionalProperties': false,
      };
      const systemPrompt = 'You are a test system prompt.';
      var history = <Message>[
        Message(
          role: MessageRole.system,
          content: [const TextPart(systemPrompt)],
        ),
      ];
      var prompt = 'What animal says "moo"?';
      for (var i = 0; i < providers.length; i++) {
        final provider = providers[i];
        final agent = Agent.provider(
          provider,
          tools: [tool],
          systemPrompt: systemPrompt,
          outputType: schema.toSchema(),
          outputFromJson:
              (json) => {'animal': json['animal'], 'sound': json['sound']},
        );
        final result = await agent.runFor<Map<String, dynamic>>(
          prompt,
          messages: history,
        );
        print('Provider: ${provider.displayName}, output: ${result.output}');
        // Append the new messages to the history, skipping duplicate system
        // prompt
        final newMessages = result.messages;
        if (newMessages.isNotEmpty &&
            newMessages.first.role == MessageRole.system) {
          history = [history.first, ...newMessages.skip(1)];
        } else {
          history = [...history, ...newMessages];
        }
        // Change the prompt for the next round
        prompt = 'What animal says "quack"?';
      }
      // Final check: history should contain both tool calls and results, and be
      // valid for both providers
      expect(
        history.any(
          (m) => m.content.any(
            (p) => p is ToolPart && p.kind == ToolPartKind.call,
          ),
        ),
        isTrue,
        reason: 'History should contain at least one tool call',
      );
      expect(
        history.any(
          (m) => m.content.any(
            (p) => p is ToolPart && p.kind == ToolPartKind.result,
          ),
        ),
        isTrue,
        reason: 'History should contain at least one tool result',
      );
      expect(
        history.any((m) => m.role == MessageRole.system),
        isTrue,
        reason: 'History should contain a system prompt',
      );
      expect(
        history.any(
          (m) => m.content.whereType<TextPart>().any(
            (p) => p.text.contains('moo') || p.text.contains('quack'),
          ),
        ),
        isTrue,
        reason: 'History should contain animal sounds',
      );
    }

    test('growing history Gemini→OpenAI→Gemini→OpenAI', () async {
      await testGrowingHistoryWithProviders([
        GeminiProvider(),
        OpenAiProvider(),
        GeminiProvider(),
        OpenAiProvider(),
      ], 'Gemini→OpenAI→Gemini→OpenAI');
    });

    test('growing history OpenAI→Gemini→OpenAI→Gemini', () async {
      await testGrowingHistoryWithProviders([
        OpenAiProvider(),
        GeminiProvider(),
        OpenAiProvider(),
        GeminiProvider(),
      ], 'OpenAI→Gemini→OpenAI→Gemini');
    });

    Future<void> testToolResultReferencedInContext(Provider provider) async {
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
      const systemPrompt = 'You are a test system prompt.';
      // Step 1: Run initial tool call
      final agent1 = Agent.provider(
        provider,
        tools: [tool],
        systemPrompt: systemPrompt,
      );
      final responses1 = await agent1.run('Echo this: magic-value-123');
      final history = responses1.messages;
      // Debug: Print message history after first run
      print(
        '--- Debug: Message history after first agent run (provider: \\${provider.displayName}) ---',
      );
      for (var i = 0; i < history.length; i++) {
        final m = history[i];
        print('Message #$i: role=\\${m.role}, content:');
        for (final part in m.content) {
          print('  $part');
        }
      }
      // Step 2: Ask a follow-up referencing the tool result
      final agent2 = Agent.provider(
        provider,
        tools: [tool],
        systemPrompt: systemPrompt,
      );
      const followup = 'What value did I ask you to echo?';
      final responses2 = await agent2.run(followup, messages: history);
      final output = responses2.output;
      // Debug: Print follow-up output and message content
      print(
        '--- Debug: Follow-up output (provider: \\${provider.displayName}) ---',
      );
      print('Follow-up prompt: \\$followup');
      print('Follow-up output: \\$output');
      final followupMessages = responses2.messages;
      print('--- Debug: Follow-up message history ---');
      for (var i = 0; i < followupMessages.length; i++) {
        final m = followupMessages[i];
        print('Message #$i: role=\\${m.role}, content:');
        for (final part in m.content) {
          print('  $part');
        }
      }
      expect(
        output.toLowerCase(),
        contains('magic-value-123'),
        reason:
            'The agent should reference the tool result from earlier in the '
            'chat',
      );
    }

    test('tool result is referenced in later chat (Gemini)', () async {
      await testToolResultReferencedInContext(GeminiProvider());
    });
    test('tool result is referenced in later chat (OpenAI)', () async {
      await testToolResultReferencedInContext(OpenAiProvider());
    });
  });
}
