// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

import '../dark_style.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  runApp(const App());
}

class App extends StatelessWidget {
  static const title = 'Example: Dark Mode';
  static final themeMode = ValueNotifier(ThemeMode.dark);

  const App({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeMode,
    builder:
        (BuildContext context, ThemeMode mode, Widget? child) => MaterialApp(
          title: title,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: mode,
          home: ChatPage(),
          debugShowCheckedModeBanner: false,
        ),
  );
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _provider = DartanticProvider(agent: Agent('gemini'));

  final _lightStyle = ChatViewStyle.defaultStyle();
  final _darkStyle = darkChatViewStyle();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(App.title),
      actions: [
        IconButton(
          onPressed:
              () =>
                  App.themeMode.value =
                      App.themeMode.value == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light,
          tooltip:
              App.themeMode.value == ThemeMode.light
                  ? 'Dark Mode'
                  : 'Light Mode',
          icon: const Icon(Icons.brightness_4_outlined),
        ),
      ],
    ),
    body: AgentChatView(
      provider: _provider,
      style: App.themeMode.value == ThemeMode.dark ? _darkStyle : _lightStyle,
    ),
  );
}
