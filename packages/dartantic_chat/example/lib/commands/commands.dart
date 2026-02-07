// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  static const title = 'Example: Command Menu';

  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: title,
    theme: ThemeData.light(),
    darkTheme: ThemeData.dark(),
    home: const ChatPage(),
    debugShowCheckedModeBanner: false,
  );
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: AgentChatView(
      provider: EchoProvider(),
      welcomeMessage: '''
Welcome to the Commands Example!

Type a forward slash `/` at the beginning of the input or after a space to see the command menu.

Try these:
1. Type `/`
2. Type `hello /`
3. Type `check this / out` (move caret to space and type `/`)

The menu follows your text caret horizontally!
''',
      suggestions: const [
        'Tell me a joke',
        'What is the weather like?',
        'How do I use slash commands?',
      ],
      commands: [
        ChatCommand(
          name: 'Help',
          icon: Icons.help_outline,
          keywords: ['help', 'support', 'guide'],
          onPressed: () {
            // In a real app, this could open a dialog or navigate to a help page
            debugPrint('Help command triggered!');
          },
        ),
      ],
    ),
  );
}
