import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    stdout.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  const defaultImageModel = 'grok-imagine-image';
  const defaultVideoModel = 'grok-imagine-video';

  // Run manually with:
  // XAI_API_KEY=your_key \
  // XAI_MEDIA_TEST_MODEL=grok-imagine-image \
  // dart test test/xai_media_gen_e2e_test.dart
  //
  // Video model override:
  // XAI_MEDIA_VIDEO_TEST_MODEL=grok-imagine-video
  final hasXaiKey = (Platform.environment['XAI_API_KEY'] ?? '')
      .trim()
      .isNotEmpty;
  final imageModelName =
      (Platform.environment['XAI_MEDIA_TEST_MODEL'] ?? defaultImageModel)
          .trim();
  final videoModel =
      (Platform.environment['XAI_MEDIA_VIDEO_TEST_MODEL'] ?? defaultVideoModel)
          .trim();

  group('xAI Media Generation E2E', () {
    late XAIResponsesProvider provider;

    setUp(() {
      final apiKey = Platform.environment['XAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw StateError('XAI_API_KEY environment variable not set');
      }
      provider = XAIResponsesProvider(apiKey: apiKey);
    });

    test(
      'generates an image asset or link',
      () async {
        final mimeTypes = ['image/png'];
        final imageModel = provider.createMediaModel(
          name: imageModelName,
          options: XAIResponsesMediaGenerationModelOptions(
            mimeTypes: mimeTypes,
          ),
        );
        final stream = imageModel.generateMediaStream(
          'Generate a simple flat illustration of a blue robot mascot.',
          mimeTypes: ['image/png'],
        );

        final results = await stream.toList();
        expect(results, isNotEmpty);

        final result = results.firstWhere(
          (r) => r.assets.isNotEmpty || r.links.isNotEmpty,
          orElse: () => fail('No media asset/link generated'),
        );

        expect(
          result.assets.isNotEmpty || result.links.isNotEmpty,
          isTrue,
          reason: 'Expected generated media output from xAI Responses.',
        );
      },
      skip: hasXaiKey ? false : 'Requires XAI_API_KEY',
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'edits image with attachment',
      () async {
        const testImagePath = 'test/files/robot_bw.png';
        final imageBytes = await File(testImagePath).readAsBytes();
        final imagePart = DataPart(imageBytes, mimeType: 'image/png');
        final mimeTypes = ['image/png'];
        final imageModel = provider.createMediaModel(
          name: imageModelName,
          options: XAIResponsesMediaGenerationModelOptions(
            mimeTypes: mimeTypes,
          ),
        );
        final stream = imageModel.generateMediaStream(
          'Colorize this robot. Keep outlines black, make body blue, '
          'eyes green.',
          mimeTypes: mimeTypes,
          attachments: [imagePart],
        );

        final results = await stream.toList();
        expect(results, isNotEmpty);

        final dataImage = _findFirstImageDataPart(results);
        final imageLink = _findFirstImageLinkPart(results);
        expect(
          dataImage != null || imageLink != null,
          isTrue,
          reason: 'Expected edited image output as DataPart or LinkPart',
        );
        if (dataImage != null) {
          expect(dataImage.bytes, isNotEmpty);
          // If bytes are returned directly, ensure output differs from input.
          expect(dataImage.bytes, isNot(equals(imageBytes)));
        }
      },
      skip: hasXaiKey ? false : 'Requires XAI_API_KEY',
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'generates video with default or configured model',
      () async {
        final videoProvider = XAIResponsesProvider(
          apiKey: Platform.environment['XAI_API_KEY'],
        );
        final mimeTypes = ['video/mp4'];
        final videoMediaModel = videoProvider.createMediaModel(
          name: videoModel,
          options: XAIResponsesMediaGenerationModelOptions(
            mimeTypes: mimeTypes,
          ),
        );

        final stream = videoMediaModel.generateMediaStream(
          'Create a 1 second looping animation of a rotating neon cube.',
          mimeTypes: mimeTypes,
          options: const XAIResponsesMediaGenerationModelOptions(
            n: 1,
            durationSeconds: 1,
            pollIntervalSeconds: 5,
            pollTimeoutSeconds: 480,
          ),
        );
        final results = await stream.toList();
        expect(results, isNotEmpty);
        expect(results.last.isComplete, isTrue);
        final hasOutput = results.any(
          (r) => r.assets.isNotEmpty || r.links.isNotEmpty,
        );
        expect(hasOutput, isTrue, reason: 'Expected a video asset or link');
        final pendingCount = results
            .where((r) => r.metadata['status'] == 'pending')
            .length;
        if (results.length > 1) {
          expect(
            pendingCount,
            greaterThan(0),
            reason: 'Video polling should emit pending status chunks.',
          );
        }
      },
      skip: !hasXaiKey ? 'Requires XAI_API_KEY' : false,
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}

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

LinkPart? _findFirstImageLinkPart(List<MediaGenerationResult> results) {
  for (final result in results) {
    for (final link in result.links) {
      if ((link.mimeType ?? '').startsWith('image/')) {
        return link;
      }
    }
  }
  return null;
}
