// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

/// Fallback drag and drop handler for platforms without a specific adapter.
class DragAndDropHandler {
  /// Creates a drag and drop handler.
  const DragAndDropHandler({
    required this.onAttachments,
    this.onDragEnter,
    this.onDragExit,
  });

  /// Callback that receives attachments when files are dropped.
  final void Function(Iterable<Part> attachments) onAttachments;

  /// Optional callback when a drag enters the drop zone.
  final VoidCallback? onDragEnter;

  /// Optional callback when a drag exits the drop zone.
  final VoidCallback? onDragExit;

  /// Returns [child] unchanged when no drag/drop adapter is available.
  Widget buildDropRegion({
    required Widget child,
    HitTestBehavior hitTestBehavior = HitTestBehavior.deferToChild,
  }) => child;

  /// No file URI drop handling is available in the fallback adapter.
  @visibleForTesting
  Future<Part?> handleDroppedFile(Uri data) async => null;
}
