import 'dart:io';
import 'dart:typed_data';

import 'package:dartantic_chat/src/helpers/paste_helper/drag_and_drop_handler.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DragAndDropHandler.handleDroppedFile', () {
    test('returns DataPart for a plain text file', () async {
      final tempDir = await Directory.systemTemp.createTemp('dd_test_text_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final file = File('${tempDir.path}/sample.txt');
      final contents = 'hello world';
      await file.writeAsString(contents);

      final handler = DragAndDropHandler(onAttachments: (_) {});
      final part = await handler.handleDroppedFile(Uri.file(file.path));

      expect(part, isNotNull);
      expect(part, isA<DataPart>());

      final dataPart = part as DataPart;
      expect(String.fromCharCodes(dataPart.bytes), contents);
      expect(dataPart.mimeType, contains('text'));
      // Generated name should be non-empty and contain an extension.
      expect(dataPart.name, isNotNull);
      expect(dataPart.name!, contains('.'));

      await file.delete();
      await tempDir.delete();
    });

    test(
      'returns DataPart for a small PNG file and has matching extension',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('dd_test_img_');
        addTearDown(() async {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });
        final filePath = '${tempDir.path}/img.png';
        final file = File(filePath);

        // Minimal PNG header plus some payload bytes so mime detection works.
        final pngHeader = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        final payload = List<int>.generate(16, (i) => i);
        final bytes = Uint8List.fromList([...pngHeader, ...payload]);
        await file.writeAsBytes(bytes);

        final handler = DragAndDropHandler(onAttachments: (_) {});
        final part = await handler.handleDroppedFile(Uri.file(file.path));

        expect(part, isNotNull);
        expect(part, isA<DataPart>());

        final dataPart = part as DataPart;
        expect(dataPart.bytes, bytes);
        expect(dataPart.mimeType, contains('image'));

        // Derive expected extension from mimeType (e.g. 'image/png' -> 'png')
        final mime = dataPart.mimeType;
        final expectedExt = mime.split('/').last;
        expect(dataPart.name, isNotNull);
        expect(dataPart.name!.toLowerCase(), endsWith('.$expectedExt'));
      },
    );

    test('returns null for nonexistent file', () async {
      final handler = DragAndDropHandler(onAttachments: (_) {});
      final part = await handler.handleDroppedFile(
        Uri.file(
          '/this/path/should/not/exist_${DateTime.now().millisecondsSinceEpoch}.xyz',
        ),
      );
      expect(part, isNull);
    });
  });
}
