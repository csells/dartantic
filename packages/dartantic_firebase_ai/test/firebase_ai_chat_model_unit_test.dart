import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:test/test.dart';

import 'mock_firebase.dart';

const _testBaseUrl = 'https://test-firebase-ai.googleapis.com/v1';

void main() {
  group('FirebaseAIChatModel', () {
    setUpAll(() async {
      await initializeMockFirebase();
    });

    test('constructs with defaults', () {
      final model = FirebaseAIChatModel(
        baseUrl: Uri.parse(_testBaseUrl),
        name: 'gemini-2.5-flash',
      );

      expect(model.name, 'gemini-2.5-flash');
      expect(model.backend, FirebaseAIBackend.vertexAI);
      expect(model.defaultOptions, isA<FirebaseAIChatModelOptions>());
    });

    test('filters return_result tool', () {
      final model = FirebaseAIChatModel(
        baseUrl: Uri.parse(_testBaseUrl),
        name: 'gemini-2.5-flash',
        tools: [
          Tool<Map<String, dynamic>>(
            name: 'return_result',
            description: 'internal',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
          Tool<Map<String, dynamic>>(
            name: 'kept_tool',
            description: 'kept',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
        ],
      );

      expect(model.tools, hasLength(1));
      expect(model.tools!.single.name, 'kept_tool');
    });

    test('sendStream accepts Schema outputSchema', () {
      final model = FirebaseAIChatModel(
        baseUrl: Uri.parse(_testBaseUrl),
        name: 'gemini-2.5-flash',
      );
      final schema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'result': {'type': 'string'},
        },
      });

      final stream = model.sendStream([
        ChatMessage.user('Return JSON'),
      ], outputSchema: schema);
      expect(stream, isA<Stream<ChatResult<ChatMessage>>>());
    });

    test('rejects tools and outputSchema together', () {
      final model = FirebaseAIChatModel(
        baseUrl: Uri.parse(_testBaseUrl),
        name: 'gemini-2.5-flash',
        tools: [
          Tool<Map<String, dynamic>>(
            name: 'lookup',
            description: 'lookup',
            inputSchema: Schema.fromMap({'type': 'object'}),
            onCall: (input) => input,
          ),
        ],
      );
      final schema = Schema.fromMap({'type': 'object'});

      expect(
        () => model.sendStream([ChatMessage.user('run')], outputSchema: schema),
        throwsArgumentError,
      );
    });
  });
}
