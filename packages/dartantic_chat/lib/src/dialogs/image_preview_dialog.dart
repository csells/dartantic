// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

/// Displays a dialog to preview the image when the user taps on an attached
/// image.
@immutable
class ImagePreviewDialog extends StatelessWidget {
  /// Shows the [ImagePreviewDialog] for the given [dataPart].
  const ImagePreviewDialog(this.dataPart, {super.key});

  /// The image data part to be previewed in the dialog.
  final DataPart dataPart;

  static const _fit = BoxFit.contain;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Center(child: Image.memory(dataPart.bytes, fit: _fit)),
  );
}
