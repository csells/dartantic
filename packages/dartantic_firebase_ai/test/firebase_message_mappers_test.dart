import 'dart:typed_data';

import 'package:dartantic_firebase_ai/src/firebase_ai_safety_options.dart';
import 'package:dartantic_firebase_ai/src/firebase_message_mappers.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai/firebase_ai.dart' as fai;
import 'package:test/test.dart';

fai.GenerateContentResponse _makeResponse(
  List<fai.Part> parts, {
  fai.FinishReason? finishReason,
}) => fai.GenerateContentResponse([
  fai.Candidate(fai.Content('model', parts), null, null, finishReason, null),
], null);

void main() {
  group('request mappers', () {
    test('maps basic user/model messages', () {
      final content = <ChatMessage>[
        ChatMessage.user('hello'),
        ChatMessage.model('hi'),
      ].toContentList();

      expect(content, hasLength(2));
      expect(content.first.parts.first, isA<fai.TextPart>());
      expect(content.last.parts.first, isA<fai.TextPart>());
    });

    test('maps multimodal user message', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            const TextPart('img'),
            DataPart(Uint8List.fromList([1, 2, 3, 4]), mimeType: 'image/png'),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      expect(list.first.parts.length, 2);
      expect(list.first.parts[1], isA<fai.InlineDataPart>());
    });

    test('maps tool call + tool result preserving IDs', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            ToolPart.call(
              callId: 'call_1',
              toolName: 'lookup',
              arguments: {'q': 'dart'},
            ),
          ],
        ),
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_1',
              toolName: 'lookup',
              result: {'ok': true},
            ),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(2));

      final functionCall = list.first.parts.single as fai.FunctionCall;
      expect(functionCall.id, 'call_1');
      expect(functionCall.name, 'lookup');

      final functionResponse = list.last.parts.single as fai.FunctionResponse;
      expect(functionResponse.id, 'call_1');
      expect(functionResponse.name, 'lookup');
    });

    test('maps ThinkingPart in model messages', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.model,
          parts: const [
            ThinkingPart('Let me think...'),
            TextPart('The answer is 42.'),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      final parts = list.single.parts;
      expect(parts, hasLength(2));

      final thinkingPart = parts[0] as fai.TextPart;
      expect(thinkingPart.text, 'Let me think...');
      expect(thinkingPart.isThought, isTrue);

      final textPart = parts[1] as fai.TextPart;
      expect(textPart.text, 'The answer is 42.');
      expect(textPart.isThought, isNot(isTrue));
    });

    test('groups consecutive tool results into single response content', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_1',
              toolName: 'lookup',
              result: {'ok': true},
            ),
          ],
        ),
        ChatMessage(
          role: ChatMessageRole.user,
          parts: const [
            ToolPart.result(
              callId: 'call_2',
              toolName: 'search',
              result: {'items': 3},
            ),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      expect(list.single.parts.length, 2);
      expect(list.single.parts.first, isA<fai.FunctionResponse>());
      expect(list.single.parts.last, isA<fai.FunctionResponse>());
    });

    test('maps LinkPart to FileData', () {
      final list = [
        ChatMessage(
          role: ChatMessageRole.user,
          parts: [
            LinkPart(
              Uri.parse('gs://bucket/file.pdf'),
              mimeType: 'application/pdf',
            ),
          ],
        ),
      ].toContentList();

      expect(list, hasLength(1));
      final part = list.single.parts.single;
      expect(part, isA<fai.FileData>());
      final fileData = part as fai.FileData;
      expect(fileData.fileUri, 'gs://bucket/file.pdf');
      expect(fileData.mimeType, 'application/pdf');
    });

    test('maps tools to firebase tool declarations', () {
      final tools = [
        Tool<Map<String, dynamic>>(
          name: 'search',
          description: 'Search docs',
          inputSchema: Schema.fromMap({
            'type': 'object',
            'properties': {
              'q': {'type': 'string'},
            },
          }),
          onCall: (input) => input,
        ),
      ];

      final firebaseTools = tools.toToolList(enableCodeExecution: false);
      expect(firebaseTools, isNotNull);
      expect(firebaseTools, isNotEmpty);
    });

    test('maps safety settings', () {
      final settings = [
        const FirebaseAISafetySetting(
          category: FirebaseAISafetySettingCategory.harassment,
          threshold: FirebaseAISafetySettingThreshold.blockLowAndAbove,
        ),
      ];
      final mapped = settings.toSafetySettings();
      expect(mapped, hasLength(1));
    });
  });

  group('response mapper', () {
    group('tool call IDs', () {
      test('uses SDK-provided FunctionCall.id when present', () {
        final response = _makeResponse([
          const fai.FunctionCall('get_weather', {
            'city': 'NYC',
          }, id: 'sdk-id-123'),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');
        final toolCall = result.output.parts.single as ToolPart;

        expect(toolCall.callId, 'sdk-id-123');
        expect(toolCall.toolName, 'get_weather');
        expect(toolCall.arguments, {'city': 'NYC'});
      });

      test('generates UUID when FunctionCall.id is null', () {
        final response = _makeResponse([
          const fai.FunctionCall('search', {'q': 'dart'}),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');
        final toolCall = result.output.parts.single as ToolPart;

        expect(toolCall.callId, isNotEmpty);
        expect(toolCall.callId, isNot(contains('#')));
        expect(toolCall.callId.length, greaterThan(10));
        expect(toolCall.toolName, 'search');
      });

      test('generates UUID when FunctionCall.id is empty', () {
        final response = _makeResponse([
          const fai.FunctionCall('search', {'q': 'dart'}, id: ''),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');
        final toolCall = result.output.parts.single as ToolPart;

        expect(toolCall.callId, isNotEmpty);
        expect(toolCall.callId.length, greaterThan(10));
      });

      test('generates unique IDs for multiple tool calls', () {
        final response = _makeResponse([
          const fai.FunctionCall('tool_a', {}),
          const fai.FunctionCall('tool_b', {}),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');
        final toolCalls = result.output.parts.whereType<ToolPart>().toList();

        expect(toolCalls, hasLength(2));
        expect(toolCalls[0].callId, isNot(toolCalls[1].callId));
      });
    });

    group('thinking support', () {
      test('maps isThought TextPart to ThinkingPart', () {
        final response = _makeResponse([
          const fai.TextPart('I need to reason...', isThought: true),
          const fai.TextPart('The answer is 42.'),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');
        final parts = result.output.parts;

        expect(parts, hasLength(2));
        expect(parts[0], isA<ThinkingPart>());
        expect((parts[0] as ThinkingPart).text, 'I need to reason...');
        expect(parts[1], isA<TextPart>());
        expect((parts[1] as TextPart).text, 'The answer is 42.');
      });

      test('sets thinking delta on ChatResult', () {
        final response = _makeResponse([
          const fai.TextPart('thinking content', isThought: true),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');

        expect(result.thinking, 'thinking content');
      });

      test('thinking is null when no thinking parts exist', () {
        final response = _makeResponse([const fai.TextPart('Hello!')]);

        final result = response.toChatResult('gemini-2.5-flash');

        expect(result.thinking, isNull);
      });

      test('non-thought TextPart is not treated as thinking', () {
        final response = _makeResponse([
          const fai.TextPart('regular text', isThought: false),
        ]);

        final result = response.toChatResult('gemini-2.5-flash');

        expect(result.output.parts.single, isA<TextPart>());
        expect(result.thinking, isNull);
      });
    });

    group('streaming messages contract', () {
      test('streaming chunk has messages: const []', () {
        final response = _makeResponse([const fai.TextPart('Hello world')]);

        final result = response.toChatResult('gemini-2.5-flash');

        expect(result.messages, isEmpty);
        expect(result.output.parts, isNotEmpty);
      });

      test('output contains the chunk content', () {
        final response = _makeResponse([const fai.TextPart('chunk text')]);

        final result = response.toChatResult('gemini-2.5-flash');
        final text = result.output.parts.whereType<TextPart>().single.text;

        expect(text, 'chunk text');
        expect(result.output.role, ChatMessageRole.model);
      });
    });

    group('finish reason mapping', () {
      test('maps stop', () {
        final result = _makeResponse([
          const fai.TextPart('done'),
        ], finishReason: fai.FinishReason.stop).toChatResult('m');
        expect(result.finishReason, FinishReason.stop);
      });

      test('maps maxTokens to length', () {
        final result = _makeResponse([
          const fai.TextPart('...'),
        ], finishReason: fai.FinishReason.maxTokens).toChatResult('m');
        expect(result.finishReason, FinishReason.length);
      });

      test('maps safety to contentFilter', () {
        final result = _makeResponse([
          const fai.TextPart(''),
        ], finishReason: fai.FinishReason.safety).toChatResult('m');
        expect(result.finishReason, FinishReason.contentFilter);
      });

      test('maps null to unspecified', () {
        final result = _makeResponse([
          const fai.TextPart('hi'),
        ]).toChatResult('m');
        expect(result.finishReason, FinishReason.unspecified);
      });
    });

    test('skips empty text parts', () {
      final response = _makeResponse([
        const fai.TextPart(''),
        const fai.TextPart('real'),
      ]);

      final result = response.toChatResult('m');

      expect(result.output.parts, hasLength(1));
      expect((result.output.parts.single as TextPart).text, 'real');
    });
  });
}
