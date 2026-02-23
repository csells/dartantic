// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/image_preview_dialog.dart';

/// A widget that displays an image attachment.
///
/// This widget aligns the image to the center-right of its parent and
/// allows the user to tap on the image to open a preview dialog.
@immutable
class ImageAttachmentView extends StatelessWidget {
  /// Creates an ImageAttachmentView.
  ///
  /// The [dataPart] parameter must not be null and represents the
  /// image data part to be displayed.
  const ImageAttachmentView(this.dataPart, {super.key});

  /// The image data part to be displayed.
  final DataPart dataPart;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: GestureDetector(
      onTap: () => unawaited(_showPreviewDialog(context)),
      child: Image.memory(dataPart.bytes),
    ),
  );

  Future<void> _showPreviewDialog(BuildContext context) async =>
      AdaptiveAlertDialog.show<void>(
        context: context,
        content: ImagePreviewDialog(dataPart),
      );
}
