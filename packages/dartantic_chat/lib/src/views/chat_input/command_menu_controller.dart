// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../styles/action_button_style.dart';

/// A menu item in the command menu.
///
/// This record defines the structure for items displayed in the attachment
/// and command menu, which can be triggered via the UI or slash commands.
///
/// Fields:
/// * [name]: The display name of the command.
/// * [icon]: The icon to display next to the command name.
/// * [onPressed]: The callback to execute when the command is selected.
/// * [style]: The visual style of the command button.
/// * [keywords]: A list of keywords used for filtering this command.
typedef CommandMenuItem = ({
  String name,
  IconData icon,
  VoidCallback onPressed,
  ActionButtonStyle style,
  List<String> keywords,
});

/// Controls the state of the command menu (slash-command popup).
///
/// This is a [ChangeNotifier] that follows the same pattern as
/// `WaveformRecorderController`: created in a parent widget, passed to
/// children as a parameter, and observed via [ListenableBuilder].
class CommandMenuController extends ChangeNotifier {
  bool _isOpen = false;
  String _filterQuery = '';
  int _activeIndex = 0;
  List<CommandMenuItem> _allItems = const [];
  List<CommandMenuItem> _filteredItems = const [];

  /// Whether the command menu is currently open.
  bool get isOpen => _isOpen;

  /// The current filter query (empty string means no filter).
  String get filterQuery => _filterQuery;

  /// The index of the currently highlighted item.
  int get activeIndex => _activeIndex;

  /// The filtered list of menu items matching the current query.
  List<CommandMenuItem> get filteredItems => _filteredItems;

  /// Opens the command menu with an optional [filterQuery].
  void open({String filterQuery = ''}) {
    _isOpen = true;
    _filterQuery = filterQuery;
    _activeIndex = 0;
    _recomputeFilteredItems();
    notifyListeners();
  }

  /// Closes the command menu and resets state.
  void close() {
    if (!_isOpen && _filterQuery.isEmpty) return;
    _isOpen = false;
    _filterQuery = '';
    _activeIndex = 0;
    notifyListeners();
  }

  /// Updates the filter query and recomputes filtered items.
  void updateFilter(String query) {
    if (_filterQuery == query) return;
    _filterQuery = query;
    _activeIndex = 0;
    _recomputeFilteredItems();
    notifyListeners();
  }

  /// Sets the source list of all menu items and recomputes filtered items.
  ///
  /// This method does **not** call [notifyListeners] because it is typically
  /// invoked during [build] (when the widget tree pushes fresh item data into
  /// the controller). Notifying during build would trigger a `setState` in
  /// listeners while the framework is already rebuilding, which is illegal.
  /// The build that calls this method already reads the updated state
  /// immediately afterward.
  void updateMenuItems(List<CommandMenuItem> allItems) {
    _allItems = List.unmodifiable(allItems);
    _recomputeFilteredItems();
  }

  /// Moves the active selection to the next item (wraps around).
  void selectNext() {
    if (_filteredItems.isEmpty) return;
    _activeIndex = (_activeIndex + 1) % _filteredItems.length;
    notifyListeners();
  }

  /// Moves the active selection to the previous item (wraps around).
  void selectPrevious() {
    if (_filteredItems.isEmpty) return;
    _activeIndex =
        (_activeIndex - 1 + _filteredItems.length) % _filteredItems.length;
    notifyListeners();
  }

  /// Triggers the action of the currently selected item.
  ///
  /// Invokes [onSelection] first (to clear slash-command text while the
  /// cursor position is still valid), then calls the item's `onPressed`,
  /// then closes the menu.
  void triggerSelected({VoidCallback? onSelection}) {
    if (_filteredItems.isEmpty) return;

    final safeIndex = _activeIndex.clamp(0, _filteredItems.length - 1);
    final item = _filteredItems[safeIndex];

    onSelection?.call();
    item.onPressed();
    close();
  }

  void _recomputeFilteredItems() {
    if (_filterQuery.isEmpty) {
      _filteredItems = List.unmodifiable(_allItems);
      return;
    }

    final query = _filterQuery.toLowerCase();
    _filteredItems = List.unmodifiable(
      _allItems.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.keywords.any((k) => k.toLowerCase().contains(query));
      }),
    );
  }
}
