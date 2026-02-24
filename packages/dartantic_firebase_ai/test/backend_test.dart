import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_firebase.dart';

void main() {
  group('FirebaseAIProvider backends', () {
    setUpAll(() async {
      await initializeMockFirebase();
    });

    test('defaults to GoogleAI backend', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      expect(provider.backend, FirebaseAIBackend.googleAI);
      expect(provider.displayName, 'Firebase AI (Google AI)');
    });

    test('supports GoogleAI backend', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      expect(provider.backend, FirebaseAIBackend.googleAI);
      expect(provider.displayName, 'Firebase AI (Google AI)');
      expect(provider.aliases, contains('firebase-google'));
    });

    test('model defaults are exposed on provider', () {
      final provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
      expect(provider.defaultModelNames[ModelKind.chat], 'gemini-2.5-flash');
      expect(
        provider.defaultModelNames[ModelKind.media],
        'gemini-2.5-flash-image',
      );
    });
  });
}
