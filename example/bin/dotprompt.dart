// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dotprompt_dart/dotprompt_dart.dart';

void main() async {
  await dotPromptExample();
}

Future<void> dotPromptExample() async {
  print('dotPromptExample');

  final prompt = DotPrompt('''
---
model: openai
input:
  default:
    length: 3
    text: "The quick brown fox jumps over the lazy dog."
---
Summarize this in {{length}} words: {{text}}
''');

  await Agent.runPromptStream(
    prompt,
  ).map((event) => stdout.write(event.output)).drain();
  print('');
}
