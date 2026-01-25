import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:mime/mime.dart';

/// Result of parsing an output schema.
class SchemaParseResult {
  SchemaParseResult({this.schema, this.error});

  final Schema? schema;
  final String? error;
}

/// Parse output schema from string (inline JSON or @file reference).
Future<SchemaParseResult> parseOutputSchema(String schemaStr) async {
  String jsonStr;

  // Check if it's a file reference
  if (schemaStr.startsWith('@')) {
    final filePath = schemaStr.substring(1);
    final file = File(filePath);
    if (!await file.exists()) {
      return SchemaParseResult(error: 'Schema file not found: $filePath');
    }
    jsonStr = await file.readAsString();
  } else {
    jsonStr = schemaStr;
  }

  // Parse the JSON
  final schemaMap = jsonDecode(jsonStr) as Map<String, dynamic>;
  return SchemaParseResult(schema: Schema.fromMap(schemaMap));
}

/// Generate a filename based on MIME type.
String generateFilename(String mimeType) {
  // Override text/plain to use .txt (mime package returns 'text')
  final ext = mimeType == 'text/plain'
      ? 'txt'
      : extensionFromMime(mimeType) ?? 'bin';
  return 'generated_${DateTime.now().millisecondsSinceEpoch}.$ext';
}
