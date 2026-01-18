@Tags(['e2e'])
library;

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    stdout.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  group('Anthropic Media Generation E2E', () {
    late AnthropicProvider provider;
    late MediaGenerationModel model;

    setUp(() {
      provider = AnthropicProvider();
      model = provider.createMediaModel();
    });

    test('generates an image', () async {
      final stream = model.generateMediaStream(
        'Create a simple logo image: a blue circle with the text "AI" '
        'in white',
        mimeTypes: ['image/png'],
      );

      final results = await stream.toList();
      final imageData = _findFirstImageDataPart(results);
      expect(imageData, isNotNull, reason: 'Expected a DataPart with image/*');
      expect(imageData!.bytes, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test(
      'edits an image with attachment',
      () async {
        // Load test image
        const testImagePath = 'test/files/robot_bw.png';
        final imageBytes = await File(testImagePath).readAsBytes();
        final imagePart = DataPart(imageBytes, mimeType: 'image/png');

        final stream = model.generateMediaStream(
          'Colorize this black and white robot drawing. '
          'Make the robot body blue and the eyes green. '
          'Use PIL/Pillow to preserve all the original black lines.',
          mimeTypes: ['image/png'],
          attachments: [imagePart],
        );

        final results = await stream.toList();
        final imageData = _findFirstImageDataPart(results);
        expect(imageData, isNotNull, reason: 'Expected a DataPart with image/*');
        expect(imageData!.bytes, isNotEmpty);
        // Verify the output is different from input (was edited)
        expect(imageData.bytes, isNot(equals(imageBytes)));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'generates media with multiple attachment types',
      () async {
        // Load test image
        const testImagePath = 'test/files/robot_bw.png';
        final imageBytes = await File(testImagePath).readAsBytes();
        final imagePart = DataPart(imageBytes, mimeType: 'image/png');

        // Add a text part as well
        const textPart = TextPart('Additional context for generation');

        final stream = model.generateMediaStream(
          'Create a colorful variation of this robot as a PNG image',
          mimeTypes: ['image/png'],
          attachments: [imagePart, textPart],
        );

        final results = await stream.toList();
        final imageData = _findFirstImageDataPart(results);
        expect(imageData, isNotNull, reason: 'Expected a DataPart with image/*');
        expect(imageData!.bytes, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

/// Finds the first DataPart with an image/* MIME type from all results.
DataPart? _findFirstImageDataPart(List<MediaGenerationResult> results) {
  for (final result in results) {
    for (final asset in result.assets) {
      if (asset is DataPart && asset.mimeType.startsWith('image/')) {
        return asset;
      }
    }
  }
  return null;
}
