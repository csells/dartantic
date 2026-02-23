import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:test/test.dart';

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
void runProviderTest(
  String description,
  Future<void> Function(FirebaseAIProvider provider) testFunction, {
  Set<ProviderTestCaps>? requiredCaps,
  Timeout? timeout,
  Set<String>? skipProviders,
}) {
  final normalizedSkips =
      skipProviders?.map((name) => name.toLowerCase()).toSet() ?? const {};

  final entries = providerTestCaps.entries.where(
    (entry) =>
        requiredCaps == null ||
        providerHasTestCaps(entry.key, requiredCaps),
  );

  for (final entry in entries) {
    final providerName = entry.key;
    final provider = entry.value.provider;
    final isSkipped = normalizedSkips.contains(providerName);

    test(
      '$providerName: $description',
      () async {
        await testFunction(provider);
      },
      timeout: timeout,
      skip: isSkipped,
    );
  }
}
