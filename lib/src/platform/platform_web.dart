/// Gets the value of an environment variable.
///
/// Throws an exception because environment variables are not supported on the
/// web.
String getEnv(String key) {
  throw Exception(
    'Environment variable $key is not supported on the web. '
    'Set Agent.apiKey or Provider.apiKey explicitly.',
  );
}
