// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  static const title = 'Example: Simulated File Upload';

  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: title, home: ChatPage());
}

class ChatPage extends StatelessWidget {
  ChatPage({super.key});

  // Using the EchoProvider to simulate the image upload w/o actually uploading
  // the files to the cloud.
  final _provider = EchoProvider();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(App.title)),
      body: AgentChatView(provider: _provider, messageSender: _imageUploader),
    );
  }

  Stream<String> _imageUploader(
    String prompt, {
    required Iterable<Part> attachments,
  }) async* {
    List<Part> newAttachments = [];
    for (final attachment in attachments) {
      // simulate uploading files and replacing them with links
      newAttachments.add(switch (attachment) {
        DataPart(mimeType: final m) when m.startsWith('image/') => LinkPart(
          Uri.parse(
            'https://upload.wikimedia.org/wikipedia/commons/4/4f/Kitty_emoji.png',
          ),
          name: 'kitty.png',
        ),
        DataPart() => LinkPart(
          Uri.parse('https://en.wikipedia.org/wiki/Schalin'),
          name: 'short.txt',
        ),
        LinkPart() => attachment,
        _ => attachment,
      });
    }

    // forward the message on to the provider using the new attachments
    yield* _provider.sendMessageStream(prompt, attachments: newAttachments);
  }
}
