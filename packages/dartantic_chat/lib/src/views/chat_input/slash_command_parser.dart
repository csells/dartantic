// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

/// The result of parsing text for an active slash command.
@immutable
class SlashParseResult {
  /// Creates an inactive result (no slash command found).
  const SlashParseResult.none() : slashIndex = -1, filterText = '';

  /// Creates an active result with the given slash position and filter text.
  const SlashParseResult.active({
    required this.slashIndex,
    required this.filterText,
  });

  /// The index of the '/' character in the text, or -1 if inactive.
  final int slashIndex;

  /// The text typed after the '/' (used to filter commands).
  final String filterText;

  /// Whether an active slash command trigger was found.
  bool get isActive => slashIndex >= 0;
}

/// Parses text input to detect slash-command triggers and provides
/// utilities for clearing command text.
class SlashCommandParser {
  SlashCommandParser._();

  /// Parse [text] at [selection] to find an active slash command.
  ///
  /// A slash command is active when '/' appears at the start of input or
  /// after a whitespace character, and the text between the '/' and the
  /// cursor contains no whitespace.
  static SlashParseResult parse(String text, TextSelection selection) {
    if (!selection.isValid || selection.baseOffset == 0) {
      return const SlashParseResult.none();
    }

    final cursorPos = selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final lastSlashIndex = textBeforeCursor.lastIndexOf('/');

    if (lastSlashIndex == -1) return const SlashParseResult.none();

    final isStartOfInput = lastSlashIndex == 0;
    final isAfterWhitespace =
        lastSlashIndex >= 1 &&
        (text[lastSlashIndex - 1] == ' ' || text[lastSlashIndex - 1] == '\n');

    if (!isStartOfInput && !isAfterWhitespace) {
      return const SlashParseResult.none();
    }

    final textAfterSlash = text.substring(lastSlashIndex + 1, cursorPos);
    if (textAfterSlash.contains(' ') || textAfterSlash.contains('\n')) {
      return const SlashParseResult.none();
    }

    return SlashParseResult.active(
      slashIndex: lastSlashIndex,
      filterText: textAfterSlash,
    );
  }

  /// Remove the slash-command text from [text], returning a new
  /// [TextEditingValue] with the command text (from [slashIndex] to
  /// [cursorPos]) removed and the cursor placed at [slashIndex].
  static TextEditingValue clearCommandText(
    String text,
    int cursorPos,
    int slashIndex,
  ) {
    final newText = text.substring(0, slashIndex) + text.substring(cursorPos);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: slashIndex),
    );
  }
}
