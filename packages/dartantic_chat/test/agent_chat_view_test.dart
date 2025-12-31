// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentChatView', () {
    group('Initial State', () {
      testWidgets('renders empty chat view with input field', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: EchoProvider())),
          ),
        );
        await tester.pump();

        // Input field should be present
        expect(find.byType(TextField), findsOneWidget);
        // When input is empty, record button is shown (not submit)
        expect(find.byTooltip('Record Audio'), findsOneWidget);
      });

      testWidgets('displays welcome message when provided', (tester) async {
        const welcomeMessage = 'Hello! How can I help you today?';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                welcomeMessage: welcomeMessage,
              ),
            ),
          ),
        );

        expect(find.text(welcomeMessage), findsOneWidget);
      });

      testWidgets('displays suggestions when provided', (tester) async {
        final suggestions = ['Tell me a joke', 'What is Flutter?'];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                suggestions: suggestions,
              ),
            ),
          ),
        );

        for (final suggestion in suggestions) {
          expect(find.text(suggestion), findsOneWidget);
        }
      });

      testWidgets('renders with existing history', (tester) async {
        final provider = EchoProvider(
          history: [
            ChatMessage.user('Hello'),
            ChatMessage.model('Hi there! How can I help you?'),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: provider)),
          ),
        );

        expect(find.text('Hello'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is MarkdownBody && w.data == 'Hi there! How can I help you?',
          ),
          findsOneWidget,
        );
      });
    });

    group('Message Sending', () {
      testWidgets('sends message and displays response', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: EchoProvider())),
          ),
        );

        // Enter text and submit
        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.pump();

        await tester.tap(find.byTooltip('Submit Message'));

        // Wait for streaming response (EchoProvider has 1s delay)
        await tester.pump(const Duration(seconds: 2));

        // User message should appear (may appear in multiple places due to echo)
        expect(find.text('Test message'), findsWidgets);

        // Response should contain the echoed message in markdown
        expect(
          find.byWidgetPredicate(
            (w) => w is MarkdownBody && w.data.contains('Test message'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('clears input field after sending', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: EchoProvider())),
          ),
        );

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        await tester.tap(find.byTooltip('Submit Message'));
        // Pump long enough for EchoProvider's internal timer (1 second)
        await tester.pump(const Duration(seconds: 2));

        // Text field should be cleared
        expect(
          (tester.widget<TextField>(textField).controller?.text ?? ''),
          isEmpty,
        );
      });

      testWidgets('clicking suggestion sends message', (tester) async {
        final suggestions = ['Tell me a joke'];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                suggestions: suggestions,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tell me a joke'));
        // Pump long enough for EchoProvider's internal timer (1 second)
        await tester.pump(const Duration(seconds: 2));

        // User message should appear (may also be in echo response)
        expect(find.text('Tell me a joke'), findsWidgets);
      });
    });

    group('Provider Integration', () {
      testWidgets('updates when provider history changes', (tester) async {
        final provider = EchoProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: provider)),
          ),
        );

        // Initially empty
        expect(find.text('External message'), findsNothing);

        // Update history externally
        provider.history = [
          ChatMessage.user('External message'),
          ChatMessage.model('External response'),
        ];

        await tester.pump();

        expect(find.text('External message'), findsOneWidget);
      });

      testWidgets('clears UI when history is cleared', (tester) async {
        final provider = EchoProvider(
          history: [
            ChatMessage.user('Message 1'),
            ChatMessage.model('Response 1'),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentChatView(provider: provider)),
          ),
        );

        expect(find.text('Message 1'), findsOneWidget);

        // Clear history
        provider.history = [];
        await tester.pump();

        expect(find.text('Message 1'), findsNothing);
      });
    });

    group('Restricted Mode', () {
      testWidgets('hides attachment button when attachments disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                enableAttachments: false,
              ),
            ),
          ),
        );

        // Attachment button should not be visible
        expect(find.byTooltip('Add Attachment'), findsNothing);
      });

      testWidgets('hides voice button when voice notes disabled', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                enableVoiceNotes: false,
              ),
            ),
          ),
        );

        // Voice recording button should not be visible
        expect(find.byTooltip('Record Audio'), findsNothing);
      });
    });

    group('Custom Styling', () {
      testWidgets('applies custom background color', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                style: ChatViewStyle(backgroundColor: Colors.red),
              ),
            ),
          ),
        );

        // Find a Container with the specified color
        expect(
          find.byWidgetPredicate(
            (w) => w is Container && w.color == Colors.red,
          ),
          findsWidgets,
        );
      });
    });
  });
}
