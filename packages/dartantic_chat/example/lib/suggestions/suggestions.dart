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
  static const title = 'Example: Suggestions';

  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: title,
    home: ChatPage(),
    debugShowCheckedModeBanner: false,
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _provider = DartanticProvider(agent: Agent('gemini'));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(App.title),
      actions: [
        IconButton(onPressed: _clearHistory, icon: const Icon(Icons.history)),
      ],
    ),
    body: AgentChatView(
      provider: _provider,
      suggestions: const [
        'Tell me a joke.',
        'Write me a limerick.',
        'Perform a haiku.',
      ],
    ),
  );

  void _clearHistory() => _provider.history = [];
}
