// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:dartantic_chat/src/chat_view_model/chat_view_model.dart';
import 'package:dartantic_chat/src/chat_view_model/chat_view_model_provider.dart';
import 'package:dartantic_chat/src/views/chat_input/chat_input.dart';
import 'package:dartantic_chat/src/views/chat_text_field.dart';
import 'package:dartantic_chat/src/views/chat_input/attachments_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Input', () {
    Widget buildTestApp({
      EchoProvider? provider,
      bool enableAttachments = true,
      bool enableVoiceNotes = true,
    }) {
      final viewModel = ChatViewModel(
        provider: provider ?? EchoProvider(),
        style: const ChatViewStyle(),
        commands: const [],
        suggestions: const [],
        welcomeMessage: 'Welcome',
        responseBuilder: null,
        messageSender: null,
        enableAttachments: enableAttachments,
        enableVoiceNotes: enableVoiceNotes,
      );
      return MaterialApp(
        home: Scaffold(
          body: ChatViewModelProvider(
            viewModel: viewModel,
            child: AgentChatView(
              provider: provider ?? EchoProvider(),
              enableAttachments: enableAttachments,
              enableVoiceNotes: enableVoiceNotes,
            ),
          ),
        ),
      );
    }

    final viewModel = ChatViewModel(
      provider: EchoProvider(),
      style: const ChatViewStyle(),
      commands: const [],
      suggestions: const [],
      welcomeMessage: null,
      responseBuilder: null,
      messageSender: null,
      enableAttachments: true,
      enableVoiceNotes: true,
    );

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
    group('Command Menu Visibility', () {
      testWidgets('closes menu when / is not at start or after whitespace', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestApp());

        final textField = find.byType(TextField);

        // Type a word and then /
        await tester.enterText(textField, 'word/');
        await tester.pump();

        // Menu should not be open
        expect(find.byType(MenuItemButton), findsNothing);

        // Type / at start
        await tester.enterText(textField, '/');
        await tester.pump();

        // Menu should be open (need to wait for pump)
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(MenuItemButton), findsWidgets);

        // Type a char to make it "word/" again (invalid)
        await tester.enterText(textField, 'a/');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(MenuItemButton), findsNothing);
      });

      testWidgets('updates menu offset relative to caret position', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestApp());

        final textFieldFinder = find.byType(TextField);
        final controller = tester
            .widget<TextField>(textFieldFinder)
            .controller!;

        // Enter text with two potential '/' trigger points
        const text = '/ some long text /';
        await tester.enterText(textFieldFinder, text);

        // 1. Move caret after the first '/'
        controller.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); // Wait for menu

        expect(find.byType(MenuItemButton), findsWidgets);
        final menuAnchorFinder = find.byType(MenuAnchor);
        final offsetAtFirst = tester
            .widget<MenuAnchor>(menuAnchorFinder)
            .alignmentOffset;
        expect(offsetAtFirst, isNotNull);

        // 2. Move caret after the second '/'
        controller.selection = TextSelection.collapsed(offset: text.length);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final offsetAtSecond = tester
            .widget<MenuAnchor>(menuAnchorFinder)
            .alignmentOffset;
        expect(offsetAtSecond, isNotNull);

        // The second offset should be further to the right (greater dx)
        expect(offsetAtSecond!.dx, greaterThan(offsetAtFirst!.dx));
        expect(offsetAtSecond.dy, equals(offsetAtFirst.dy));
      });

      testWidgets('filters command menu as user types', (tester) async {
        await tester.pumpWidget(buildTestApp());

        final textField = find.byType(TextField);

        // 1. Initial slash
        await tester.enterText(textField, '/');
        await tester.pumpAndSettle();

        expect(find.text('Attach Image'), findsOneWidget);
        expect(find.text('Attach File'), findsOneWidget);
        expect(find.text('Attach Link'), findsOneWidget);

        // 2. Type 'g' - should narrow to 'Attach Image' (matches 'Gallery')
        await tester.enterText(textField, '/g');
        await tester.pumpAndSettle();

        expect(find.text('Attach Image'), findsOneWidget);
        expect(find.text('Attach File'), findsNothing);
        expect(find.text('Attach Link'), findsNothing);

        // 3. Type 'fi' - should narrow to 'Attach File' (matches 'File')
        await tester.enterText(textField, '/fi');
        await tester.pumpAndSettle();

        expect(find.text('Attach Image'), findsNothing);
        expect(find.text('Attach File'), findsOneWidget);
      });

      testWidgets(
        'navigates command menu with arrow keys and selects with Enter',
        (tester) async {
          await tester.pumpWidget(buildTestApp());

          final textFieldFinder = find.byType(TextField);
          await tester.tap(textFieldFinder);
          await tester.pump();

          // Start command - should show all items
          await tester.enterText(textFieldFinder, '/');
          await tester.pumpAndSettle();

          final attachmentState = tester.state<AttachmentActionBarState>(
            find.byType(AttachmentActionBar),
          );
          final initialIndex = attachmentState.activeIndex;
          expect(initialIndex, isNotNull);

          // Arrow Down to next item
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          expect(attachmentState.activeIndex, (initialIndex + 1));

          // Arrow Up back
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pump();
          expect(attachmentState.activeIndex, initialIndex);

          // Filter to URL manually by typing 'url'
          await tester.enterText(textFieldFinder, '/url');
          await tester.pumpAndSettle();

          expect(find.text('Attach Link'), findsOneWidget);

          // Enter to trigger URL dialog
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          // pumpAndSettle to wait for dialog animation
          await tester.pumpAndSettle();

          // Verify URL dialog appeared
          expect(find.text('Attach URL'), findsOneWidget);
        },
      );
    });

    group('Post-frame Callback Safety', () {
      testWidgets('post-frame callbacks do not crash when unmounted', (
        tester,
      ) async {
        // We use a StatefulWidget to control the lifecycle and trigger an update in ChatInput
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatViewModelProvider(
                viewModel: viewModel,
                child: ChatInput(
                  onSendMessage: (text, parts) {},
                  onTranslateStt: (file, parts) {},
                  attachments: const [],
                  onAttachments: (parts) {},
                  onRemoveAttachment: (part) {},
                  onClearAttachments: () {},
                  onReplaceAttachments: (parts) {},
                  initialMessage: null,
                ),
              ),
            ),
          ),
        );

        // Schedule an update that will trigger addPostFrameCallback inside didUpdateWidget
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatViewModelProvider(
                viewModel: viewModel,
                child: ChatInput(
                  onSendMessage: (text, parts) {},
                  onTranslateStt: (file, parts) {},
                  attachments: const [],
                  onAttachments: (parts) {},
                  onRemoveAttachment: (part) {},
                  onClearAttachments: () {},
                  onReplaceAttachments: (parts) {},
                  initialMessage: ChatMessage.user('New text', parts: []),
                ),
              ),
            ),
          ),
        );

        // Immediatley unmount the widget bridge by pumping a different widget
        await tester.pumpWidget(const SizedBox());

        // This will execute the post-frame callback scheduled in the previous pumpWidget.
        await tester.pump();
      });
    });
  });
}
