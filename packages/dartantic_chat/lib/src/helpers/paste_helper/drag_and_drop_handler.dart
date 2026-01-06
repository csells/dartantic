// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:universal_platform/universal_platform.dart';

import '../paste_helper/paste_extensions.dart';

/// Handles drag and drop operations for the chat input field.
///
/// This class manages the drag and drop functionality, including:
/// - Accepting dropped files and images
/// - Converting dropped content to a format the chat can handle
/// - Providing visual feedback during drag operations
class DragAndDropHandler {
  /// Creates a drag and drop handler.
  ///
  /// Parameters:
  ///   - [onAttachments]: Callback that receives a list of attachments when files are dropped.
  ///   - [onDragEnter]: Optional callback when a drag enters the drop zone.
  ///   - [onDragExit]: Optional callback when a drag exits the drop zone.
  const DragAndDropHandler({
    required this.onAttachments,
    this.onDragEnter,
    this.onDragExit,
  });

  /// Callback that receives a list of attachments when files are dropped.
  final void Function(Iterable<Part> attachments) onAttachments;

  /// Optional callback when a drag enters the drop zone.
  final VoidCallback? onDragEnter;

  /// Optional callback when a drag exits the drop zone.
  final VoidCallback? onDragExit;

  /// Creates a [DropRegion] widget that handles file drops.
  ///
  /// Parameters:
  ///   - [child]: The widget that should accept drops.
  ///   - [allowedOperations]: The types of operations allowed (copy, move, etc.)
  ///   - [hitTestBehavior]: How the drop region should behave during hit testing.
  ///   - [cursor]: The cursor to display when dragging over the region.
  ///
  /// Returns:
  ///   A [DropRegion] widget that handles file drops.
  Widget buildDropRegion({
    required Widget child,
    Set<DropOperation> allowedOperations = const {DropOperation.copy},
    HitTestBehavior hitTestBehavior = HitTestBehavior.deferToChild,
    MouseCursor cursor = SystemMouseCursors.copy,
  }) {
    return DropRegion(
      formats: [
        Formats.fileUri,
        ...Formats.standardFormats.whereType<FileFormat>(),
      ],
      hitTestBehavior: hitTestBehavior,
      onDropOver: (event) {
        return DropOperation.copy;
      },
      onPerformDrop: (event) async {
        final items = event.session.items;

        for (final item in items) {
          if (item.dataReader != null) {
            if (!UniversalPlatform.isWeb) {
              item.dataReader!.getValue(Formats.fileUri, (val) async {
                if (val != null) {
                  final file = await _handleDroppedFile(val);
                  if (file != null) {
                    onAttachments([file]);
                  }
                }
              });
            } else {
              for (final format
                  in Formats.standardFormats.whereType<FileFormat>()) {
                if (item.dataReader!.canProvide(format)) {
                  item.dataReader!.getFile(format, (file) async {
                    final stream = file.getStream();
                    await stream.toList().then((chunks) {
                      final attachmentBytes = Uint8List.fromList(
                        chunks.expand((e) => e).toList(),
                      );
                      final mimeType =
                          lookupMimeType(
                            file.fileName ?? '',
                            headerBytes: attachmentBytes,
                          ) ??
                          'application/octet-stream';
                      final fileName =
                          file.fileName ??
                          'pasted_file_${DateTime.now().millisecondsSinceEpoch}.${getExtensionFromMime(mimeType)}';
                      final dataPart = DataPart(
                        attachmentBytes,
                        mimeType: mimeType,
                        name: fileName,
                      );
                      onAttachments([dataPart]);
                      return;
                    });
                  });
                  return;
                }
              }
            }
          }
        }
      },
      onDropEnter: (_) => onDragEnter?.call(),
      onDropEnded: (_) => onDragExit?.call(),
      child: child,
    );
  }

  Future<Part?> _handleDroppedFile(Uri data) async {
    try {
      final path = data.toFilePath();
      final file = XFile(path);
      final bytes = await file.readAsBytes();
      final mimeType =
          file.mimeType ?? lookupMimeType(path, headerBytes: bytes);
      return DataPart(
        bytes,
        name: file.name,
        mimeType: mimeType ?? 'application/octet-stream',
      );
    } catch (e) {
      debugPrint('Error handling dropped file: $e');
      return null;
    }
  }

  /// Test-only wrapper to expose file drop handling for unit tests.
  @visibleForTesting
  Future<Part?> handleDroppedFile(Uri data) => _handleDroppedFile(data);

  /// Creates a [DragTarget] widget for platforms where [DropRegion] is not supported.
  ///
  /// This is a fallback for platforms that don't support the full drag and drop API.
  /// It provides basic file dropping functionality with less visual feedback.
  Widget buildLegacyDropTarget({
    required Widget child,
    required BuildContext context,
  }) {
    return DragTarget<XFile>(
      onAcceptWithDetails: (file) async {
        try {
          final bytes = await file.data.readAsBytes();
          final mimeType =
              lookupMimeType(file.data.name) ?? 'application/octet-stream';
          final part = DataPart(
            bytes,
            name: file.data.name,
            mimeType: mimeType,
          );
          onAttachments([part]);
        } catch (e) {
          debugPrint('Error handling dropped file: $e');
        }
      },
      onWillAcceptWithDetails: (_) => true,
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: candidateData.isNotEmpty
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
