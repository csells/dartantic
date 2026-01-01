import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';
// ignore: implementation_imports
import 'package:mime/src/default_extension_map.dart';
import 'package:path/path.dart' as p;

/// A message in a conversation between a user and a model.
@immutable
class ChatMessage {
  /// Creates a new message.
  const ChatMessage({
    required this.role,
    required this.parts,
    this.metadata = const {},
  });

  /// Creates a message from a JSON-compatible map.
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: ChatMessageRole.values.byName(json['role']),
    parts: (json['parts'] as List<dynamic>)
        .map((p) => Part.fromJson(p as Map<String, dynamic>))
        .toList(),
    metadata: json['metadata'] ?? const {},
  );

  /// Creates a system message.
  factory ChatMessage.system(
    String text, {
    List<Part> parts = const [],
    Map<String, dynamic>? metadata,
  }) => ChatMessage(
    role: ChatMessageRole.system,
    parts: [TextPart(text), ...parts],
    metadata: metadata ?? const {},
  );

  /// Creates a user message with text.
  factory ChatMessage.user(
    String text, {
    List<Part> parts = const [],
    Map<String, dynamic>? metadata,
  }) => ChatMessage(
    role: ChatMessageRole.user,
    parts: [TextPart(text), ...parts],
    metadata: metadata ?? const {},
  );

  /// Creates a model message with text.
  factory ChatMessage.model(
    String text, {
    List<Part> parts = const [],
    Map<String, dynamic>? metadata,
  }) => ChatMessage(
    role: ChatMessageRole.model,
    parts: [TextPart(text), ...parts],
    metadata: metadata ?? const {},
  );

  /// The role of the message author.
  final ChatMessageRole role;

  /// The content parts of the message.
  final List<Part> parts;

  /// Optional metadata associated with this message.
  /// Can include information like suppressed content, warnings, etc.
  final Map<String, dynamic> metadata;

  /// Gets the text content of the message by concatenating all text parts.
  String get text => parts.whereType<TextPart>().map((p) => p.text).join();

  /// Checks if this message contains any tool calls.
  bool get hasToolCalls =>
      parts.whereType<ToolPart>().any((p) => p.kind == ToolPartKind.call);

  /// Gets all tool calls in this message.
  List<ToolPart> get toolCalls => parts
      .whereType<ToolPart>()
      .where((p) => p.kind == ToolPartKind.call)
      .toList();

  /// Checks if this message contains any tool results.
  bool get hasToolResults =>
      parts.whereType<ToolPart>().any((p) => p.kind == ToolPartKind.result);

  /// Gets all tool results in this message.
  List<ToolPart> get toolResults => parts
      .whereType<ToolPart>()
      .where((p) => p.kind == ToolPartKind.result)
      .toList();

  /// Converts the message to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'role': role.name,
    'parts': parts.map((p) => p.toJson()).toList(),
    'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          _listEquals(parts, other.parts) &&
          _mapEquals(metadata, other.metadata);

  @override
  int get hashCode => role.hashCode ^ parts.hashCode ^ metadata.hashCode;

  @override
  String toString() =>
      'Message(role: $role, parts: $parts, metadata: $metadata)';
}

/// The role of a message author.
enum ChatMessageRole {
  /// A message from the system that sets context or instructions.
  system,

  /// A message from the end user.
  user,

  /// A message from the model.
  model,
}

/// Base class for message content parts.
@immutable
abstract class Part {
  /// Creates a new part.
  const Part();

  /// Creates a part from a JSON-compatible map.
  factory Part.fromJson(Map<String, dynamic> json) => switch (json['type']) {
    'TextPart' => TextPart(json['content'] as String),
    'DataPart' => () {
      final content = json['content'] as Map<String, dynamic>;
      final dataUri = content['bytes'] as String;
      final uri = Uri.parse(dataUri);
      return DataPart(
        uri.data!.contentAsBytes(),
        mimeType: content['mimeType'] as String,
        name: content['name'] as String?,
      );
    }(),
    'LinkPart' => () {
      final content = json['content'] as Map<String, dynamic>;
      return LinkPart(
        Uri.parse(content['url'] as String),
        mimeType: content['mimeType'] as String?,
        name: content['name'] as String?,
      );
    }(),
    'ToolPart' => () {
      final content = json['content'] as Map<String, dynamic>;
      // Check if it's a call or result based on presence of arguments or result
      if (content.containsKey('arguments')) {
        return ToolPart.call(
          id: content['id'] as String,
          name: content['name'] as String,
          arguments: content['arguments'] as Map<String, dynamic>? ?? {},
        );
      } else {
        return ToolPart.result(
          id: content['id'] as String,
          name: content['name'] as String,
          result: content['result'],
        );
      }
    }(),
    _ => throw UnimplementedError('Unknown part type: ${json['type']}'),
  };

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

  /// Converts the part to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'type': runtimeType.toString(),
    'content': switch (this) {
      TextPart(text: final text) => text,
      DataPart(
        bytes: final bytes,
        mimeType: final mimeType,
        name: final name,
      ) =>
        {
          if (name != null) 'name': name,
          'mimeType': mimeType,
          'bytes': 'data:$mimeType;base64,${base64Encode(bytes)}',
        },
      LinkPart(url: final url, mimeType: final mimeType, name: final name) => {
        if (name != null) 'name': name,
        if (mimeType != null) 'mimeType': mimeType,
        'url': url.toString(),
      },
      ToolPart(
        id: final id,
        name: final name,
        arguments: final arguments,
        result: final result,
      ) =>
        {
          'id': id,
          'name': name,
          if (arguments != null) 'arguments': arguments,
          if (result != null) 'result': result,
        },
      _ => throw UnimplementedError('Unknown part type: $runtimeType'),
    },
  };
}

/// A text part of a message.
@immutable
class TextPart extends Part {
  /// Creates a new text part.
  const TextPart(this.text);

  /// The text content.
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextPart &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextPart($text)';
}

/// A data part containing binary data (e.g., images).
@immutable
class DataPart extends Part {
  /// Creates a new data part.
  DataPart(this.bytes, {required this.mimeType, String? name})
    : name = name ?? Part.nameFromMimeType(mimeType);

  /// Creates a data part from an [XFile].
  static Future<DataPart> fromFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = _nameFromPath(file.path) ?? _emptyNull(file.name);
    final mimeType =
        _emptyNull(file.mimeType) ??
        Part.mimeType(
          name ?? '',
          headerBytes: Uint8List.fromList(
            bytes.take(defaultMagicNumbersMaxLength).toList(),
          ),
        );

    return DataPart(bytes, mimeType: mimeType, name: name);
  }

  static String? _nameFromPath(String? path) {
    if (path == null || path.isEmpty) return null;
    final url = Uri.tryParse(path);
    if (url == null) return p.basename(path);
    final segments = url.pathSegments;
    if (segments.isEmpty) return null;
    return segments.last;
  }

  static String? _emptyNull(String? value) =>
      value == null || value.isEmpty ? null : value;

  /// The binary data.
  final Uint8List bytes;

  /// The MIME type of the data.
  final String mimeType;

  /// Optional name for the data.
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataPart &&
          runtimeType == other.runtimeType &&
          _listEquals(bytes, other.bytes) &&
          mimeType == other.mimeType &&
          name == other.name;

  @override
  int get hashCode => bytes.hashCode ^ mimeType.hashCode ^ name.hashCode;

  @override
  String toString() =>
      'DataPart(mimeType: $mimeType, name: $name, bytes: ${bytes.length})';
}

/// A link part referencing external content.
@immutable
class LinkPart extends Part {
  /// Creates a new link part.
  const LinkPart(this.url, {this.mimeType, this.name});

  /// The URL of the external content.
  final Uri url;

  /// Optional MIME type of the linked content.
  final String? mimeType;

  /// Optional name for the link.
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkPart &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          mimeType == other.mimeType &&
          name == other.name;

  @override
  int get hashCode => url.hashCode ^ mimeType.hashCode ^ name.hashCode;

  @override
  String toString() => 'LinkPart(url: $url, mimeType: $mimeType, name: $name)';
}

/// A tool interaction part of a message.
@immutable
class ToolPart extends Part {
  /// Creates a tool call part.
  const ToolPart.call({
    required this.id,
    required this.name,
    required this.arguments,
    this.thoughtSignature,
  }) : kind = ToolPartKind.call,
       result = null;

  /// Creates a tool result part.
  const ToolPart.result({
    required this.id,
    required this.name,
    required this.result,
    this.thoughtSignature,
  }) : kind = ToolPartKind.result,
       arguments = null;

  /// The kind of tool interaction.
  final ToolPartKind kind;

  /// The unique identifier for this tool interaction.
  final String id;

  /// The name of the tool.
  final String name;

  /// The arguments for a tool call (null for results).
  final Map<String, dynamic>? arguments;

  /// The result of a tool execution (null for calls).
  final dynamic result;

  /// The thought signature for the tool call.
  final dynamic thoughtSignature;

  /// The arguments as a JSON string.
  String get argumentsRaw => arguments != null
      ? (arguments!.isEmpty ? '{}' : _jsonEncode(arguments))
      : '';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolPart &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          id == other.id &&
          name == other.name &&
          _mapEquals(arguments, other.arguments) &&
          result == other.result &&
          thoughtSignature == other.thoughtSignature;

  @override
  int get hashCode =>
      kind.hashCode ^
      id.hashCode ^
      name.hashCode ^
      arguments.hashCode ^
      result.hashCode ^
      thoughtSignature.hashCode;

  @override
  String toString() {
    if (kind == ToolPartKind.call) {
      return 'ToolPart.call(id: $id, name: $name, arguments: $arguments, '
          'thoughtSignature: $thoughtSignature)';
    } else {
      return 'ToolPart.result(id: $id, name: $name, result: $result, '
          'thoughtSignature: $thoughtSignature)';
    }
  }
}

/// The kind of tool interaction.
enum ToolPartKind {
  /// A request to call a tool.
  call,

  /// The result of a tool execution.
  result,
}

// Helper functions for equality checks
bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

String _jsonEncode(dynamic object) {
  // Simple JSON encoding for common cases
  if (object == null) return 'null';
  if (object is String) return '"${object.replaceAll('"', r'\"')}"';
  if (object is num || object is bool) return object.toString();
  if (object is List) {
    final items = object.map(_jsonEncode).join(',');
    return '[$items]';
  }
  if (object is Map) {
    final entries = object.entries
        .map((e) => '"${e.key}":${_jsonEncode(e.value)}')
        .join(',');
    return '{$entries}';
  }
  return object.toString();
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
