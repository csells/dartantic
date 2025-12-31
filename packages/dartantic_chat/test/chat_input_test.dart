// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:dartantic_chat/src/views/chat_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Input', () {
    Widget buildTestApp({
      EchoProvider? provider,
      bool enableAttachments = true,
      bool enableVoiceNotes = true,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AgentChatView(
            provider: provider ?? EchoProvider(),
            enableAttachments: enableAttachments,
            enableVoiceNotes: enableVoiceNotes,
          ),
        ),
      );
    }

    group('Text Input', () {
      testWidgets('accepts text input', (tester) async {
        await tester.pumpWidget(buildTestApp());

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Hello world');
        await tester.pump();

        expect(
          tester.widget<TextField>(textField).controller?.text,
          equals('Hello world'),
        );
      });

      testWidgets('supports multiline input', (tester) async {
        await tester.pumpWidget(buildTestApp());

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Line 1\nLine 2\nLine 3');
        await tester.pump();

        expect(
          tester.widget<TextField>(textField).controller?.text,
          contains('\n'),
        );
      });
    });

    group('Submit Behavior', () {
      testWidgets('submits on button tap', (tester) async {
        await tester.pumpWidget(buildTestApp());

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        await tester.tap(find.byTooltip('Submit Message'));
        // Pump long enough for EchoProvider's internal timer (1 second)
        await tester.pump(const Duration(seconds: 2));

        // Message should appear in chat - may find in both user message and echo response
        expect(find.text('Test message'), findsWidgets);
      });

      testWidgets('clears text field after submit', (tester) async {
        await tester.pumpWidget(buildTestApp());

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        await tester.tap(find.byTooltip('Submit Message'));
        // Pump long enough for EchoProvider's internal timer (1 second)
        await tester.pump(const Duration(seconds: 2));

        expect(tester.widget<TextField>(textField).controller?.text, isEmpty);
      });
    });

    group('Attachment Button', () {
      testWidgets('shows attachment button by default', (tester) async {
        await tester.pumpWidget(buildTestApp());

        expect(find.byTooltip('Add Attachment'), findsOneWidget);
      });

      testWidgets('hides attachment button when disabled', (tester) async {
        await tester.pumpWidget(buildTestApp(enableAttachments: false));

        expect(find.byTooltip('Add Attachment'), findsNothing);
      });
    });

    group('Voice Button', () {
      testWidgets('shows voice button by default', (tester) async {
        await tester.pumpWidget(buildTestApp());

        // Voice button should be present
        expect(find.byTooltip('Record Audio'), findsOneWidget);
      });

      testWidgets('hides voice button when disabled', (tester) async {
        await tester.pumpWidget(buildTestApp(enableVoiceNotes: false));

        expect(find.byTooltip('Record Audio'), findsNothing);
      });
    });

    group('Input Focus', () {
      testWidgets('ChatTextField has correct autofocus value', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(provider: EchoProvider(), autofocus: true),
            ),
          ),
        );

        final chatTextField = find.byType(ChatTextField);
        expect(tester.widget<ChatTextField>(chatTextField).autofocus, isTrue);
      });

      testWidgets('TextField gets focus when autofocus is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(provider: EchoProvider(), autofocus: true),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.focusNode?.hasFocus, isTrue);
      });
    });

    group('Hint Text', () {
      testWidgets('shows default hint text', (tester) async {
        await tester.pumpWidget(buildTestApp());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, isNotNull);
      });

      testWidgets('applies custom hint text from style', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                style: ChatViewStyle(
                  chatInputStyle: ChatInputStyle(hintText: 'Custom hint'),
                ),
              ),
            ),
          ),
        );

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.decoration?.hintText, equals('Custom hint'));
      });
    });
  });
}
