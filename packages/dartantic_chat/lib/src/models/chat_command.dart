// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/styles/styles.dart';
import 'package:flutter/widgets.dart';

/// A command that can be triggered from the chat input.
@immutable
class ChatCommand {
  /// Creates a [ChatCommand].
  const ChatCommand({
    required this.name,
    required this.icon,
    required this.onPressed,
    this.style,
  });

  /// The name of the command, displayed in the menu.
  final String name;

  /// The icon to display next to the command name.
  final IconData icon;

  /// The callback to execute when the command is selected.
  final VoidCallback onPressed;

  /// Optional style for the command button.
  final ActionButtonStyle? style;
}
