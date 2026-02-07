// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat_example/commands/commands.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChatPage renders core UI elements', (WidgetTester tester) async {
    // Build the ChatPage
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));

    // Verify the welcome message snippet appears
    expect(
      find.textContaining('Welcome to the Commands Example!'),
      findsOneWidget,
    );

    // Verify at least one suggestion appears
    expect(find.text('Tell me a joke'), findsOneWidget);

    expect(find.text('How do I use slash commands?'), findsOneWidget);
  });

  testWidgets('Typing / shows command menu with custom commands', (
    WidgetTester tester,
  ) async {
    // Build the ChatPage
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));

    // Find the text field
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Type '/' to open the command menu
    await tester.enterText(textFieldFinder, '/');
    await tester.pump();

    // Verify standard commands are present
    expect(find.text('Attach File'), findsOneWidget);
    expect(find.text('Attach Link'), findsOneWidget);

    // Verify custom command is present
    expect(find.text('Help'), findsOneWidget);
    expect(find.byIcon(Icons.help_outline), findsOneWidget);

    // Tap the custom command
    await tester.tap(find.text('Help'));
    await tester.pump();

    // Verify text is cleared
    expect(find.text('/'), findsNothing);
    final textField = tester.widget<TextField>(textFieldFinder);
    expect(textField.controller!.text, isEmpty);
  });
}
