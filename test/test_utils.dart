// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

final allProviders = [
  for (final providerName in ProviderTable.providers.keys)
    Agent.providerFor(providerName),
];

Stream<T> rateLimitRetryStream<T>(
  Stream<T> Function() fn, {
  int retries = 1,
}) async* {
  for (var attempts = 0; attempts < retries; ++attempts) {
    try {
      yield* fn();
    } on openai.OpenAIClientException catch (ex) {
      final waitTimeMs = _retryWait(ex, attempts);
      if (waitTimeMs > 0) {
        await Future.delayed(Duration(milliseconds: waitTimeMs));
      } else {
        // Not a rate limit error or retries exhausted, rethrow
        rethrow;
      }
    }
  }
}

Future<T> rateLimitRetry<T>(Future<T> Function() fn, {int retries = 1}) async {
  for (var attempts = 0; attempts < retries; ++attempts) {
    try {
      return await fn();
    } on openai.OpenAIClientException catch (e) {
      final waitTimeMs = _retryWait(e, attempts);
      if (waitTimeMs > 0) {
        await Future.delayed(Duration(milliseconds: waitTimeMs));
      } else {
        // Not a rate limit error or retries exhausted, rethrow
        rethrow;
      }
    }
  }

  // If we get here, all retries were exhausted
  throw Exception('All retry attempts failed after $retries attempts');
}

int _retryWait(openai.OpenAIClientException ex, int attempts) {
  // Check if it's a rate limit error (code 429)
  if (ex.code != 429) return 0;

  // Try to parse the wait time from the error message
  final errorBody = ex.body;
  if (errorBody is Map<String, dynamic> &&
      errorBody['error'] is Map<String, dynamic>) {
    final errorMap = errorBody['error'] as Map<String, dynamic>;
    final errorMessage = errorMap['message'] as String?;

    if (errorMessage != null) {
      // Extract wait time using regex
      final regex = RegExp(r'Please try again in (\d+)ms');
      final match = regex.firstMatch(errorMessage);

      if (match != null && match.groupCount >= 1) {
        final waitTimeMs = int.tryParse(match.group(1)!) ?? 1000;
        print(
          'Rate limit hit. Waiting ${waitTimeMs}ms before retry. '
          'Attempt: $attempts',
        );
        return waitTimeMs;
      }
    }
  }

  // If we couldn't parse the wait time, use exponential backoff
  final backoffMs = 200 * (1 << (attempts - 1)); // 200ms, 400ms, 800ms, etc.

  print(
    'Rate limit hit. Using exponential backoff: ${backoffMs}ms. '
    'Attempt: $attempts',
  );

  return backoffMs;
}

extension AgentRetryExtension on Agent {
  Future<AgentResponse> runWithRetries(
    String prompt, {
    Iterable<Message> messages = const [],
    Iterable<Part> attachments = const [],
    int retries = 1,
  }) => rateLimitRetry(
    () => run(prompt, messages: messages, attachments: attachments),
    retries: retries,
  );

  Future<AgentResponseFor<T>> runForWithRetries<T>(
    String prompt, {
    Iterable<Message> messages = const [],
    Iterable<Part> attachments = const [],
    int retries = 1,
  }) => rateLimitRetry<AgentResponseFor<T>>(
    () => runFor<T>(prompt, messages: messages, attachments: attachments),
    retries: retries,
  );

  Stream<AgentResponse> runStreamWithRetries(
    String prompt, {
    Iterable<Message> messages = const [],
    Iterable<Part> attachments = const [],
    int retries = 1,
  }) => rateLimitRetryStream<AgentResponse>(
    () => runStream(prompt, messages: messages, attachments: attachments),
    retries: retries,
  );
}
