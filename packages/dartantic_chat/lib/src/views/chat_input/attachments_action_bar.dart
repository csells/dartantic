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
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../models/chat_command.dart';
import 'chat_input_constants.dart';
import '../../platform_helper/platform_helper.dart';
import '../../styles/styles.dart';
import '../action_button.dart';
import 'command_menu_controller.dart';

/// A widget that provides an action bar for attaching files or images.
///
/// When a [commandMenuController] is provided, the menu items are driven
/// by the controller's state (open/close, filter, active index). Without
/// a controller, the bar operates as a simple attachment menu.
@immutable
class AttachmentActionBar extends StatefulWidget {
  /// Creates an [AttachmentActionBar].
  ///
  /// The [onAttachments] parameter is required and is called when attachments
  /// are selected.
  const AttachmentActionBar({
    required this.onAttachments,
    this.commandMenuController,
    this.menuOffset,
    this.onSelection,
    super.key,
  });

  /// Callback function that is called when attachments are selected.
  ///
  /// The selected [Part]s are passed as an argument to this function.
  final Function(Iterable<Part> attachments) onAttachments;

  /// Optional controller for command menu state.
  ///
  /// When provided, the menu visibility, filtering, and active index are
  /// driven by this controller rather than internal state.
  final CommandMenuController? commandMenuController;

  /// The offset used to position the menu relative to the action bar.
  ///
  /// This is typically computed from the caret position when a slash
  /// command triggers the menu. If null, default positioning is used.
  final Offset? menuOffset;

  /// Callback function called when an item is selected from the menu.
  final VoidCallback? onSelection;

  @override
  State<AttachmentActionBar> createState() => _AttachmentActionBarState();
}

class _AttachmentActionBarState extends State<AttachmentActionBar> {
  late final bool _canCamera;
  final _menuController = MenuController();

  bool? _testIsMobile;

  /// Sets the test-only mobile override and triggers a rebuild.
  @visibleForTesting
  set testIsMobile(bool? value) {
    setState(() => _testIsMobile = value);
  }

  bool get _isMobile => _testIsMobile ?? isMobile;

  CommandMenuController? get _commandController => widget.commandMenuController;

  @override
  void initState() {
    super.initState();
    _canCamera = canTakePhoto();
    _commandController?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(AttachmentActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandMenuController != widget.commandMenuController) {
      oldWidget.commandMenuController?.removeListener(_onControllerChanged);
      widget.commandMenuController?.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _commandController?.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final controller = _commandController;
    if (controller == null) return;

    if (controller.isOpen && !_menuController.isOpen) {
      _menuController.open();
    } else if (!controller.isOpen && _menuController.isOpen) {
      _menuController.close();
    }

    // Trigger a rebuild so the menu children and alignment offset update
    setState(() {});
  }

  List<CommandMenuItem> _buildAllItems(
    ChatViewStyle chatStyle,
    List<ChatCommand> commands,
  ) {
    return <CommandMenuItem>[
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
          style:
              c.style ?? ActionButtonStyle.defaultStyle(ActionButtonType.url),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final chatStyle = ChatViewStyle.resolve(viewModel.style);
      final allItems = _buildAllItems(chatStyle, viewModel.commands);

      // Push items to the controller so it can compute filtering
      _commandController?.updateMenuItems(allItems);

      final controller = _commandController;
      final items = controller?.filteredItems ?? allItems;
      final activeIdx = controller?.activeIndex ?? -1;

      final menuChildren = List.generate(items.length, (index) {
        final data = items[index];
        final isActive = index == activeIdx;

        return MenuItemButton(
          leadingIcon: Icon(data.icon, color: data.style.iconColor),
          onPressed: () {
            widget.onSelection?.call();
            data.onPressed();
            controller?.close();
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
          menuChildren.length,
        ),
        consumeOutsideTap: true,
        onClose: () {
          controller?.close();
        },
        builder: (_, menuCtrl, _) => ActionButton(
          onPressed: menuCtrl.isOpen ? menuCtrl.close : menuCtrl.open,
          style: chatStyle.addButtonStyle!,
        ),
        menuChildren: menuChildren,
      );
    },
  );

  Offset? _menuAnchorAlignmentOffsetHackForMobile(
    ChatViewStyle chatStyle,
    int menuItems,
  ) {
    const itemHeight = ChatInputConstants.menuItemHeight;
    const menuPadding = ChatInputConstants.menuPadding;

    // Calculate menu height based on actual number of items
    final double estimatedMenuHeight = (menuItems * itemHeight) + menuPadding;

    if (widget.menuOffset != null) {
      return Offset(
        widget.menuOffset!.dx,
        widget.menuOffset!.dy - estimatedMenuHeight,
      );
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
