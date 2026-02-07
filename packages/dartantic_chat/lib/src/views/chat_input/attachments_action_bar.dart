// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dartantic_chat/src/dialogs/url_input_dialog.dart';
import 'package:dartantic_chat/src/utility.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart'
    show ButtonStyle, Icons, MenuAnchor, MenuItemButton, MenuStyle, Theme;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../models/chat_command.dart';
import '../../platform_helper/platform_helper.dart';
import '../../styles/styles.dart';
import '../action_button.dart';

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

/// A widget that provides an action bar for attaching files or images.
@immutable
class AttachmentActionBar extends StatefulWidget {
  /// Creates an [AttachmentActionBar].
  ///
  /// The [onAttachments] parameter is required and is called when attachments
  /// are selected. The [offset] parameter can be used to adjust the position
  /// of the menu that appears when the attachment button is pressed.
  ///
  /// The [key] parameter is forwarded to the superclass.
  const AttachmentActionBar({
    required this.onAttachments,
    this.offset,
    this.onSelection,
    this.onMenuChanged,
    super.key,
  });

  /// Controls the visibility of the attachments menu.
  ///
  /// When [visible] is true, the menu will be shown if it's not already visible.
  /// When false, the menu will be hidden if it's currently visible.
  void setMenuVisible(bool visible, {String? filter}) {
    assert(
      key is GlobalKey<AttachmentActionBarState>,
      'AttachmentActionBar.setMenuVisible was called, but the widget handle is incorrectly configured. '
      'A GlobalKey<AttachmentActionBarState> must be provided to the AttachmentActionBar constructor '
      'to enable external menu control. Current key: $key',
    );

    final stateKey = key;
    if (stateKey is GlobalKey<AttachmentActionBarState>) {
      stateKey.currentState?.setMenuVisible(visible, filter: filter);
    }
  }

  /// Callback function that is called when attachments are selected.
  ///
  /// The selected [Part]s are passed as an argument to this function.
  final Function(Iterable<Part> attachments) onAttachments;

  /// The offset used to position the attachment menu.
  ///
  /// This can be used to adjust where the menu appears relative to the
  /// attachment button. If null, default positioning is used.
  final Offset? offset;

  /// Callback function called when an item is selected from the menu.
  final VoidCallback? onSelection;

  /// Callback function called when the menu open state changes.
  final ValueChanged<bool>? onMenuChanged;

  @override
  AttachmentActionBarState createState() => AttachmentActionBarState();
}

/// The state for the [AttachmentActionBar] widget.
///
/// This class manages the state and behavior of the attachment action bar,
/// including handling user interactions with the attachment menu and managing
/// the attachment selection process.
class AttachmentActionBarState extends State<AttachmentActionBar> {
  late final bool _canCamera;
  final _menuController = MenuController();

  /// Internal flag used for testing mobile behavior.
  @visibleForTesting
  bool? testIsMobile;

  bool get _isMobile => testIsMobile ?? isMobile;

  @override
  void initState() {
    super.initState();
    _canCamera = canTakePhoto();
  }

  String? _filterQuery;
  int _activeIndex = 0;
  List<MenuItemButton> _filteredItems = [];

  /// Controls the visibility of the attachment menu.
  ///
  /// If [visible] is true, opens the menu if it's not already open.
  /// If [visible] is false, closes the menu if it's currently open.
  /// Whether the attachment menu is currently open.
  bool get isMenuOpen => _menuController.isOpen || _filterQuery != null;

  /// The currently active index in the filtered menu.
  @visibleForTesting
  int get activeIndex => _activeIndex;

  /// Controls the visibility of the attachment menu.
  /// [setMenuVisible] method.
  void setMenuVisible(bool visible, {String? filter}) {
    final wasOpen = isMenuOpen;
    setState(() {
      if (_filterQuery != filter) {
        _filterQuery = filter;
        _activeIndex = 0;
      }
      if (visible) {
        if (!_menuController.isOpen) {
          _activeIndex = 0;
          _menuController.open();
        }
      } else {
        _menuController.close();
        _filterQuery = null;
      }
    });

    // Notify parent of menu state change
    final isOpen = isMenuOpen;
    if (wasOpen != isOpen && widget.onMenuChanged != null) {
      widget.onMenuChanged!(isOpen);
    }
  }

  /// Sets the filter query for the command menu.
  ///
  /// Note: This method only sets the filter query but does not automatically
  /// open the menu. The menu should be opened separately via [setMenuVisible]
  /// when appropriate. This design allows for scenarios where the filter
  /// needs to be updated before the menu is displayed (e.g., during typing
  /// before the menu trigger conditions are met).
  void setFilter(String? query) {
    if (_filterQuery == query) return;
    setState(() {
      _filterQuery = query;
      _activeIndex = 0;
    });
  }

  /// Selects the next item in the filtered list.
  void selectNext() {
    if (_filteredItems.isEmpty) return;
    setState(() {
      _activeIndex = (_activeIndex + 1) % _filteredItems.length;
    });
  }

  /// Selects the previous item in the filtered list.
  void selectPrevious() {
    if (_filteredItems.isEmpty) return;
    setState(() {
      _activeIndex =
          (_activeIndex - 1 + _filteredItems.length) % _filteredItems.length;
    });
  }

  /// Triggers the action of the currently selected item.
  void triggerSelected() {
    // We get the current view model and style to re-compute the data correctly
    final viewModel = ChatViewModelProvider.of(context);
    final chatStyle = ChatViewStyle.resolve(viewModel.style);
    final filteredData = _getFilteredData(chatStyle, viewModel.commands);

    if (filteredData.isEmpty ||
        _activeIndex < 0 ||
        _activeIndex >= filteredData.length) {
      return;
    }

    final data = filteredData[_activeIndex];

    // Trigger the underlying action and hide the menu
    data.onPressed();
    widget.onSelection?.call();
    setMenuVisible(false);
  }

  List<CommandMenuItem> _getFilteredData(
    ChatViewStyle chatStyle,
    List<ChatCommand> commands,
  ) {
    final allItems = <CommandMenuItem>[
      if (_canCamera)
        (
          name: chatStyle.cameraButtonStyle!.text!,
          keywords: ['camera', 'photo', 'take'],
          icon: chatStyle.cameraButtonStyle!.icon!,
          onPressed: () => _onCamera(),
          style: chatStyle.cameraButtonStyle!,
        ),
      (
        name: chatStyle.galleryButtonStyle!.text!,
        keywords: ['gallery', 'image', 'photo', 'attach'],
        icon: chatStyle.galleryButtonStyle!.icon!,
        onPressed: () => _onGallery(),
        style: chatStyle.galleryButtonStyle!,
      ),
      (
        name: chatStyle.attachFileButtonStyle!.text!,
        keywords: ['file', 'attach', 'document'],
        icon: chatStyle.attachFileButtonStyle!.icon!,
        onPressed: () => _onFile(),
        style: chatStyle.attachFileButtonStyle!,
      ),
      (
        name: chatStyle.urlButtonStyle!.text!,
        keywords: ['url', 'link', 'attach', 'web'],
        icon: Icons.link,
        onPressed: () => _onUrl(),
        style: chatStyle.urlButtonStyle!,
      ),
      ...commands.map(
        (c) => (
          name: c.name,
          keywords: c.keywords,
          icon: c.icon,
          onPressed: c.onPressed,
          style: c.style ?? const ActionButtonStyle(),
        ),
      ),
    ];

    return _filterQuery == null || _filterQuery!.isEmpty
        ? allItems
        : allItems.where((item) {
            final query = _filterQuery!.toLowerCase();
            return item.name.toLowerCase().contains(query) ||
                item.keywords.any((k) => k.contains(query));
          }).toList();
  }

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final chatStyle = ChatViewStyle.resolve(viewModel.style);
      final filteredData = _getFilteredData(chatStyle, viewModel.commands);

      _filteredItems = List.generate(filteredData.length, (index) {
        final data = filteredData[index];
        final isActive = index == activeIndex;

        return MenuItemButton(
          leadingIcon: Icon(data.icon, color: data.style.iconColor),
          onPressed: () {
            data.onPressed();
            widget.onSelection?.call();
            setMenuVisible(false);
          },
          style: isActive
              ? ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    (data.style.iconColor ??
                            Theme.of(context).colorScheme.onSurface)
                        .withValues(alpha: 0.12),
                  ),
                )
              : null,
          child: Text(data.name, style: data.style.textStyle),
        );
      });

      return MenuAnchor(
        controller: _menuController,
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(chatStyle.menuColor),
        ),
        // Force menu above by using negative offset equal to estimated menu
        // height. NOTE: This is a hack to get the menu to appear above the
        // button so that it doesn't appear below the soft keyboard. There
        // should be no reason to set the alignmentOffset at all once this bug
        // is fixed: https://github.com/flutter/flutter/issues/142921
        alignmentOffset: _menuAnchorAlignmentOffsetHackForMobile(
          chatStyle,
          _filteredItems.length,
        ),
        consumeOutsideTap: true,
        onClose: () {
          // Clear filter query when menu closes via outside tap
          if (_filterQuery != null) {
            setState(() {
              _filterQuery = null;
              _activeIndex = 0;
            });
            // Notify parent of menu state change
            widget.onMenuChanged?.call(false);
          }
        },
        builder: (_, controller, _) => ActionButton(
          onPressed: controller.isOpen ? controller.close : controller.open,
          style: chatStyle.addButtonStyle!,
        ),
        menuChildren: _filteredItems,
      );
    },
  );

  Offset? _menuAnchorAlignmentOffsetHackForMobile(
    ChatViewStyle chatStyle,
    int menuItems,
  ) {
    // From MenuAnchor source: minimum height is 48.0 + some padding for
    // safety
    final double itemHeight = 48.0 + 8.0;
    final double menuPadding = 16.0;

    // Calculate menu height based on actual number of items
    final double estimatedMenuHeight = (menuItems * itemHeight) + menuPadding;

    if (widget.offset != null) {
      // If an offset is provided (e.g. from slash command), we use it.
      // On mobile, we still need to ensure it doesn't get covered by the keyboard
      // if it's too low, but for now we'll trust the offset and adjust height
      // to make it appear above the calculated point.
      return Offset(widget.offset!.dx, widget.offset!.dy - estimatedMenuHeight);
    }

    // Limit the potential damage on this hack to mobile platforms
    if (!_isMobile) return null;

    return Offset(0, -estimatedMenuHeight);
  }

  void _onCamera() => unawaited(_pickImage(ImageSource.camera));
  void _onGallery() => unawaited(_pickImage(ImageSource.gallery));

  Future<void> _pickImage(ImageSource source) async {
    assert(
      source == ImageSource.camera || source == ImageSource.gallery,
      'Unsupported image source: $source',
    );

    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final pics = await picker.pickMultiImage();
        final attachments = await Future.wait(pics.map(_dataPartFromXFile));
        widget.onAttachments(attachments);
      } else {
        final pic = await takePhoto(context);
        if (pic == null) return;
        widget.onAttachments([await _dataPartFromXFile(pic)]);
      }
    } on Exception catch (ex) {
      if (context.mounted) {
        // I just checked this! ^^^
        // ignore: use_build_context_synchronously
        AdaptiveSnackBar.show(context, 'Unable to pick an image: $ex');
      }
    }
  }

  Future<void> _onFile() async {
    try {
      final files = await openFiles();
      final attachments = await Future.wait(files.map(_dataPartFromXFile));
      widget.onAttachments(attachments);
    } on Exception catch (ex) {
      if (context.mounted) {
        // I just checked this! ^^^
        // ignore: use_build_context_synchronously
        AdaptiveSnackBar.show(context, 'Unable to pick a file: $ex');
      }
    }
  }

  Future<void> _onUrl() async {
    try {
      final url = await showUrlInputDialog(context);
      if (url == null) return;
      widget.onAttachments([LinkPart(url.url, name: url.name)]);
    } on Exception catch (ex) {
      if (context.mounted) {
        // I just checked this! ^^^
        // ignore: use_build_context_synchronously
        AdaptiveSnackBar.show(context, 'Unable to pick a URL: $ex');
      }
    }
  }

  /// Creates a [DataPart] from an [XFile].
  Future<DataPart> _dataPartFromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? 'application/octet-stream';
    return DataPart(bytes, mimeType: mimeType, name: file.name);
  }
}
