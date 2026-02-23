// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EchoProvider', () {
    group('Initialization', () {
      test('creates with empty history by default', () {
        final provider = EchoProvider();
        expect(provider.history, isEmpty);
      });

      test('creates with provided history', () {
        final history = [
          ChatMessage.user('Hello'),
          ChatMessage.model('Hi there!'),
        ];
        final provider = EchoProvider(history: history);

        expect(provider.history.length, equals(2));
        expect(provider.history.first.text, equals('Hello'));
        expect(provider.history.last.text, equals('Hi there!'));
      });
    });

    group('History Management', () {
      test('history setter replaces all messages', () {
        final provider = EchoProvider(
          history: [ChatMessage.user('Old message')],
        );

        provider.history = [
          ChatMessage.user('New message 1'),
          ChatMessage.model('New response 1'),
        ];

        expect(provider.history.length, equals(2));
        expect(provider.history.first.text, equals('New message 1'));
      });

      test('history setter clears when set to empty', () {
        final provider = EchoProvider(
          history: [ChatMessage.user('Message'), ChatMessage.model('Response')],
        );

        provider.history = [];
        expect(provider.history, isEmpty);
      });

      test('notifies listeners when history changes', () {
        final provider = EchoProvider();
        var notificationCount = 0;
        provider.addListener(() => notificationCount++);

        provider.history = [ChatMessage.user('Test')];

        expect(notificationCount, equals(1));
      });
    });

    group('sendMessageStream', () {
      test('adds user message to history immediately', () async {
        final provider = EchoProvider();

        // Start the stream but don't consume it fully yet
        final stream = provider.sendMessageStream('Hello');

        // Consume at least one chunk to ensure the method has started
        await stream.first;

        // User message should be in history
        expect(provider.history.length, greaterThanOrEqualTo(1));
        expect(provider.history.first.role, equals(ChatMessageRole.user));
        expect(provider.history.first.text, equals('Hello'));
      });

      test('adds model response to history after completion', () async {
        final provider = EchoProvider();

        final chunks = await provider.sendMessageStream('Hello').toList();

        expect(provider.history.length, equals(2));
        expect(provider.history.last.role, equals(ChatMessageRole.model));

        // Response should contain the echoed content
        final fullResponse = chunks.join();
        expect(provider.history.last.text, equals(fullResponse));
      });

      test('streams response in chunks', () async {
        final provider = EchoProvider();

        final chunks = await provider.sendMessageStream('Test').toList();

        // EchoProvider yields at least 2 chunks (header, then content)
        expect(chunks.length, greaterThanOrEqualTo(2));
        expect(chunks.first, contains('Echo'));
      });

      test('echoes the prompt in response', () async {
        final provider = EchoProvider();

        final response = await provider
            .sendMessageStream('My test message')
            .join();

        expect(response, contains('My test message'));
      });

      test('includes attachment info in response', () async {
        final provider = EchoProvider();
        final attachment = DataPart(
          Uint8List.fromList([1, 2, 3]),
          mimeType: 'application/octet-stream',
          name: 'test.bin',
        );

        final response = await provider
            .sendMessageStream('Test', attachments: [attachment])
            .join();

        expect(response, contains('Attachments'));
      });

      test('notifies listeners after response completes', () async {
        final provider = EchoProvider();
        var notificationCount = 0;
        provider.addListener(() => notificationCount++);

        await provider.sendMessageStream('Hello').toList();

        expect(notificationCount, equals(1));
      });
    });

    group('Error Handling', () {
      test('throws LlmCancelException when prompt is CANCEL', () async {
        final provider = EchoProvider();

        expect(
          () async => await provider.sendMessageStream('CANCEL').toList(),
          throwsA(isA<LlmCancelException>()),
        );
      });

      test('throws LlmFailureException when prompt is FAIL', () async {
        final provider = EchoProvider();

        expect(
          () async => await provider.sendMessageStream('FAIL').toList(),
          throwsA(isA<LlmFailureException>()),
        );
      });

      test('throws immediately when prompt is FAILFAST', () async {
        final provider = EchoProvider();

        expect(
          () async => await provider.sendMessageStream('FAILFAST').toList(),
          throwsA(isA<LlmFailureException>()),
        );
      });
    });

    group('transcribeAudio', () {
      test('returns transcription message', () async {
        final provider = EchoProvider();
        // XFile.fromData doesn't preserve name on all platforms, so just test the format
        final audioFile = XFile.fromData(
          Uint8List.fromList([0, 1, 2, 3]),
          mimeType: 'audio/wav',
        );

        final result = await provider.transcribeAudio(audioFile).join();

        // Verify it returns the expected format
        expect(result, contains('Transcribed audio from:'));
      });
    });
  });
}
