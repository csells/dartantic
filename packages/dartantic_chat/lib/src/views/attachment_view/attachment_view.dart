// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

import 'file_attatchment_view.dart';
import 'image_attachment_view.dart';
import 'link_attachment_view.dart';

/// A widget that displays an attachment based on its type.
///
/// This widget determines the appropriate view for the given [part]
/// and renders it accordingly. It supports data parts (files/images)
/// and link parts.
@immutable
class AttachmentView extends StatelessWidget {
  /// Creates an AttachmentView.
  ///
  /// The [part] parameter must not be null.
  const AttachmentView(this.part, {super.key});

  /// The part to be displayed.
  final Part part;

  @override
  Widget build(BuildContext context) => switch (part) {
    DataPart(mimeType: final m) when m.startsWith('image/') =>
      ImageAttachmentView(part as DataPart),
    DataPart() => FileAttachmentView(part as DataPart),
    LinkPart() => LinkAttachmentView(part as LinkPart),
    _ => const SizedBox.shrink(),
  };
}
