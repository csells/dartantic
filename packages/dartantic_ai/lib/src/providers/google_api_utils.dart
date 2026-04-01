import 'package:googleai_dart/googleai_dart.dart';
import 'package:http/http.dart' as http;

/// Shared helpers for Google Gemini provider and models.
class GoogleApiConfig {
  GoogleApiConfig._();

  /// Default base URL for the Google Gemini API (includes API version path).
  static final Uri defaultBaseUrl = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta',
  );
}

/// Normalizes a Google model name to include the required `models/` prefix.
String normalizeGoogleModelName(String model) =>
    model.contains('/') ? model : 'models/$model';

/// Strips the `models/` resource prefix for stream/embed model URL segments.
String googleModelIdForApiRequest(String model) {
  final n = normalizeGoogleModelName(model);
  const prefix = 'models/';
  return n.startsWith(prefix) ? n.substring(prefix.length) : n;
}

/// Determines the API version based on the base URL.
ApiVersion googleClientApiVersion(Uri configured) {
  final str = configured.toString();
  return str.endsWith('/v1beta') ? ApiVersion.v1beta : ApiVersion.v1;
}

/// Removes a trailing `/v1` or `/v1beta` segment so [GoogleAIConfig.apiVersion]
/// supplies the version path exactly once.
Uri googleClientBaseUriWithoutVersion(Uri configured) {
  var str = configured.toString();
  if (str.endsWith('/')) {
    str = str.substring(0, str.length - 1);
  }
  for (final suffix in ['/v1beta', '/v1']) {
    if (str.endsWith(suffix)) {
      return Uri.parse(str.substring(0, str.length - suffix.length));
    }
  }
  return configured;
}

/// Creates a [GoogleAIClient] for the Gemini Developer API with API-key header
/// auth, matching prior `x-goog-api-key` behavior.
GoogleAIClient createGoogleAiClient({
  required String apiKey,
  required Uri configuredBaseUrl,
  Map<String, String> extraHeaders = const {},
  http.Client? httpClient,
}) {
  final baseUri = googleClientBaseUriWithoutVersion(configuredBaseUrl);
  final apiVersion = googleClientApiVersion(configuredBaseUrl);
  return GoogleAIClient(
    config: GoogleAIConfig(
      baseUrl: baseUri.toString(),
      apiVersion: apiVersion,
      authProvider: ApiKeyProvider(apiKey, placement: AuthPlacement.header),
      defaultHeaders: extraHeaders,
    ),
    httpClient: httpClient ?? http.Client(),
  );
}
