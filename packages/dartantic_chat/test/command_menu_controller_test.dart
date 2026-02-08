// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/styles/action_button_style.dart';
import 'package:dartantic_chat/src/views/chat_input/command_menu_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

CommandMenuItem _item(String name, {List<String> keywords = const []}) => (
  name: name,
  icon: const IconData(0),
  onPressed: () {},
  style: const ActionButtonStyle(),
  keywords: keywords,
);

void main() {
  group('CommandMenuController', () {
    late CommandMenuController controller;

    setUp(() {
      controller = CommandMenuController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts closed with empty state', () {
      expect(controller.isOpen, isFalse);
      expect(controller.filterQuery, '');
      expect(controller.activeIndex, 0);
      expect(controller.filteredItems, isEmpty);
    });

    test('open sets isOpen and notifies', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.open();

      expect(controller.isOpen, isTrue);
      expect(notified, isTrue);
    });

    test('open with filterQuery filters items', () {
      controller.updateMenuItems([
        _item('Camera', keywords: ['camera']),
        _item('File', keywords: ['file']),
      ]);

      controller.open(filterQuery: 'cam');

      expect(controller.isOpen, isTrue);
      expect(controller.filterQuery, 'cam');
      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'Camera');
    });

    test('close resets state', () {
      controller.open(filterQuery: 'test');
      controller.close();

      expect(controller.isOpen, isFalse);
      expect(controller.filterQuery, '');
      expect(controller.activeIndex, 0);
    });

    test('close is idempotent when already closed', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.close();

      expect(notifyCount, 0);
    });

    test('updateFilter recomputes filtered items', () {
      controller.updateMenuItems([
        _item('Camera', keywords: ['camera']),
        _item('File', keywords: ['file']),
        _item('URL', keywords: ['url']),
      ]);

      controller.updateFilter('fi');

      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'File');
      expect(controller.activeIndex, 0);
    });

    test('updateFilter with empty string shows all items', () {
      controller.updateMenuItems([_item('Camera'), _item('File')]);

      controller.updateFilter('cam');
      expect(controller.filteredItems.length, 1);

      controller.updateFilter('');
      expect(controller.filteredItems.length, 2);
    });

    test('updateMenuItems recomputes with current filter', () {
      controller.open(filterQuery: 'url');

      controller.updateMenuItems([
        _item('Camera', keywords: ['camera']),
        _item('URL', keywords: ['url']),
      ]);

      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'URL');
    });

    test('selectNext wraps around', () {
      controller.updateMenuItems([_item('A'), _item('B'), _item('C')]);

      expect(controller.activeIndex, 0);

      controller.selectNext();
      expect(controller.activeIndex, 1);

      controller.selectNext();
      expect(controller.activeIndex, 2);

      controller.selectNext();
      expect(controller.activeIndex, 0);
    });

    test('selectPrevious wraps around', () {
      controller.updateMenuItems([_item('A'), _item('B'), _item('C')]);

      expect(controller.activeIndex, 0);

      controller.selectPrevious();
      expect(controller.activeIndex, 2);

      controller.selectPrevious();
      expect(controller.activeIndex, 1);
    });

    test('selectNext/selectPrevious no-op on empty items', () {
      controller.selectNext();
      expect(controller.activeIndex, 0);

      controller.selectPrevious();
      expect(controller.activeIndex, 0);
    });

    test('triggerSelected calls onPressed and onSelection', () {
      var itemPressed = false;
      var selectionCalled = false;

      controller.updateMenuItems([
        (
          name: 'Test',
          icon: const IconData(0),
          onPressed: () => itemPressed = true,
          style: const ActionButtonStyle(),
          keywords: const [],
        ),
      ]);

      controller.triggerSelected(onSelection: () => selectionCalled = true);

      expect(itemPressed, isTrue);
      expect(selectionCalled, isTrue);
      expect(controller.isOpen, isFalse);
    });

    test('triggerSelected no-ops on empty items', () {
      controller.triggerSelected(onSelection: () => fail('should not call'));
    });

    test('triggerSelected clamps index to safe range', () {
      var pressedName = '';

      controller.updateMenuItems([
        (
          name: 'Only',
          icon: const IconData(0),
          onPressed: () => pressedName = 'Only',
          style: const ActionButtonStyle(),
          keywords: const [],
        ),
      ]);

      // Manually set active index beyond range via multiple selectNext calls
      // (the list has 1 item, so wrapping keeps it at 0 anyway)
      controller.selectNext();
      controller.triggerSelected();

      expect(pressedName, 'Only');
    });

    test('filtering matches by name case-insensitively', () {
      controller.updateMenuItems([_item('Attach File'), _item('Attach Image')]);

      controller.updateFilter('FILE');

      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'Attach File');
    });

    test('filtering matches by keywords', () {
      controller.updateMenuItems([
        _item('Attach Image', keywords: ['gallery', 'photo']),
        _item('Attach File', keywords: ['file', 'document']),
      ]);

      controller.updateFilter('gallery');

      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'Attach Image');
    });

    test('filtering matches keywords case-insensitively', () {
      controller.updateMenuItems([
        _item('Attach Image', keywords: ['Gallery', 'Photo']),
        _item('Attach File', keywords: ['File', 'Document']),
      ]);

      controller.updateFilter('gallery');

      expect(controller.filteredItems.length, 1);
      expect(controller.filteredItems.first.name, 'Attach Image');
    });
  });
}
