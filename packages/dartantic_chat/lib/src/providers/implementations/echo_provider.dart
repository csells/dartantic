// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/foundation.dart';

import '../../llm_exception.dart';
import '../interface/chat_history_provider.dart';

/// A simple chat history provider that echoes the input prompt and attachment
/// information.
///
/// This provider is primarily used for testing and debugging purposes.
class EchoProvider extends ChatHistoryProvider with ChangeNotifier {
  /// Creates an [EchoProvider] instance with an optional chat history.
  ///
  /// The [history] parameter is an optional iterable of [ChatMessage] objects
  /// representing the chat history. If provided, it will be converted to a list
  /// and stored internally. If not provided, an empty list will be used.
  EchoProvider({Iterable<ChatMessage>? history})
    : _history = List<ChatMessage>.from(history ?? []);

  final List<ChatMessage> _history;

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    await Future.delayed(const Duration(milliseconds: 500));
    yield 'Transcribed audio from: ${audioFile.name}';
  }

  Stream<String> _generateStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) async* {
    if (prompt == 'FAILFAST') throw const LlmFailureException('Failing fast!');

    await Future.delayed(const Duration(milliseconds: 1000));
    yield '# Echo\n';

    switch (prompt) {
      case 'CANCEL':
        throw const LlmCancelException();
      case 'FAIL':
        throw const LlmFailureException('User requested failure');
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    yield prompt;

    yield '\n\n# Attachments\n${attachments.map((a) => a.toString())}';
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) async* {
    // Add user message to history
    final userMessage = ChatMessage.user(prompt, parts: attachments.toList());
    _history.add(userMessage);

    // Generate response and collect it
    final buffer = StringBuffer();
    final response = _generateStream(prompt, attachments: attachments);

    await for (final chunk in response) {
      buffer.write(chunk);
      yield chunk;
    }

    // Add completed model message to history
    _history.add(ChatMessage.model(buffer.toString()));
    notifyListeners();
  }

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }
}
