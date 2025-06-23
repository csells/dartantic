import 'dart:io';

import '../agent/agent.dart';

/// Gets the value of an environment variable.
///
/// Retrieves the value of the environment variable with the given [key].
/// It first checks the `Agent.environment` map, then falls back to
/// `Platform.environment`.
///
/// Throws an exception if the variable is not set or is empty in either
/// location.
String getEnv(String key) {
  final value = Agent.environment[key] ?? Platform.environment[key];
  if (value == null) {
    throw Exception(
      'Environment variable $key not found. Set it in Agent.environment, '
      'the platform environment, or pass it to the Agent/Provider manually.',
    );
  }
  return value;
}
