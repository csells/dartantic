// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:universal_platform/universal_platform.dart';

import '../paste_helper/paste_extensions.dart';

final _formats = [
  ...Formats.standardFormats.whereType<FileFormat>(),
  Formats.epub,
  Formats.md,
  Formats.opus,
];

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
  ///
  /// Returns:
  ///   A [DropRegion] widget that handles file drops.
  Widget buildDropRegion({
    required Widget child,
    Set<DropOperation> allowedOperations = const {DropOperation.copy},
    HitTestBehavior hitTestBehavior = HitTestBehavior.deferToChild,
  }) {
    return DropRegion(
      formats: [Formats.fileUri, ..._formats],
      hitTestBehavior: hitTestBehavior,
      onDropOver: (event) {
        return allowedOperations.firstOrNull ?? DropOperation.copy;
      },
      onPerformDrop: (event) async {
        final items = event.session.items;
        final parts = <Part>[];
        final futures = <Future<void>>[];

        for (final item in items) {
          if (item.dataReader != null) {
            if (!UniversalPlatform.isWeb) {
              final completer = Completer<void>();
              item.dataReader!.getValue(Formats.fileUri, (val) async {
                if (val != null) {
                  final file = await _handleDroppedFile(val);
                  if (file != null) {
                    parts.add(file);
                  }
                }
                completer.complete();
              });
              futures.add(completer.future);
            } else {
              final completer = Completer<void>();
              bool handled = false;
              for (final format in _formats) {
                if (handled) break;
                if (item.dataReader!.canProvide(format)) {
                  handled = true;
                  item.dataReader!.getFile(format, (file) async {
                    try {
                      final stream = file.getStream();
                      final chunks = await stream.toList();
                      final attachmentBytes = Uint8List.fromList(
                        chunks.expand((e) => e).toList(),
                      );
                      final (mimeType, fileName) = _determineMimeAndFilename(
                        originalName: file.fileName,
                        bytes: attachmentBytes,
                      );
                      final dataPart = DataPart(
                        attachmentBytes,
                        mimeType: mimeType,
                        name: fileName,
                      );
                      parts.add(dataPart);
                    } catch (error, stackTrace) {
                      debugPrint('Error handling dropped file -> $error');
                      debugPrint('$stackTrace');
                    } finally {
                      completer.complete();
                    }
                  });
                }
              }
              if (handled) {
                futures.add(completer.future);
              } else {
                completer.complete();
              }
            }
          }
        }
        await Future.wait(futures).timeout(
          const Duration(seconds: 10),
          onTimeout: () async {
            debugPrint('Timeout waiting for file drop futures');
            return [];
          },
        );
        if (parts.isNotEmpty) {
          onAttachments(parts);
        }
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
      final (mimeType, fileName) = _determineMimeAndFilename(
        originalName: file.name,
        bytes: bytes,
      );

      return DataPart(bytes, name: fileName, mimeType: mimeType);
    } catch (e) {
      debugPrint('Error handling dropped file: $e');
      return null;
    }
  }

  /// Test-only wrapper to expose file drop handling for unit tests.
  @visibleForTesting
  Future<Part?> handleDroppedFile(Uri data) => _handleDroppedFile(data);

  (String mimeType, String fileName) _determineMimeAndFilename({
    required String? originalName,
    required Uint8List bytes,
  }) {
    String mimeType =
        lookupMimeType(originalName ?? '', headerBytes: bytes) ??
        'application/octet-stream';

    String fileName =
        originalName ?? 'pasted_file_${DateTime.now().millisecondsSinceEpoch}';

    // Handle markdown files
    if (originalName?.endsWith('.md') == true ||
        originalName?.endsWith('.markdown') == true) {
      mimeType = 'text/markdown';
      if (!fileName.endsWith('.md') && !fileName.endsWith('.markdown')) {
        fileName = '$fileName.md';
      }
    } else if (mimeType == 'application/octet-stream' &&
        originalName?.contains('.') == true) {
      // Try to get extension from original filename
      final extension = originalName!.substring(originalName.lastIndexOf('.'));
      final lastDotIndex = originalName.lastIndexOf('.');
      final baseName = lastDotIndex > 0
          ? fileName.substring(0, lastDotIndex)
          : fileName;
      fileName = '$baseName$extension';
    } else {
      final extension = getExtensionFromMime(mimeType);
      if (extension.isNotEmpty && !fileName.endsWith('.$extension')) {
        fileName = '$fileName.$extension';
      }
    }

    return (mimeType, fileName);
  }
}
