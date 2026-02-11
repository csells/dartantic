// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/views/chat_input/slash_command_parser.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SlashCommandParser.parse', () {
    test('returns inactive for empty text', () {
      final result = SlashCommandParser.parse(
        '',
        const TextSelection.collapsed(offset: 0),
      );
      expect(result.isActive, isFalse);
    });

    test('returns inactive for invalid selection', () {
      final result = SlashCommandParser.parse(
        'hello',
        const TextSelection(baseOffset: -1, extentOffset: -1),
      );
      expect(result.isActive, isFalse);
    });

    test('returns inactive when cursor is at position 0', () {
      final result = SlashCommandParser.parse(
        '/hello',
        const TextSelection.collapsed(offset: 0),
      );
      expect(result.isActive, isFalse);
    });

    test('detects slash at start of input', () {
      final result = SlashCommandParser.parse(
        '/',
        const TextSelection.collapsed(offset: 1),
      );
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 0);
      expect(result.filterText, '');
    });

    test('detects slash with filter text', () {
      final result = SlashCommandParser.parse(
        '/help',
        const TextSelection.collapsed(offset: 5),
      );
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 0);
      expect(result.filterText, 'help');
    });

    test('detects slash after space', () {
      final result = SlashCommandParser.parse(
        'hello /cmd',
        const TextSelection.collapsed(offset: 10),
      );
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 6);
      expect(result.filterText, 'cmd');
    });

    test('detects slash after newline', () {
      final result = SlashCommandParser.parse(
        'hello\n/',
        const TextSelection.collapsed(offset: 7),
      );
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 6);
      expect(result.filterText, '');
    });

    test('returns inactive when slash is mid-word', () {
      final result = SlashCommandParser.parse(
        'word/',
        const TextSelection.collapsed(offset: 5),
      );
      expect(result.isActive, isFalse);
    });

    test('returns inactive when filter text contains space', () {
      final result = SlashCommandParser.parse(
        '/hello world',
        const TextSelection.collapsed(offset: 12),
      );
      expect(result.isActive, isFalse);
    });

    test('returns inactive when filter text contains newline', () {
      final result = SlashCommandParser.parse(
        '/hello\nworld',
        const TextSelection.collapsed(offset: 12),
      );
      expect(result.isActive, isFalse);
    });

    test('returns inactive when no slash present', () {
      final result = SlashCommandParser.parse(
        'hello world',
        const TextSelection.collapsed(offset: 11),
      );
      expect(result.isActive, isFalse);
    });

    test('detects last slash when multiple exist', () {
      final result = SlashCommandParser.parse(
        '/ some text /cmd',
        const TextSelection.collapsed(offset: 16),
      );
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 12);
      expect(result.filterText, 'cmd');
    });
  });

  group('SlashCommandParser.clearCommandText', () {
    test('removes slash and filter text', () {
      final result = SlashCommandParser.clearCommandText('/hello', 6, 0);
      expect(result.text, '');
      expect(result.selection.baseOffset, 0);
    });

    test('preserves text before and after slash command', () {
      final result = SlashCommandParser.clearCommandText(
        'before /cmd after',
        11,
        7,
      );
      expect(result.text, 'before  after');
      expect(result.selection.baseOffset, 7);
    });

    test('handles slash at start with trailing text', () {
      final result = SlashCommandParser.clearCommandText('/cmd rest', 4, 0);
      expect(result.text, ' rest');
      expect(result.selection.baseOffset, 0);
    });
  });

  group('SlashParseResult', () {
    test('none result is inactive', () {
      const result = SlashParseResult.none();
      expect(result.isActive, isFalse);
      expect(result.slashIndex, -1);
      expect(result.filterText, '');
    });

    test('active result is active', () {
      const result = SlashParseResult.active(slashIndex: 5, filterText: 'test');
      expect(result.isActive, isTrue);
      expect(result.slashIndex, 5);
      expect(result.filterText, 'test');
    });
  });
}
