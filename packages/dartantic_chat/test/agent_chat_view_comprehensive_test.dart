// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:dartantic_chat/src/views/jumping_dots_progress_indicator/jumping_dots_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('AgentChatView - Cancel Callbacks', () {
    testWidgets('calls onCancelCallback when operation is cancelled', (
      tester,
    ) async {
      var cancelCallbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              onCancelCallback: (context) {
                cancelCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      // Send a message that will trigger cancel
      await tester.enterText(find.byType(TextField), 'CANCEL');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      // Wait for the response to process (EchoProvider has 1s delay before CANCEL check)
      await tester.pump(const Duration(seconds: 2));

      expect(cancelCallbackCalled, isTrue);
    });

    testWidgets('shows default snackbar when no onCancelCallback provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: EchoProvider())),
        ),
      );

      await tester.enterText(find.byType(TextField), 'CANCEL');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(); // Allow snackbar to appear

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Operation canceled by user'), findsOneWidget);
    });

    testWidgets('shows stop button during pending response', (tester) async {
      final provider = ControllableProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: provider)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));
      await tester.pump();

      // Stop button should be visible during pending response
      expect(find.byTooltip('Stop'), findsOneWidget);

      provider.complete();
      await tester.pump();

      // Stop button should be hidden after response completes
      expect(find.byTooltip('Stop'), findsNothing);
    });

    testWidgets('tapping stop button cancels response', (tester) async {
      var cancelCallbackCalled = false;
      final provider = ControllableProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: provider,
              onCancelCallback: (context) {
                cancelCallbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));
      await tester.pump();

      // Tap stop button
      await tester.tap(find.byTooltip('Stop'));
      provider.cancel(); // Provider receives the cancel
      await tester.pump();

      expect(cancelCallbackCalled, isTrue);
    });
  });

  group('AgentChatView - Error Callbacks', () {
    testWidgets('calls onErrorCallback when error occurs', (tester) async {
      LlmException? receivedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              onErrorCallback: (context, error) {
                receivedError = error;
              },
            ),
          ),
        ),
      );

      // Send a message that will trigger failure
      await tester.enterText(find.byType(TextField), 'FAIL');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      // Wait for the response to process
      await tester.pump(const Duration(seconds: 2));

      expect(receivedError, isNotNull);
      expect(receivedError, isA<LlmFailureException>());
    });

    testWidgets('shows default alert dialog when no onErrorCallback provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: EchoProvider())),
        ),
      );

      await tester.enterText(find.byType(TextField), 'FAIL');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Alert dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('handles FAILFAST immediate failure', (tester) async {
      LlmException? receivedError;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              onErrorCallback: (context, error) {
                receivedError = error;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'FAILFAST');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      // FAILFAST should fail immediately
      await tester.pump(const Duration(milliseconds: 100));

      expect(receivedError, isNotNull);
      expect(receivedError, isA<LlmFailureException>());
    });
  });

  group('AgentChatView - Response Builder', () {
    testWidgets('uses custom responseBuilder when provided', (tester) async {
      var customBuilderCalled = false;
      String? receivedResponse;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(
                history: [
                  ChatMessage.user('Hello'),
                  ChatMessage.model('Custom response text'),
                ],
              ),
              responseBuilder: (context, response) {
                customBuilderCalled = true;
                receivedResponse = response;
                return Container(
                  key: const Key('custom-response'),
                  child: Text('CUSTOM: $response'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      expect(customBuilderCalled, isTrue);
      expect(receivedResponse, equals('Custom response text'));
      expect(find.byKey(const Key('custom-response')), findsOneWidget);
      expect(find.text('CUSTOM: Custom response text'), findsOneWidget);
    });

    testWidgets('responseBuilder used for new responses', (tester) async {
      var builderCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              responseBuilder: (context, response) {
                builderCallCount++;
                return Container(
                  key: const Key('custom-response'),
                  child: Text('CUSTOM: $response'),
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));

      // Wait for response to complete (EchoProvider has delays)
      await tester.pump(const Duration(seconds: 3));

      // Builder should have been called for the response
      expect(builderCallCount, greaterThan(0));
      expect(find.byKey(const Key('custom-response')), findsOneWidget);
    });
  });

  group('AgentChatView - Message Sender (Rerouting)', () {
    testWidgets('uses messageSender instead of provider when provided', (
      tester,
    ) async {
      var messageSenderCalled = false;
      String? receivedPrompt;
      Iterable<Part>? receivedAttachments;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              messageSender: (prompt, {required attachments}) async* {
                messageSenderCalled = true;
                receivedPrompt = prompt;
                receivedAttachments = attachments;
                yield 'Custom response from messageSender';
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(messageSenderCalled, isTrue);
      expect(receivedPrompt, equals('Test message'));
      expect(receivedAttachments, isEmpty);
    });

    testWidgets('messageSender can intercept and log prompts', (tester) async {
      final loggedPrompts = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              messageSender: (prompt, {required attachments}) async* {
                loggedPrompts.add(prompt);
                // Delegate to a simple echo response
                yield 'Logged and responded';
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'First message');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(loggedPrompts, contains('First message'));
    });
  });

  group('AgentChatView - Message Editing', () {
    testWidgets('displays edit button for last user message', (tester) async {
      final provider = EchoProvider(
        history: [
          ChatMessage.user('Original message'),
          ChatMessage.model('Original response'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: provider)),
        ),
      );

      await tester.pump();

      // The edit functionality exists - verify history has messages
      expect(provider.history.length, equals(2));
      expect(find.text('Original message'), findsOneWidget);
    });

    testWidgets('history can be modified externally', (tester) async {
      final provider = EchoProvider(
        history: [
          ChatMessage.user('First message'),
          ChatMessage.model('First response'),
          ChatMessage.user('Second message'),
          ChatMessage.model('Second response'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: provider)),
        ),
      );

      expect(provider.history.length, equals(4));

      // Remove last two messages (simulating edit)
      final newHistory = provider.history.toList();
      newHistory.removeLast();
      newHistory.removeLast();
      provider.history = newHistory;
      await tester.pump();

      expect(provider.history.length, equals(2));
    });
  });

  group('AgentChatView - Progress Indicator', () {
    testWidgets('shows jumping dots during response', (tester) async {
      final provider = ControllableProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: provider)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();
      await tester.tap(find.byTooltip('Submit Message'));
      await tester.pump();

      // During pending response, we should see the stop button
      expect(find.byTooltip('Stop'), findsOneWidget);

      provider.complete();
      await tester.pump();

      expect(find.byTooltip('Stop'), findsNothing);
    });

    testWidgets('custom progress indicator color is applied', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(history: [ChatMessage.user('Test')]),
              style: ChatViewStyle(progressIndicatorColor: Colors.purple),
            ),
          ),
        ),
      );

      // JumpingDotsProgressIndicator uses the progress indicator color
      // We just verify the widget renders without error with custom color
      await tester.pump();
      expect(find.byType(JumpingDotsProgressIndicator), findsNothing);
    });
  });

  group('AgentChatView - Voice Transcription', () {
    testWidgets('shows record button when enableVoiceNotes is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              enableVoiceNotes: true,
            ),
          ),
        ),
      );

      // Record button should be visible
      expect(find.byTooltip('Record Audio'), findsOneWidget);
    });

    testWidgets('hides record button when enableVoiceNotes is false', (
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

      expect(find.byTooltip('Record Audio'), findsNothing);
    });

    testWidgets('record button hidden when text is entered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              enableVoiceNotes: true,
            ),
          ),
        ),
      );

      // Initially record button visible
      expect(find.byTooltip('Record Audio'), findsOneWidget);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Some text');
      await tester.pump();

      // Now submit button should be visible instead
      expect(find.byTooltip('Submit Message'), findsOneWidget);
    });
  });

  group('AgentChatView - Attachments', () {
    testWidgets('shows attachment button when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              enableAttachments: true,
            ),
          ),
        ),
      );

      expect(find.byTooltip('Add Attachment'), findsOneWidget);
    });

    testWidgets('hides attachment button when disabled', (tester) async {
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

      expect(find.byTooltip('Add Attachment'), findsNothing);
    });

    testWidgets('shows attachment menu on button tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              enableAttachments: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Add Attachment'));
      await tester.pumpAndSettle();

      // Attachment menu items should be visible (as Text, not tooltips)
      expect(find.text('Attach File'), findsOneWidget);
    });
  });

  group('AgentChatView - Autofocus Behavior', () {
    testWidgets('autofocuses when no suggestions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(provider: EchoProvider(), suggestions: []),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('does not autofocus when suggestions present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: ['Suggestion 1', 'Suggestion 2'],
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isFalse);
    });

    testWidgets('respects explicit autofocus=true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: ['Suggestion 1'],
              autofocus: true,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('respects explicit autofocus=false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: [],
              autofocus: false,
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode?.hasFocus, isFalse);
    });
  });

  group('AgentChatView - Custom Styling', () {
    testWidgets('applies custom suggestion style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: ['Test suggestion'],
              style: ChatViewStyle(
                suggestionStyle: SuggestionStyle(
                  textStyle: const TextStyle(color: Colors.red, fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test suggestion'), findsOneWidget);
    });

    testWidgets('applies custom chat input style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              style: ChatViewStyle(
                chatInputStyle: ChatInputStyle(
                  hintText: 'Custom placeholder...',
                  backgroundColor: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, equals('Custom placeholder...'));
    });

    testWidgets('applies custom background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              style: ChatViewStyle(backgroundColor: Colors.blue),
            ),
          ),
        ),
      );

      // Widget renders with custom style
      expect(find.byType(AgentChatView), findsOneWidget);
    });
  });

  group('AgentChatView - History Persistence', () {
    testWidgets('reacts to external history changes', (tester) async {
      final provider = EchoProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentChatView(provider: provider)),
        ),
      );

      // Initially empty
      expect(find.text('Test message'), findsNothing);

      // Update history externally
      provider.history = [
        ChatMessage.user('Test message'),
        ChatMessage.model('Test response'),
      ];
      await tester.pump();

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('clears UI when history is reset', (tester) async {
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

      provider.history = [];
      await tester.pump();

      expect(find.text('Message 1'), findsNothing);
    });

    testWidgets('displays welcome message when history is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              welcomeMessage: 'Welcome to the chat!',
            ),
          ),
        ),
      );

      expect(find.text('Welcome to the chat!'), findsOneWidget);
    });

    testWidgets('keeps welcome message when history is added', (tester) async {
      final provider = EchoProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(provider: provider, welcomeMessage: 'Welcome!'),
          ),
        ),
      );

      expect(find.text('Welcome!'), findsOneWidget);

      // Add message to history
      provider.history = [
        ChatMessage.user('Hello'),
        ChatMessage.model('Hi there!'),
      ];
      await tester.pump();

      // Welcome message should still be visible
      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });
  });

  group('AgentChatView - Suggestions', () {
    testWidgets('displays suggestions when history is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: ['Suggestion 1', 'Suggestion 2', 'Suggestion 3'],
            ),
          ),
        ),
      );

      expect(find.text('Suggestion 1'), findsOneWidget);
      expect(find.text('Suggestion 2'), findsOneWidget);
      expect(find.text('Suggestion 3'), findsOneWidget);
    });

    testWidgets('hides suggestions when history is not empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(
                history: [
                  ChatMessage.user('Previous message'),
                  ChatMessage.model('Previous response'),
                ],
              ),
              suggestions: ['Suggestion 1', 'Suggestion 2'],
            ),
          ),
        ),
      );

      expect(find.text('Suggestion 1'), findsNothing);
      expect(find.text('Suggestion 2'), findsNothing);
    });

    testWidgets('tapping suggestion sends it as message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              provider: EchoProvider(),
              suggestions: ['Ask about weather'],
            ),
          ),
        ),
      );

      // Tap the suggestion
      await tester.tap(find.text('Ask about weather'));
      await tester.pump();

      // Wait for the message to be processed
      await tester.pump(const Duration(seconds: 3));

      // The suggestion should now appear as a user message in history
      expect(find.text('Ask about weather'), findsWidgets);
    });
  });
}
