// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model_client.dart';
import '../../styles/file_attachment_style.dart';

/// A widget that displays a file attachment.
///
/// This widget creates a container with a file icon and information about the
/// attached file, such as its name and MIME type.
@immutable
class FileAttachmentView extends StatelessWidget {
  /// Creates a FileAttachmentView.
  ///
  /// The [dataPart] parameter must not be null and represents the
  /// file attachment to be displayed.
  const FileAttachmentView(this.dataPart, {super.key});

  /// The data part to be displayed.
  final DataPart dataPart;

  @override
  Widget build(BuildContext context) => ChatViewModelClient(
    builder: (context, viewModel, child) {
      final attachmentStyle = FileAttachmentStyle.resolve(
        viewModel.style?.fileAttachmentStyle,
      );

      return Container(
        height: 80,
        padding: const EdgeInsets.all(8),
        decoration: attachmentStyle.decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.all(10),
              decoration: attachmentStyle.iconDecoration,
              child: Icon(
                attachmentStyle.icon,
                color: attachmentStyle.iconColor,
                size: 24,
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dataPart.name ?? Part.nameFromMimeType(dataPart.mimeType),
                    style: attachmentStyle.filenameStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    dataPart.mimeType,
                    style: attachmentStyle.filetypeStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
