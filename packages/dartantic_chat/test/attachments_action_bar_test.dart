// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/chat_view_model/chat_view_model_provider.dart';
import 'package:dartantic_chat/src/providers/providers.dart';
import 'package:dartantic_chat/src/views/chat_input/attachments_action_bar.dart';
import 'package:dartantic_chat/src/views/chat_input/chat_input_constants.dart';
import 'package:dartantic_chat/src/views/chat_input/command_menu_controller.dart';
import 'package:dartantic_chat/src/chat_view_model/chat_view_model.dart';
import 'package:dartantic_chat/src/views/action_button.dart';
import 'package:dartantic_chat/src/styles/chat_view_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttachmentActionBar', () {
    late ChatViewModel viewModel;

    setUp(() {
      viewModel = ChatViewModel(
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
    });

    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: ChatViewModelProvider(viewModel: viewModel, child: child),
        ),
      );
    }

    testWidgets('uses menuOffset correctly in menu placement', (tester) async {
      const providedOffset = Offset(10, 20);

      await tester.pumpWidget(
        wrap(
          AttachmentActionBar(
            onAttachments: (_) {},
            menuOffset: providedOffset,
          ),
        ),
      );

      // Open menu to count items
      await tester.tap(find.byType(ActionButton));
      await tester.pump();

      // On non-mobile (test environment), menuOffset is passed through as-is
      final menuAnchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      expect(menuAnchor.alignmentOffset, equals(providedOffset));
    });

    testWidgets('controller toggles the menu open and closed', (tester) async {
      final controller = CommandMenuController();
      await tester.pumpWidget(
        wrap(
          AttachmentActionBar(
            onAttachments: (_) {},
            commandMenuController: controller,
          ),
        ),
      );

      // Menu should be closed initially
      expect(find.byType(MenuItemButton), findsNothing);

      // Open menu via controller
      controller.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MenuItemButton), findsWidgets);

      // Close menu via controller
      controller.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MenuItemButton), findsNothing);

      controller.dispose();
    });

    testWidgets(
      'returns negative vertical offset on mobile when no offset provided',
      (tester) async {
        await tester.pumpWidget(
          wrap(AttachmentActionBar(onAttachments: (_) {})),
        );

        // Simulate mobile via the testIsMobile setter (triggers setState)
        final state = tester.state<State<AttachmentActionBar>>(
          find.byType(AttachmentActionBar),
        );
        // ignore: avoid_dynamic_calls
        (state as dynamic).testIsMobile = true;
        await tester.pump();

        // Open menu to count items
        await tester.tap(find.byType(ActionButton));
        await tester.pump();

        // Dynamically count items
        final menuItemsCount = find.byType(MenuItemButton).evaluate().length;

        const itemHeight = ChatInputConstants.menuItemHeight;
        const menuPadding = ChatInputConstants.menuPadding;
        final estimatedHeight = (menuItemsCount * itemHeight) + menuPadding;

        final menuAnchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
        expect(menuAnchor.alignmentOffset, equals(Offset(0, -estimatedHeight)));
      },
    );
  });
}
