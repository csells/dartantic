import '../agent/agent.dart';

/// Gets the value of an environment variable.
///
/// For web, this function only checks the `Agent.environment` map.
/// Throws an exception if the variable is not set or is empty.
String getEnv(String key) {
  final value = Agent.environment[key];
  if (value == null) {
    throw Exception(
      'Environment variable $key not found. Set it in Agent.environment, or '
      'pass it to the Agent/Provider manually.',
    );
  }
  return value;
}
