// ignore_for_file: non_constant_identifier_names

import 'dart:io';

class Env {
  static final GEMINI_API_KEY = Platform.environment['GEMINI_API_KEY'];
  static final OPENAI_API_KEY = Platform.environment['OPENAI_API_KEY'];
  static final OPENROUTER_API_KEY = Platform.environment['OPENROUTER_API_KEY'];

  static String tryGet(String key, {String? defaultValue}) {
    final value = switch (key) {
      'GEMINI_API_KEY' => GEMINI_API_KEY,
      'OPENAI_API_KEY' => OPENAI_API_KEY,
      'OPENROUTER_API_KEY' => OPENROUTER_API_KEY,
      _ => throw Exception('Unknown environment variable: $key'),
    };

    if (value == null) {
      if (defaultValue != null) return defaultValue;
      throw Exception('Environment variable $key is not set');
    }
    return value;
  }

  static Map<String, String> get tryAll => {
    'GEMINI_API_KEY': tryGet('GEMINI_API_KEY'),
    'OPENAI_API_KEY': tryGet('OPENAI_API_KEY'),
    'OPENROUTER_API_KEY': tryGet('OPENROUTER_API_KEY'),
  };
}
