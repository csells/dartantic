import 'dart:typed_data';

import 'package:genai_primitives/genai_primitives.dart';
import 'package:mime/mime.dart';
// ignore: implementation_imports
import 'package:mime/src/default_extension_map.dart';

// Re-export types from genai_primitives
export 'package:genai_primitives/genai_primitives.dart'
    show
        ChatMessage,
        ChatMessageRole,
        DataPart,
        LinkPart,
        StandardPart,
        TextPart,
        ThinkingPart,
        ToolPart,
        ToolPartKind;

/// Alias for [StandardPart] for API convenience.
///
/// **For most dartantic users**: Use `Part` as before - it works identically.
///
/// **For custom part types**: Import genai_primitives directly to extend
/// the base `Part` class:
/// ```dart
/// import 'package:genai_primitives/genai_primitives.dart' as gaip;
/// class MyCustomPart extends gaip.Part { ... }
/// ```
typedef Part = StandardPart;

/// Helper utilities for Part-related operations.
///
/// Provides MIME type detection and file extension mapping for [DataPart].
class PartHelpers {
  PartHelpers._();

  /// The default MIME type for binary data.
  static const defaultMimeType = 'application/octet-stream';

  /// Gets the MIME type for a file.
  static String mimeType(String path, {Uint8List? headerBytes}) =>
      lookupMimeType(path, headerBytes: headerBytes) ?? defaultMimeType;

  /// Gets the name for a MIME type.
  static String nameFromMimeType(String mimeType) {
    final ext = extensionFromMimeType(mimeType) ?? '.bin';
    return mimeType.startsWith('image/') ? 'image.$ext' : 'file.$ext';
  }

  /// Gets the extension for a MIME type.
  static String? extensionFromMimeType(String mimeType) {
    final ext = defaultExtensionMap.entries
        .firstWhere(
          (e) => e.value == mimeType,
          orElse: () => const MapEntry('', ''),
        )
        .key;
    return ext.isNotEmpty ? ext : null;
  }
}

/// Static helper methods for extracting specific types of parts from a list.
extension MessagePartHelpers on Iterable<Part> {
  /// Extracts and concatenates all text content from TextPart instances.
  ///
  /// Returns a single string with all text content concatenated together
  /// without any separators. Empty text parts are included in the result.
  String get text => whereType<TextPart>().map((p) => p.text).join();

  /// Extracts all tool call parts from the list.
  ///
  /// Returns only ToolPart instances where kind == ToolPartKind.call.
  List<ToolPart> get toolCalls =>
      whereType<ToolPart>().where((p) => p.kind == ToolPartKind.call).toList();

  /// Extracts all tool result parts from the list.
  ///
  /// Returns only ToolPart instances where kind == ToolPartKind.result.
  List<ToolPart> get toolResults => whereType<ToolPart>()
      .where((p) => p.kind == ToolPartKind.result)
      .toList();
}
