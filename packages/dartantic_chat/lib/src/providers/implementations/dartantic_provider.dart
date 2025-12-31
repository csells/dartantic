// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/foundation.dart';

import '../interface/chat_history_provider.dart';

/// A chat history provider implementation using dartantic_ai.
///
/// This provider uses the dartantic_ai Agent to interact with various LLM
/// providers (OpenAI, Anthropic, Google, etc.) and maintains chat history.
class DartanticProvider extends ChatHistoryProvider with ChangeNotifier {
  /// Creates a [DartanticProvider] with the given agent.
  ///
  /// [agent] is the dartantic Agent instance to use for LLM interactions.
  /// [history] is an optional initial chat history.
  /// [systemPrompt] is an optional system prompt to include at the start
  /// of conversations.
  DartanticProvider({
    required Agent agent,
    Iterable<ChatMessage>? history,
    String? systemPrompt,
  }) : _agent = agent,
       _systemPrompt = systemPrompt {
    if (history != null) {
      _messages.addAll(history);
    }
  }

  final Agent _agent;
  final String? _systemPrompt;
  final List<ChatMessage> _messages = [];

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    // Use the LLM to transcribe the attached audio to text
    const prompt =
        'translate the attached audio to text; provide the result of that '
        'translation as just the text of the translation itself. be careful to '
        'separate the background audio from the foreground audio and only '
        'provide the result of translating the foreground audio.';

    final attachment = await DataPart.fromFile(audioFile);

    // Use generateStream without affecting main history
    final historyForTranscription = [
      if (_systemPrompt != null) ChatMessage.system(_systemPrompt),
    ];

    await for (final result in _agent.sendStream(
      prompt,
      history: historyForTranscription,
      attachments: [attachment],
    )) {
      if (result.output.isNotEmpty) {
        yield result.output;
      }
    }
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Part> attachments = const [],
  }) async* {
    // Create user message with text and attachments
    final userMessage = ChatMessage.user(prompt, parts: attachments.toList());
    _messages.add(userMessage);

    // Build history with optional system prompt
    final historyForAgent = [
      if (_systemPrompt != null) ChatMessage.system(_systemPrompt),
      ..._messages,
    ];

    // Stream the response
    final buffer = StringBuffer();
    ChatMessage? modelMessage;

    await for (final result in _agent.sendStream(
      prompt,
      history: historyForAgent.sublist(
        0,
        historyForAgent.length - 1,
      ), // exclude the user message we just added
      attachments: attachments.toList(),
    )) {
      // Accumulate text output
      if (result.output.isNotEmpty) {
        buffer.write(result.output);
        yield result.output;
      }

      // Capture the model message if present
      for (final message in result.messages) {
        if (message.role == ChatMessageRole.model) {
          modelMessage = message;
        }
      }
    }

    // Add the completed model response to history
    final finalText = buffer.toString();
    if (modelMessage != null) {
      _messages.add(modelMessage);
    } else if (finalText.isNotEmpty) {
      _messages.add(ChatMessage.model(finalText));
    }

    notifyListeners();
  }

  @override
  Iterable<ChatMessage> get history => _messages;

  @override
  set history(Iterable<ChatMessage> history) {
    _messages.clear();
    _messages.addAll(history);
    notifyListeners();
  }
}
