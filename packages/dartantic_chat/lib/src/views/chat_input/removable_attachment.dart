// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/image_preview_dialog.dart';
import '../../styles/chat_view_style.dart';
import '../action_button.dart';
import '../attachment_view/attachment_view.dart';

/// A widget that displays an attachment with a remove button.
@immutable
class RemovableAttachment extends StatelessWidget {
  /// Creates a [RemovableAttachment].
  ///
  /// The [attachment] parameter is required and represents the attachment to
  /// display. The [onRemove] parameter is a callback function that is called
  /// when the remove button is pressed.
  const RemovableAttachment({
    required this.attachment,
    required this.onRemove,
    super.key,
  });

  /// The attachment to display.
  final Part attachment;

  /// Callback function that is called when the remove button is pressed.
  ///
  /// The [Part] to be removed is passed as an argument to this function.
  final Function(Part) onRemove;

  @override
  Widget build(BuildContext context) {
    // Check if this is an image DataPart
    final isImage =
        attachment is DataPart &&
        (attachment as DataPart).mimeType.startsWith('image/');

    return Stack(
      children: [
        GestureDetector(
          onTap: isImage ? () => unawaited(_showPreviewDialog(context)) : null,
          child: Container(
            padding: const EdgeInsets.only(right: 12),
            height: 80,
            child: AttachmentView(attachment),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(2),
          child: ChatViewModelClient(
            builder: (context, viewModel, child) {
              final chatStyle = ChatViewStyle.resolve(viewModel.style);
              return ActionButton(
                style: chatStyle.closeButtonStyle!,
                size: 20,
                onPressed: () => onRemove(attachment),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showPreviewDialog(BuildContext context) async =>
      AdaptiveAlertDialog.show<void>(
        context: context,
        content: ImagePreviewDialog(attachment as DataPart),
      );
}
