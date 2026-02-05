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
}
