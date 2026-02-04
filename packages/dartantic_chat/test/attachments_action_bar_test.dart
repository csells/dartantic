// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/chat_view_model/chat_view_model_provider.dart';
import 'package:dartantic_chat/src/providers/providers.dart';
import 'package:dartantic_chat/src/views/chat_input/attachments_action_bar.dart';
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

    testWidgets('uses widget.offset correctly in menu placement', (
      tester,
    ) async {
      const providedOffset = Offset(10, 20);

      await tester.pumpWidget(
        wrap(
          AttachmentActionBar(onAttachments: (_) {}, offset: providedOffset),
        ),
      );

      // Open menu to count items
      await tester.tap(find.byType(ActionButton));
      await tester.pump();

      // Dynamically count items
      final menuItemsCount = find.byType(MenuItemButton).evaluate().length;

      const itemHeight = 56.0;
      const menuPadding = 16.0;
      final estimatedHeight = (menuItemsCount * itemHeight) + menuPadding;

      final menuAnchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
      expect(
        menuAnchor.alignmentOffset,
        equals(Offset(10, 20 - estimatedHeight)),
      );
    });

    testWidgets('setMenuVisible toggles the menu with an attached GlobalKey', (
      tester,
    ) async {
      final key = GlobalKey<AttachmentActionBarState>();
      await tester.pumpWidget(
        wrap(AttachmentActionBar(key: key, onAttachments: (_) {})),
      );

      // Menu should be closed initially
      expect(find.byType(MenuItemButton), findsNothing);

      // Open menu
      AttachmentActionBar actionBar = tester.widget(
        find.byType(AttachmentActionBar),
      );
      actionBar.setMenuVisible(true);
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Minimal pump for visibility

      expect(find.byType(MenuItemButton), findsWidgets);

      // Close menu
      actionBar.setMenuVisible(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MenuItemButton), findsNothing);
    });

    testWidgets(
      'returns negative vertical offset on mobile when no offset provided',
      (tester) async {
        await tester.pumpWidget(
          wrap(AttachmentActionBar(onAttachments: (_) {})),
        );

        // Simulate mobile
        final state = tester.state<AttachmentActionBarState>(
          find.byType(AttachmentActionBar),
        );
        state.testIsMobile = true;
        // ignore: invalid_use_of_protected_member
        tester.element(find.byType(AttachmentActionBar)).markNeedsBuild();
        await tester.pump();

        // Open menu to count items
        await tester.tap(find.byType(ActionButton));
        await tester.pump();

        // Dynamically count items
        final menuItemsCount = find.byType(MenuItemButton).evaluate().length;

        const itemHeight = 56.0;
        const menuPadding = 16.0;
        final estimatedHeight = (menuItemsCount * itemHeight) + menuPadding;

        final menuAnchor = tester.widget<MenuAnchor>(find.byType(MenuAnchor));
        expect(menuAnchor.alignmentOffset, equals(Offset(0, -estimatedHeight)));
      },
    );
  });
}
