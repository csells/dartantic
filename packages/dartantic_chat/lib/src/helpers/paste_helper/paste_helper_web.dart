// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_chat/src/helpers/paste_helper/paste_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:mime/mime.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:dartantic_interface/dartantic_interface.dart';

bool _isListenerRegistered = false;
final _events = ClipboardEvents.instance;

/// Handles paste events in a web environment, supporting both text, file, and image pasting.
///
/// This function processes the clipboard contents, registers a paste event listener and either:
/// - Extracts and handles image data if images are present in the clipboard
/// - Inserts plain text into the provided text controller
///
/// Parameters:
///   - [controller]: The text editing controller to insert text into
///   - [onAttachments]: Callback that receives a list of attachments when images are pasted
///   - [insertText]: Function to handle text insertion, allowing for custom text processing
///
/// Returns:
///   A [Future] that completes when the paste operation is finished
Future<void> handlePasteWeb({
  required TextEditingController controller,
  required void Function(Iterable<Part> attachments)? onAttachments,
  required void Function({
    required TextEditingController controller,
    required String text,
  })
  insertText,
}) async {
  try {
    if (_isListenerRegistered) return;

    _isListenerRegistered = true;

    if (_events == null) return;

    _events!.registerPasteEventListener((event) async {
      final reader = await event.getClipboardReader();
      await pasteOperation(
        controller: controller,
        onAttachments: onAttachments,
        insertText: insertText,
        reader: reader,
      );
    });
  } catch (e, s) {
    debugPrint('Error in handlePasteWeb: $e');
    debugPrintStack(stackTrace: s);
  }
}

/// Internal function to handle the actual clipboard reading and data processing.
///
/// It checks for various data formats (files, images, plain text, HTML) in a specific order
/// and executes the appropriate action (calling [onAttachments] or [insertText]).
///
/// Parameters:
///   - [controller]: The text editing controller.
///   - [onAttachments]: Callback to handle file/image attachments.
///   - [insertText]: Function to handle text insertion.
///   - [reader]: The [ClipboardReader] containing the clipboard data.
@visibleForTesting
Future<void> pasteOperation({
  required TextEditingController controller,
  required void Function(Iterable<Part> attachments)? onAttachments,
  required void Function({
    required TextEditingController controller,
    required String text,
  })
  insertText,
  required ClipboardReader reader,
}) async {
  if (onAttachments != null) {
    final imageFormats = [
      Formats.png,
      Formats.jpeg,
      Formats.svg,
      Formats.bmp,
      Formats.gif,
      Formats.tiff,
      Formats.webp,
      Formats.heic,
    ];

    for (final format in Formats.standardFormats.whereType<FileFormat>()) {
      if (reader.canProvide(format)) {
        reader.getFile(format, (file) async {
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

    for (final format in imageFormats) {
      if (reader.canProvide(format)) {
        reader.getFile(format, (file) async {
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
                'image/png';
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

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        insertText(controller: controller, text: text);
        return;
      }
    }

    if (reader.canProvide(Formats.htmlText)) {
      final html = await reader.readValue(Formats.htmlText);
      if (html != null && html.isNotEmpty) {
        insertText(controller: controller, text: html);
        return;
      }
    }
  }
}

/// Unregisters the paste event listener established in [handlePasteWeb].
///
/// This is necessary to stop processing paste events when they are no longer needed
/// (e.g., when a widget is disposed).
void unregisterPasteListener() {
  if (_events != null) {
    _events!.unregisterPasteEventListener;
  }
}
