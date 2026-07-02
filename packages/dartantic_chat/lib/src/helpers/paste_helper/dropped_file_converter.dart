// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:mime/mime.dart';

import 'paste_extensions.dart';

/// Converts dropped file bytes into chat attachment parts.
class DroppedFileConverter {
  const DroppedFileConverter._();

  /// Creates a [DataPart] from dropped file bytes.
  static DataPart toDataPart({
    required Uint8List bytes,
    required String? originalName,
    String? browserMimeType,
  }) {
    final (mimeType, fileName) = determineMimeAndFilename(
      originalName: originalName,
      bytes: bytes,
      browserMimeType: browserMimeType,
    );

    return DataPart(bytes, name: fileName, mimeType: mimeType);
  }

  /// Determines a stable MIME type and file name for dropped data.
  static (String mimeType, String fileName) determineMimeAndFilename({
    required String? originalName,
    required Uint8List bytes,
    String? browserMimeType,
  }) {
    String mimeType = (browserMimeType?.isNotEmpty ?? false)
        ? browserMimeType!
        : lookupMimeType(originalName ?? '', headerBytes: bytes) ??
              'application/octet-stream';

    String fileName =
        originalName ?? 'pasted_file_${DateTime.now().millisecondsSinceEpoch}';

    if (originalName?.endsWith('.md') == true ||
        originalName?.endsWith('.markdown') == true) {
      mimeType = 'text/markdown';
      if (!fileName.endsWith('.md') && !fileName.endsWith('.markdown')) {
        fileName = '$fileName.md';
      }
    } else if (mimeType == 'application/octet-stream' &&
        originalName?.contains('.') == true) {
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
