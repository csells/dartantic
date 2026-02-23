// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

/// An example demonstrating how to create a restricted chat interface
/// where attachments and voice notes are disabled.
void main() {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  runApp(const App());
}

/// A Flutter application that demonstrates a restricted chat interface.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: const ChatPage(), debugShowCheckedModeBanner: false);
}

/// A screen that displays a restricted chat interface.
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restricted Chat')),
    body: AgentChatView(
      provider: DartanticProvider(agent: Agent('gemini')),
      enableAttachments: false,
      enableVoiceNotes: false,
    ),
  );
}
