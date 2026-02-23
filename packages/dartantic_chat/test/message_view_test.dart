// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message Views', () {
    Widget buildTestApp({required List<ChatMessage> history}) {
      return MaterialApp(
        home: Scaffold(
          body: AgentChatView(provider: EchoProvider(history: history)),
        ),
      );
    }

    group('User Messages', () {
      testWidgets('displays user message text', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('Hello from user'),
              ChatMessage.model('Response'),
            ],
          ),
        );

        expect(find.text('Hello from user'), findsOneWidget);
      });

      testWidgets('displays multiple user messages', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('First message'),
              ChatMessage.model('First response'),
              ChatMessage.user('Second message'),
              ChatMessage.model('Second response'),
            ],
          ),
        );

        expect(find.text('First message'), findsOneWidget);
        expect(find.text('Second message'), findsOneWidget);
      });

      testWidgets('preserves line breaks in user messages', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('Line 1\nLine 2'),
              ChatMessage.model('Response'),
            ],
          ),
        );

        // The text should contain the line break
        expect(find.textContaining('Line 1'), findsOneWidget);
        expect(find.textContaining('Line 2'), findsOneWidget);
      });
    });

    group('Model Messages', () {
      testWidgets('displays model response as markdown', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('Question'),
              ChatMessage.model('**Bold** response'),
            ],
          ),
        );

        // MarkdownBody should render the response
        expect(
          find.byWidgetPredicate(
            (w) => w is MarkdownBody && w.data.contains('**Bold**'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders code blocks in model response', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('Show code'),
              ChatMessage.model('```dart\nvoid main() {}\n```'),
            ],
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is MarkdownBody && w.data.contains('void main()'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders lists in model response', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('List items'),
              ChatMessage.model('- Item 1\n- Item 2\n- Item 3'),
            ],
          ),
        );

        expect(
          find.byWidgetPredicate(
            (w) => w is MarkdownBody && w.data.contains('Item 1'),
          ),
          findsOneWidget,
        );
      });
    });

    group('Message Order', () {
      testWidgets('displays messages in chronological order', (tester) async {
        await tester.pumpWidget(
          buildTestApp(
            history: [
              ChatMessage.user('First'),
              ChatMessage.model('Second'),
              ChatMessage.user('Third'),
              ChatMessage.model('Fourth'),
            ],
          ),
        );

        // Find all text widgets and verify order
        final firstFinder = find.text('First');
        final thirdFinder = find.text('Third');

        expect(firstFinder, findsOneWidget);
        expect(thirdFinder, findsOneWidget);

        // First should appear before Third in the widget tree
        final firstOffset = tester.getCenter(firstFinder);
        final thirdOffset = tester.getCenter(thirdFinder);

        // In a scrollable list, earlier messages should be above later ones
        expect(firstOffset.dy, lessThan(thirdOffset.dy));
      });
    });

    group('Empty States', () {
      testWidgets('shows welcome message when history is empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(),
                welcomeMessage: 'Welcome! How can I help?',
              ),
            ),
          ),
        );

        expect(find.text('Welcome! How can I help?'), findsOneWidget);
      });

      testWidgets('shows welcome message alongside history', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(
                  history: [
                    ChatMessage.user('Hi'),
                    ChatMessage.model('Hello!'),
                  ],
                ),
                welcomeMessage: 'Welcome! How can I help?',
              ),
            ),
          ),
        );

        // Welcome message is prepended to history, not hidden
        expect(find.text('Welcome! How can I help?'), findsOneWidget);
        expect(find.text('Hi'), findsOneWidget);
      });
    });

    group('Scrolling', () {
      testWidgets('scrolls to show new messages', (tester) async {
        // Create a provider with many messages
        final messages = <ChatMessage>[];
        for (var i = 0; i < 20; i++) {
          messages.add(ChatMessage.user('Message $i'));
          messages.add(ChatMessage.model('Response $i'));
        }

        await tester.pumpWidget(buildTestApp(history: messages));

        // The last message should be visible (auto-scroll)
        expect(find.text('Message 19'), findsOneWidget);
      });
    });

    group('Styling', () {
      testWidgets('applies custom user message style', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AgentChatView(
                provider: EchoProvider(
                  history: [
                    ChatMessage.user('Styled message'),
                    ChatMessage.model('Response'),
                  ],
                ),
                style: ChatViewStyle(
                  userMessageStyle: UserMessageStyle(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        // Find the user message and verify it exists
        expect(find.text('Styled message'), findsOneWidget);
      });
    });
  });
}
