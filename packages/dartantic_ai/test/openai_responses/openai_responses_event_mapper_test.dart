import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_ai/src/chat_models/openai_responses/openai_responses_event_mapper.dart';
import 'package:dartantic_ai/src/shared/openai_responses_metadata.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:test/test.dart';

// Mock download function for tests
Future<ContainerFileData> _mockDownloadContainerFile(
  String containerId,
  String fileId,
) async => ContainerFileData(
  bytes: Uint8List.fromList(const [1, 2, 3, 4]),
  fileName: '$fileId.bin',
);

void main() {
  group('OpenAIResponsesEventMapper', () {
    test('streams text deltas as chat results', () async {
      final mapper = OpenAIResponsesEventMapper(
        storeSession: true,
        downloadContainerFile: _mockDownloadContainerFile,
      );

      final results = await mapper
          .handle(
            const openai.OutputTextDeltaEvent(
              itemId: 'msg',
              outputIndex: 0,
              contentIndex: 0,
              delta: 'Hello',
              sequenceNumber: 1,
            ),
          )
          .toList();

      expect(results, hasLength(1));
      final chunk = results.single;
      expect(
        chunk.output.parts.single,
        isA<TextPart>().having((p) => p.text, 'text', 'Hello'),
      );
    });

    test(
      'builds final chat result with telemetry and session metadata',
      () async {
        final mapper = OpenAIResponsesEventMapper(
          storeSession: true,
          downloadContainerFile: _mockDownloadContainerFile,
        );

        final response = openai.Response(
          id: 'resp_123',
          object: 'response',
          createdAt: 0,
          model: 'gpt-4o',
          status: openai.ResponseStatus.completed,
          usage: const openai.ResponseUsage(
            inputTokens: 12,
            outputTokens: 34,
            totalTokens: 46,
          ),
          output: [
            const openai.MessageOutputItem(
              id: 'msg-1',
              role: openai.MessageRole.assistant,
              content: [
                openai.OutputTextContent(text: 'Hello!', annotations: []),
              ],
              status: openai.ItemStatus.completed,
            ),
            openai.FunctionCallOutputItemResponse(
              id: 'fc-1',
              callId: 'tool-1',
              name: 'fetchData',
              arguments: jsonEncode({'foo': 'bar'}),
            ),
            const openai.ReasoningItem(
              id: 'reason-1',
              summary: [openai.ReasoningSummaryContent(text: 'Thinking...')],
            ),
            const openai.CodeInterpreterCallOutputItem(
              id: 'ci-1',
              code: 'print(1)',
              status: openai.ItemStatus.completed,
            ),
            openai.ImageGenerationCallOutputItem(
              id: 'img-1',
              status: openai.ItemStatus.completed,
              result: base64Encode(utf8.encode('fake')), // any bytes
            ),
            const openai.WebSearchCallOutputItem(
              id: 'search-1',
              status: openai.ItemStatus.completed,
            ),
            const openai.FileSearchCallOutputItem(
              id: 'files-1',
              status: openai.ItemStatus.completed,
              queries: ['query'],
              results: [
                {'text': 'snippet', 'file_id': 'file-1'},
              ],
            ),
            const openai.McpCallOutputItem(
              id: 'mcp-1',
              callId: 'mcp-call-1',
              name: 'list',
              arguments: '{}',
              serverLabel: 'server-a',
              output: 'ok',
            ),
          ],
        );

        final results = await mapper
            .handle(
              openai.ResponseCompletedEvent(
                response: response,
                sequenceNumber: 10,
              ),
            )
            .toList();

        expect(results, hasLength(1));
        final result = results.single;

        expect(result.id, equals('resp_123'));
        expect(result.usage?.promptTokens, equals(12));
        expect(result.usage?.responseTokens, equals(34));

        final message = result.output;
        expect(
          message.parts.whereType<TextPart>().single.text,
          equals('Hello!'),
        );

        final callPart = message.parts.whereType<ToolPart>().firstWhere(
          (part) => part.kind == ToolPartKind.call,
        );
        expect(callPart.toolName, equals('fetchData'));

        final session = OpenAIResponsesMetadata.getSessionData(
          message.metadata,
        )!;
        expect(
          session[OpenAIResponsesMetadata.responseIdKey],
          equals('resp_123'),
        );

        // Message metadata should ONLY contain session info Tool events are not
        // duplicated on the message (only in streaming metadata)
        expect(
          message.metadata.keys.toSet(),
          equals({'_responses_session'}),
          reason: 'Message metadata should only contain session info',
        );

        expect(result.metadata['response_id'], equals('resp_123'));
        expect(result.metadata['status'], equals('completed'));
      },
    );

    test(
      'handles streaming image generation with ResponseOutputItemDone',
      () async {
        final mapper = OpenAIResponsesEventMapper(
          storeSession: false,
          downloadContainerFile: _mockDownloadContainerFile,
        );

        // Step 1: OutputItemAddedEvent with ImageGenerationCallOutputItem
        var results = await mapper
            .handle(
              const openai.OutputItemAddedEvent(
                outputIndex: 0,
                sequenceNumber: 1,
                item: openai.ImageGenerationCallOutputItem(
                  id: 'img-1',
                  status: openai.ItemStatus.inProgress,
                ),
              ),
            )
            .toList();
        expect(results, isEmpty); // No output yet

        // Step 2: ResponseImageGenerationCallInProgressEvent
        results = await mapper
            .handle(
              const openai.ResponseImageGenerationCallInProgressEvent(
                itemId: 'img-1',
                outputIndex: 0,
                sequenceNumber: 2,
              ),
            )
            .toList();
        expect(results, hasLength(1)); // Metadata chunk emitted
        expect(results.first.metadata['image_generation'], isNotNull);

        // Step 3: ResponseImageGenerationCallGeneratingEvent
        results = await mapper
            .handle(
              const openai.ResponseImageGenerationCallGeneratingEvent(
                itemId: 'img-1',
                outputIndex: 0,
                sequenceNumber: 3,
              ),
            )
            .toList();
        expect(results, hasLength(1)); // Metadata chunk emitted

        // Step 4: ResponseImageGenerationCallPartialImageEvent
        const fakeImageData =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC'
            '0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
        results = await mapper
            .handle(
              const openai.ResponseImageGenerationCallPartialImageEvent(
                itemId: 'img-1',
                outputIndex: 0,
                sequenceNumber: 4,
                partialImageB64: fakeImageData,
                partialImageIndex: 0,
              ),
            )
            .toList();
        expect(results, hasLength(1)); // Metadata chunk emitted

        // Step 5: OutputItemDoneEvent marks completion
        results = await mapper
            .handle(
              const openai.OutputItemDoneEvent(
                outputIndex: 0,
                sequenceNumber: 5,
                item: openai.ImageGenerationCallOutputItem(
                  id: 'img-1',
                  status: openai.ItemStatus.completed,
                  result: fakeImageData,
                ),
              ),
            )
            .toList();
        expect(results, isEmpty); // Just marks completion, no output yet

        // Step 6: ResponseCompletedEvent should include the image as a DataPart
        const response = openai.Response(
          id: 'resp_img',
          object: 'response',
          createdAt: 0,
          status: openai.ResponseStatus.completed,
          output: [
            openai.ImageGenerationCallOutputItem(
              id: 'img-1',
              status: openai.ItemStatus.completed,
              result: fakeImageData,
            ),
          ],
        );

        results = await mapper
            .handle(
              const openai.ResponseCompletedEvent(
                response: response,
                sequenceNumber: 6,
              ),
            )
            .toList();

        expect(results, hasLength(1));
        final finalResult = results.single;
        final message = finalResult.output;

        // Verify the image was added as a DataPart
        final dataParts = message.parts.whereType<DataPart>().toList();
        expect(dataParts, hasLength(1));
        expect(dataParts.first.mimeType, equals('image/png'));
        expect(dataParts.first.bytes, equals(base64Decode(fakeImageData)));
        expect(dataParts.first.name, equals('image_0.png'));
      },
    );

    test('handles multiple concurrent images at different indices', () async {
      const fakeImageData1 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC'
          '0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
      const fakeImageData2 =
          'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAE'
          'klEQVR4nGNgYGD4z8DAwMgAAAOGAgM9RdERAAAAAElFTkSuQmCC';

      final mapper = OpenAIResponsesEventMapper(
        storeSession: false,
        downloadContainerFile: _mockDownloadContainerFile,
      );

      // Image 1 at outputIndex 0
      await mapper
          .handle(
            const openai.OutputItemAddedEvent(
              outputIndex: 0,
              sequenceNumber: 1,
              item: openai.ImageGenerationCallOutputItem(
                id: 'img-1',
                status: openai.ItemStatus.inProgress,
              ),
            ),
          )
          .toList();

      await mapper
          .handle(
            const openai.ResponseImageGenerationCallPartialImageEvent(
              itemId: 'img-1',
              outputIndex: 0,
              sequenceNumber: 2,
              partialImageB64: fakeImageData1,
              partialImageIndex: 0,
            ),
          )
          .toList();

      // Image 2 at outputIndex 1 (different index!)
      await mapper
          .handle(
            const openai.OutputItemAddedEvent(
              outputIndex: 1,
              sequenceNumber: 3,
              item: openai.ImageGenerationCallOutputItem(
                id: 'img-2',
                status: openai.ItemStatus.inProgress,
              ),
            ),
          )
          .toList();

      await mapper
          .handle(
            const openai.ResponseImageGenerationCallPartialImageEvent(
              itemId: 'img-2',
              outputIndex: 1,
              sequenceNumber: 4,
              partialImageB64: fakeImageData2,
              partialImageIndex: 0,
            ),
          )
          .toList();

      // Complete both images
      await mapper
          .handle(
            const openai.OutputItemDoneEvent(
              outputIndex: 0,
              sequenceNumber: 5,
              item: openai.ImageGenerationCallOutputItem(
                id: 'img-1',
                status: openai.ItemStatus.completed,
                result: fakeImageData1,
              ),
            ),
          )
          .toList();

      await mapper
          .handle(
            const openai.OutputItemDoneEvent(
              outputIndex: 1,
              sequenceNumber: 6,
              item: openai.ImageGenerationCallOutputItem(
                id: 'img-2',
                status: openai.ItemStatus.completed,
                result: fakeImageData2,
              ),
            ),
          )
          .toList();

      // ResponseCompletedEvent with both images at indices 0 and 1
      const response = openai.Response(
        id: 'resp_multi',
        object: 'response',
        createdAt: 0,
        status: openai.ResponseStatus.completed,
        output: [
          openai.ImageGenerationCallOutputItem(
            id: 'img-1',
            status: openai.ItemStatus.completed,
            result: fakeImageData1,
          ),
          openai.ImageGenerationCallOutputItem(
            id: 'img-2',
            status: openai.ItemStatus.completed,
            result: fakeImageData2,
          ),
        ],
      );

      final results = await mapper
          .handle(
            const openai.ResponseCompletedEvent(
              response: response,
              sequenceNumber: 7,
            ),
          )
          .toList();

      expect(results, hasLength(1));
      final finalResult = results.single;
      final message = finalResult.output;

      // Verify BOTH images were added as DataParts (not just the last one!)
      final dataParts = message.parts.whereType<DataPart>().toList();
      expect(
        dataParts,
        hasLength(2),
        reason: 'Should have 2 images, not just the last one',
      );

      // Verify first image
      expect(dataParts[0].mimeType, equals('image/png'));
      expect(dataParts[0].bytes, equals(base64Decode(fakeImageData1)));
      expect(dataParts[0].name, equals('image_0.png'));

      // Verify second image
      expect(dataParts[1].mimeType, equals('image/png'));
      expect(dataParts[1].bytes, equals(base64Decode(fakeImageData2)));
      expect(dataParts[1].name, equals('image_1.png'));
    });
  });
}
