/// TESTING PHILOSOPHY:
/// 1. DO NOT catch exceptions - let them bubble up for diagnosis
/// 2. DO NOT add provider filtering except by capabilities (e.g.
///    ProviderTestCaps)
/// 3. DO NOT add performance tests
/// 4. DO NOT add regression tests
/// 5. 80% cases = common usage patterns tested across ALL capable providers
/// 6. Edge cases = rare scenarios tested on Google only to avoid timeouts
/// 7. Each functionality should only be tested in ONE file - no duplication

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:test/test.dart';

void main() {
  group('Provider httpClient parameter', () {
    test('OpenAIProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = OpenAIProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('OpenAIResponsesProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = OpenAIResponsesProvider(
        apiKey: 'k',
        httpClient: tracking,
      );
      expect(provider.httpClient, same(tracking));
    });

    test('XAIProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = XAIProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('CohereProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = CohereProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('XAIResponsesProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = XAIResponsesProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('AnthropicProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = AnthropicProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('GoogleProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = GoogleProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('MistralProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = MistralProvider(apiKey: 'k', httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('OllamaProvider stores httpClient', () {
      final tracking = TrackingHttpClient();
      final provider = OllamaProvider(httpClient: tracking);
      expect(provider.httpClient, same(tracking));
    });

    test('http.RetryClient is passed through unwrapped', () {
      final retryClient = RetryClient(
        http.Client(),
        retries: 3,
        when: (response) => response.statusCode == 429,
      );
      final provider = GoogleProvider(
        apiKey: 'test-api-key',
        httpClient: retryClient,
      );
      expect(provider.httpClient, same(retryClient));
    });
  });
}

/// HTTP client that tracks every request without modifying the response.
///
/// Defined inline because the parallel `test/custom_http_client_test.dart`
/// uses a different `TrackingHttpClient` shape; we keep the tests
/// independent.
class TrackingHttpClient extends http.BaseClient {
  TrackingHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;
  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
