// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dartantic_chat/src/dialogs/url_input_dialog.dart';
import 'package:dartantic_chat/src/utility.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart'
    show Icons, MenuAnchor, MenuItemButton, MenuStyle;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../platform_helper/platform_helper.dart';
import '../../styles/chat_view_style.dart';
import '../action_button.dart';

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
    super.key,
  });

  /// Controls the visibility of the attachments menu.
  ///
  /// When [visible] is true, the menu will be shown if it's not already visible.
  /// When false, the menu will be hidden if it's currently visible.
  void setMenuVisible(bool visible) {
    assert(
      key is GlobalKey<AttachmentActionBarState>,
      'AttachmentActionBar.setMenuVisible was called, but the widget handle is incorrectly configured. '
      'A GlobalKey<AttachmentActionBarState> must be provided to the AttachmentActionBar constructor '
      'to enable external menu control. Current key: $key',
    );

    final stateKey = key;
    if (stateKey is GlobalKey<AttachmentActionBarState>) {
      stateKey.currentState?.setMenuVisible(visible);
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

  /// Controls the visibility of the attachment menu.
  ///
  /// If [visible] is true, opens the menu if it's not already open.
  /// If [visible] is false, closes the menu if it's currently open.
  ///
  /// This is called by the parent [AttachmentActionBar] widget's public
  /// [setMenuVisible] method.
  void setMenuVisible(bool visible) {
    if (visible) {
      _menuController.open();
    } else {
      _menuController.close();
    }
  }

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final chatStyle = ChatViewStyle.resolve(viewModel.style);
      final menuItems = [
        if (_canCamera)
          MenuItemButton(
            leadingIcon: Icon(
              chatStyle.cameraButtonStyle!.icon!,
              color: chatStyle.cameraButtonStyle!.iconColor,
            ),
            onPressed: () => _onCamera(),
            child: Text(
              chatStyle.cameraButtonStyle!.text!,
              style: chatStyle.cameraButtonStyle!.textStyle,
            ),
          ),
        MenuItemButton(
          leadingIcon: Icon(
            chatStyle.galleryButtonStyle!.icon!,
            color: chatStyle.galleryButtonStyle!.iconColor,
          ),
          onPressed: () => _onGallery(),
          child: Text(
            chatStyle.galleryButtonStyle!.text!,
            style: chatStyle.galleryButtonStyle!.textStyle,
          ),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            chatStyle.attachFileButtonStyle!.icon!,
            color: chatStyle.attachFileButtonStyle!.iconColor,
          ),
          onPressed: () => _onFile(),
          child: Text(
            chatStyle.attachFileButtonStyle!.text!,
            style: chatStyle.attachFileButtonStyle!.textStyle,
          ),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.link,
            color: chatStyle.urlButtonStyle!.iconColor,
          ),
          onPressed: () => _onUrl(),
          child: Text(
            chatStyle.urlButtonStyle!.text!,
            style: chatStyle.urlButtonStyle!.textStyle,
          ),
        ),
      ];

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
          menuItems.length,
        ),
        consumeOutsideTap: true,
        builder: (_, controller, _) => ActionButton(
          onPressed: controller.isOpen ? controller.close : controller.open,
          style: chatStyle.addButtonStyle!,
        ),
        menuChildren: menuItems,
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
