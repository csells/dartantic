// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/foundation.dart';

import 'package:dartantic_chat/src/llm_exception.dart';
import 'package:dartantic_chat/src/providers/interface/chat_history_provider.dart';

/// A configurable chat history provider for testing purposes.
///
/// This provider allows fine-grained control over streaming behavior,
/// delays, and error conditions for comprehensive testing.
class TestEchoProvider extends ChatHistoryProvider with ChangeNotifier {
  TestEchoProvider({
    Iterable<ChatMessage>? history,
    this.responseDelay = Duration.zero,
    this.chunkDelay = Duration.zero,
    this.transcriptionDelay = Duration.zero,
    this.shouldCancel = false,
    this.shouldFail = false,
    this.failureMessage = 'Test failure',
    this.customResponse,
    this.onMessageSent,
  }) : _history = List<ChatMessage>.from(history ?? []);

  final List<ChatMessage> _history;

  /// Delay before starting to stream the response.
  final Duration responseDelay;

  /// Delay between each chunk of the response.
  final Duration chunkDelay;

  /// Delay before completing transcription.
  final Duration transcriptionDelay;

  /// If true, throws LlmCancelException during streaming.
  final bool shouldCancel;

  /// If true, throws LlmFailureException during streaming.
  final bool shouldFail;

  /// The message to include in the failure exception.
  final String failureMessage;

  /// Custom response to return instead of echoing the prompt.
  final String? customResponse;

  /// Callback invoked when a message is sent (for testing message flow).
  final void Function(String prompt, Iterable<Part> attachments)? onMessageSent;

  /// Tracks the number of messages sent for testing.
  int messagesSent = 0;

  /// Tracks the last prompt sent for testing.
  String? lastPrompt;

  /// Tracks the last attachments sent for testing.
  List<Part>? lastAttachments;

  /// The current streaming completer for cancel testing.
  Completer<void>? _streamCompleter;

  /// Cancels the current streaming operation.
  void cancelStream() {
    _streamCompleter?.completeError(const LlmCancelException());
  }

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    if (transcriptionDelay > Duration.zero) {
      await Future.delayed(transcriptionDelay);
    }
    yield 'Transcribed: ${audioFile.name}';
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) async* {
    // Track message info for testing
    messagesSent++;
    lastPrompt = prompt;
    lastAttachments = attachments.toList();
    onMessageSent?.call(prompt, attachments);

    // Add user message to history
    final userMessage = ChatMessage.user(prompt, parts: attachments.toList());
    _history.add(userMessage);

    _streamCompleter = Completer<void>();

    if (responseDelay > Duration.zero) {
      await Future.delayed(responseDelay);
    }

    if (shouldFail) {
      throw LlmFailureException(failureMessage);
    }

    final response = customResponse ?? 'Echo: $prompt';
    final chunks = response.split(' ');
    final buffer = StringBuffer();

    for (var i = 0; i < chunks.length; i++) {
      // Check for cancellation
      if (_streamCompleter?.isCompleted == true) {
        throw const LlmCancelException();
      }

      if (shouldCancel && i == chunks.length ~/ 2) {
        throw const LlmCancelException();
      }

      if (chunkDelay > Duration.zero) {
        await Future.delayed(chunkDelay);
      }

      final chunk = i == 0 ? chunks[i] : ' ${chunks[i]}';
      buffer.write(chunk);
      yield chunk;
    }

    // Add completed model message to history
    _history.add(ChatMessage.model(buffer.toString()));
    _streamCompleter?.complete();
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

/// A provider that allows controlling when responses complete.
class ControllableProvider extends ChatHistoryProvider with ChangeNotifier {
  ControllableProvider({Iterable<ChatMessage>? history})
    : _history = List<ChatMessage>.from(history ?? []);

  final List<ChatMessage> _history;
  StreamController<String>? _currentController;
  final StringBuffer _currentResponse = StringBuffer();

  /// Yields a chunk to the current stream.
  void yieldChunk(String chunk) {
    _currentResponse.write(chunk);
    _currentController?.add(chunk);
  }

  /// Completes the current stream successfully.
  void complete() {
    _history.add(ChatMessage.model(_currentResponse.toString()));
    _currentController?.close();
    _currentController = null;
    _currentResponse.clear();
    notifyListeners();
  }

  /// Completes the current stream with a cancel exception.
  void cancel() {
    _currentController?.addError(const LlmCancelException());
    _currentController?.close();
    _currentController = null;
    _currentResponse.clear();
  }

  /// Completes the current stream with a failure exception.
  void fail(String message) {
    _currentController?.addError(LlmFailureException(message));
    _currentController?.close();
    _currentController = null;
    _currentResponse.clear();
  }

  /// Whether a stream is currently active.
  bool get isStreaming => _currentController != null;

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    yield 'Transcribed: ${audioFile.name}';
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) {
    final userMessage = ChatMessage.user(prompt, parts: attachments.toList());
    _history.add(userMessage);

    _currentController = StreamController<String>();
    return _currentController!.stream;
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
