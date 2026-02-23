// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart'
    show TextEditingController, debugPrint, debugPrintStack;
import 'package:mime/mime.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:dartantic_interface/dartantic_interface.dart';

import 'paste_extensions.dart';

/// Handles paste operations, supporting both text and image pasting.
///
/// This function processes the clipboard contents and either:
/// - Extracts and handles image data if images are present in the clipboard
/// - Inserts plain text into the provided text controller if no images are found
///
/// On web, it delegates to [handlePasteWeb] for more comprehensive handling
/// of web-specific clipboard APIs.
///
/// Parameters:
///   - [controller]: The text editing controller to insert text into
///   - [onAttachments]: Callback that receives a list of attachments when images are pasted.
///     If null, image pasting will be skipped even if images are available.
///
/// Returns:
///   A [Future] that completes when the paste operation is finished
Future<void> handlePaste({
  required TextEditingController controller,
  required void Function(Iterable<Part> attachments)? onAttachments,
  required void Function({
    required TextEditingController controller,
    required String text,
  })
  insertText,
  ClipboardReader? readerOverride,
}) async {
  try {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null && readerOverride == null) return;
    final reader = readerOverride ?? await clipboard!.read();

    if (onAttachments != null) {
      final imageFormats = [
        Formats.png,
        Formats.jpeg,
        Formats.bmp,
        Formats.gif,
        Formats.tiff,
        Formats.webp,
        Formats.heic,
      ];

      final fileFormats = [
        Formats.pdf,
        Formats.doc,
        Formats.docx,
        Formats.xls,
        Formats.xlsx,
        Formats.ppt,
        Formats.pptx,
        Formats.epub,
        Formats.mp3,
        Formats.wav,
        Formats.mp4,
        Formats.mov,
        Formats.avi,
        Formats.zip,
        Formats.tar,
      ];

      if (reader.canProvide(Formats.fileUri)) {
        await reader.readValue(Formats.fileUri).then((val) async {
          if (val != null) {
            if (val.isScheme('file')) {
              final path = val.toFilePath();
              final file = XFile(path);
              final attachment = await file.readAsBytes();
              final mimeType =
                  lookupMimeType(file.path, headerBytes: attachment) ??
                  'application/octet-stream';
              onAttachments([
                DataPart(attachment, mimeType: mimeType, name: file.name),
              ]);
            }
          }
        });
        return;
      }

      for (final format in fileFormats) {
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
                  lookupMimeType('', headerBytes: attachmentBytes) ??
                  'image/png';
              final dataPart = DataPart(
                attachmentBytes,
                mimeType: mimeType,
                name:
                    'pasted_image_${DateTime.now().millisecondsSinceEpoch}.${getExtensionFromMime(mimeType)}',
              );
              onAttachments([dataPart]);
              return;
            });
          });
          return;
        }
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
  } catch (e, s) {
    debugPrint('Error pasting image: $e');
    debugPrintStack(stackTrace: s);
  }
}
