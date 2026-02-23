import 'dart:io';

import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_core/firebase_core.dart';

/// Simple command-line example of Firebase AI provider usage.
///
/// This example shows basic text generation without the Flutter UI.
/// Run with: dart run example/bin/simple_chat.dart
void main() async {
  await Firebase.initializeApp();

  final provider = FirebaseAIProvider();
  final chatModel = provider.createChatModel(
    name: 'gemini-2.5-flash-lite',
    temperature: 0.7,
  );

  final messages = <ChatMessage>[];

  while (true) {
    stdout.write('\nYou: ');
    final input = stdin.readLineSync();

    if (input == null || input.toLowerCase() == 'quit') {
      break;
    }

    if (input.trim().isEmpty) {
      continue;
    }

    messages.add(ChatMessage.user(input));

    stdout.write('AI: ');

    ChatResult<ChatMessage>? finalResult;
    await for (final chunk in chatModel.sendStream(messages)) {
      stdout.write(chunk.output.text);
      finalResult = chunk;
    }
    stdout.writeln();

    if (finalResult != null) {
      messages.addAll(finalResult.messages);
    }
  }

  chatModel.dispose();
}
