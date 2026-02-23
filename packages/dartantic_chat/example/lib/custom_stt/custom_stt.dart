// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cross_file/cross_file.dart';
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
  static const title = 'Example: Custom Speech to Text';

  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: title, home: ChatPage());
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: AgentChatView(
      provider: CustomSttProvider(
        chatAgent: Agent('gemini'),
        // Use a different model for higher quality transcription
        sttAgent: Agent('gemini'),
      ),
    ),
  );
}

/// A custom provider that uses a separate agent for speech-to-text transcription.
///
/// This allows using a different (potentially higher quality) model for
/// transcription while using a faster model for chat responses.
class CustomSttProvider extends DartanticProvider {
  CustomSttProvider({required Agent chatAgent, required Agent sttAgent})
    : _sttAgent = sttAgent,
      super(agent: chatAgent);

  final Agent _sttAgent;

  @override
  Stream<String> transcribeAudio(XFile audioFile) async* {
    const prompt =
        'translate the attached audio to text. provide the result of the '
        'translation as just the raw text with no time or sound markers.';

    final attachment = await DataPart.fromFile(audioFile);

    await for (final result in _sttAgent.sendStream(
      prompt,
      attachments: [attachment],
    )) {
      if (result.output.isNotEmpty) {
        yield result.output;
      }
    }
  }
}
