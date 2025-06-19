// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Multimedia Input', () {
    final imageFile = File('test/files/pikachu.webp');

    for (final provider in allProviders) {
      group('Provider: ${provider.handle}', () {
        late Agent agent;

        setUp(() {
          agent = Agent.provider(provider);
        });

        test('should process text file via DataPart.file()', () async {
          // Create a temporary text file for testing
          final tempFile = File('test_bio.txt');
          await tempFile.writeAsString('''
Chris Sells is a software engineer and author who has worked at Microsoft, 
Google, and other technology companies. He is known for his work on Windows 
development technologies and has written several books about programming.
''');

          try {
            final response = await agent.run(
              "Can you summarize this person's background in one sentence?",
              attachments: [await DataPart.file(tempFile)],
            );

            expect(response.output, isNotEmpty);
            expect(
              response.output.toLowerCase(),
              anyOf([
                contains('chris sells'),
                contains('software engineer'),
                contains('author'),
                contains('microsoft'),
                contains('google'),
              ]),
            );
            expect(response.messages, isNotEmpty);
          } finally {
            // Clean up temporary file
            if (tempFile.existsSync()) await tempFile.delete();
          }
        });

        test('should process image file via DataPart.file()', () async {
          final response = await agent.run(
            'What do you see in this image? Describe it briefly.',
            attachments: [await DataPart.file(imageFile)],
          );

          expect(response.output, isNotEmpty);
          // Should contain some description of the image content
          expect(response.output.length, greaterThan(10));
          expect(response.messages, isNotEmpty);
        });

        test(
          'should process web image via LinkPart() for compatible providers',
          () async {
            final imageUrl = Uri.parse(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/'
              'Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-'
              'Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
            );

            try {
              final response = await agent.run(
                'Describe what you see in this image.',
                attachments: [LinkPart(imageUrl)],
              );

              expect(response.output, isNotEmpty);
              expect(response.output.length, greaterThan(10));
              expect(response.messages, isNotEmpty);
            } on Exception catch (e) {
              // Some providers (like Gemini) may not support arbitrary web URLs
              // and prefer files uploaded to their file service
              if (provider.name == 'google') {
                // This is expected for Gemini - skip the test
                markTestSkipped(
                  'Provider ${provider.name} does not support arbitrary web '
                  'URLs: $e',
                );
              } else {
                // For other providers, this should work, so re-throw
                rethrow;
              }
            }
          },
        );

        test('should handle multiple attachments', () async {
          // Create a temporary text file for testing
          final tempFile = File('test_multi.txt');
          await tempFile.writeAsString('This is a test document.');

          try {
            final response = await agent.run(
              'I have attached a text file and an image. '
              'Can you acknowledge both attachments?',
              attachments: [
                await DataPart.file(tempFile),
                await DataPart.file(imageFile),
              ],
            );

            expect(response.output, isNotEmpty);
            expect(response.output.length, greaterThan(10));
            expect(response.messages, isNotEmpty);
          } finally {
            // Clean up temporary file
            if (tempFile.existsSync()) {
              await tempFile.delete();
            }
          }
        });

        test('should work with streaming and attachments', () async {
          // Create a temporary text file for testing
          final tempFile = File('test_stream.txt');
          await tempFile.writeAsString('''
The quick brown fox jumps over the lazy dog. This sentence contains 
every letter in the English alphabet and is commonly used for testing.
''');

          try {
            final chunks = <String>[];
            var messageHistory = <Message>[];

            await for (final response in agent.runStream(
              'Please count the words in this text file.',
              attachments: [await DataPart.file(tempFile)],
            )) {
              chunks.add(response.output);
              messageHistory = response.messages;
            }

            final fullOutput = chunks.join();
            expect(fullOutput, isNotEmpty);
            expect(messageHistory, isNotEmpty);

            // Should contain some numerical information about word count
            expect(
              fullOutput.toLowerCase(),
              anyOf([
                contains('word'),
                contains('count'),
                contains('sentence'),
                matches(RegExp(r'\d+')), // Contains numbers
              ]),
            );
          } finally {
            // Clean up temporary file
            if (tempFile.existsSync()) {
              await tempFile.delete();
            }
          }
        });

        test('should maintain message history with attachments', () async {
          // Create a temporary text file for testing
          final tempFile = File('test_history.txt');
          await tempFile.writeAsString('My favorite color is blue.');

          try {
            // First message with attachment
            final response1 = await agent.run(
              'What is mentioned in this file?',
              attachments: [await DataPart.file(tempFile)],
            );

            expect(response1.output, isNotEmpty);
            expect(response1.messages, isNotEmpty);

            // Second message without attachment, but with history
            final response2 = await agent.run(
              'What color was mentioned?',
              messages: response1.messages,
            );

            expect(response2.output, isNotEmpty);
            expect(response2.output.toLowerCase(), contains('blue'));
            expect(
              response2.messages.length,
              greaterThan(response1.messages.length),
            );
          } finally {
            // Clean up temporary file
            if (tempFile.existsSync()) {
              await tempFile.delete();
            }
          }
        });
      });
    }
  });

  group('Multimedia Error Handling', () {
    test('should handle non-existent file gracefully', () async {
      final nonExistentFile = File('definitely_does_not_exist.txt');

      await expectLater(
        () async => DataPart.file(nonExistentFile),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('should handle invalid URL gracefully', () async {
      final invalidUrl = Uri.parse(
        'https://invalid-domain-that-does-not-exist.com/image.jpg',
      );

      // This should not throw during construction
      final linkPart = LinkPart(invalidUrl);
      expect(linkPart.url, equals(invalidUrl));

      // The actual failure would happen during the API call,
      // but that's provider-dependent behavior
    });
  });
}
