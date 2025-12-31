// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  runApp(const App());
}

class App extends StatelessWidget {
  static const title = 'Example: Logging';

  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: title, home: ChatPage());
}

class ChatPage extends StatelessWidget {
  ChatPage({super.key});
  final _provider = DartanticProvider(agent: Agent('gemini'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(App.title)),
      body: AgentChatView(provider: _provider, messageSender: _logMessage),
    );
  }

  Stream<String> _logMessage(
    String prompt, {
    required Iterable<Part> attachments,
  }) async* {
    // log the message and attachments
    debugPrint('# Sending Message');
    debugPrint('## Prompt\n$prompt');
    debugPrint('## Attachments\n${attachments.map((a) => a.toString())}');

    // forward the message on to the provider
    final response = _provider.sendMessageStream(
      prompt,
      attachments: attachments,
    );

    // log the response and yield it
    await for (final chunk in response) {
      debugPrint('## Response chunk: $chunk');
      yield chunk;
    }
  }
}
