import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:test/test.dart';

import '../mock_firebase.dart';

/// Capabilities of a provider's default model for testing purposes.
enum ProviderTestCaps {
  /// The provider supports chat.
  chat,

  /// The provider can generate media assets.
  mediaGeneration,

  /// The provider can stream or return model reasoning ("thinking").
  thinking,
}

/// Test-only mapping of Firebase provider variants to test capabilities.
final providerTestCaps =
    <String, ({FirebaseAIProvider provider, Set<ProviderTestCaps> caps})>{
      'firebase-google': (
        provider: FirebaseAIProvider(backend: FirebaseAIBackend.googleAI),
        caps: {
          ProviderTestCaps.chat,
          ProviderTestCaps.mediaGeneration,
          ProviderTestCaps.thinking,
        },
      ),
      'firebase-vertex': (
        provider: FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI),
        caps: {
          ProviderTestCaps.chat,
          ProviderTestCaps.mediaGeneration,
          ProviderTestCaps.thinking,
        },
      ),
    };

/// Returns true if the provider has all the required capabilities for testing.
bool providerHasTestCaps(
  String providerName,
  Set<ProviderTestCaps> requiredCaps,
) {
  final entry = providerTestCaps[providerName];
  if (entry == null) return false;
  return requiredCaps.every(entry.caps.contains);
}

/// Runs a parameterized test across Firebase providers selected by caps.
///
/// When [integration] is true, tests are skipped unless real Firebase
/// credentials (`FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID`) are available in the
/// environment. Integration tests only run against the `firebase-google`
/// backend to keep CI simple.
void runProviderTest(
  String description,
  Future<void> Function(FirebaseAIProvider provider) testFunction, {
  Set<ProviderTestCaps>? requiredCaps,
  bool integration = false,
  Timeout? timeout,
  Set<String>? skipProviders,
}) {
  final normalizedSkips =
      skipProviders?.map((name) => name.toLowerCase()).toSet() ?? const {};

  var entries = providerTestCaps.entries.where(
    (entry) =>
        requiredCaps == null ||
        providerHasTestCaps(entry.key, requiredCaps),
  );

  if (integration) {
    entries = entries.where((e) => e.key == 'firebase-google');
  }

  for (final entry in entries) {
    final providerName = entry.key;
    final provider = entry.value.provider;
    final isSkipped = normalizedSkips.contains(providerName);

    final skipReason = integration && !hasFirebaseCredentials
        ? 'Integration test requires FIREBASE_API_KEY and FIREBASE_PROJECT_ID'
        : (isSkipped ? '' : null);

    test(
      '$providerName: $description',
      () async {
        await testFunction(provider);
      },
      timeout: timeout,
      skip: skipReason ?? isSkipped,
    );
  }
}
