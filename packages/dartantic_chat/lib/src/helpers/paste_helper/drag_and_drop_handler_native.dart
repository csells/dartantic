// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import 'dropped_file_converter.dart';

final _formats = [
  ...Formats.standardFormats.whereType<FileFormat>(),
  Formats.epub,
  Formats.md,
  Formats.opus,
];

/// Handles drag and drop operations for native desktop platforms.
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

  /// Wraps [child] in a native file drop target.
  Widget buildDropRegion({
    required Widget child,
    HitTestBehavior hitTestBehavior = HitTestBehavior.deferToChild,
  }) {
    return DropRegion(
      formats: [Formats.fileUri, ..._formats],
      hitTestBehavior: hitTestBehavior,
      onDropOver: (_) => DropOperation.copy,
      onPerformDrop: (event) async {
        final parts = <Part>[];
        final futures = <Future<void>>[];

        for (final item in event.session.items) {
          final reader = item.dataReader;
          if (reader == null) continue;

          final completer = Completer<void>();
          reader.getValue(Formats.fileUri, (val) async {
            if (val != null) {
              final file = await _handleDroppedFile(val);
              if (file != null) parts.add(file);
            }
            completer.complete();
          });
          futures.add(completer.future);
        }

        await Future.wait(futures).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Timeout waiting for file drop futures');
            return [];
          },
        );
        if (parts.isNotEmpty) onAttachments(parts);
      },
      onDropEnter: (_) => onDragEnter?.call(),
      onDropLeave: (_) => onDragExit?.call(),
      child: child,
    );
  }

  Future<Part?> _handleDroppedFile(Uri data) async {
    try {
      final path = data.toFilePath();
      final file = XFile(path);
      final bytes = await file.readAsBytes();

      return DroppedFileConverter.toDataPart(
        bytes: bytes,
        originalName: file.name,
      );
    } catch (e) {
      debugPrint('Error handling dropped file: $e');
      return null;
    }
  }

  /// Test-only wrapper to expose file drop handling for unit tests.
  @visibleForTesting
  Future<Part?> handleDroppedFile(Uri data) => _handleDroppedFile(data);
}
