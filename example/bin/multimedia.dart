// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';

// final agent = Agent('openai:gpt-4.1-mini');
final agent = Agent('google');

void main() async {
  await textFile();

  try {
    await imageFileLink();
  } on Exception catch (e) {
    print('Error: $e');
    if (agent.model.startsWith('google')) {
      print(
        'The google provider likes LinkPart.uri to refer to a file uploaded to '
        'the Google AI File Service API.',
      );
    }
  }

  await imageFileData();
  exit(0);
}

Future<void> textFile() async {
  print('\n# Text File');

  await _writeStream(
    agent.runStream(
      'Can you summarized the attached file?',
      attachments: [await DataPart.file(File('bin/files/bio.txt'))],
    ),
  );
}

Future<void> imageFileLink() async {
  print('\n# Image File Link');

  final boardwalk = Uri.parse(
    'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-Gfp-wisconsin-madison-the-nature-boardwalk.jpg',
  );

  await _writeStream(
    agent.runStream(
      'Can you describe this image?',
      attachments: [LinkPart(boardwalk)],
    ),
  );
}

Future<void> imageFileData() async {
  print('\n# Image File Data');

  await _writeStream(
    agent.runStream(
      'What food do I have on hand?',
      attachments: [await DataPart.file(File('bin/files/cupboard.jpg'))],
    ),
  );
}

Future<void> _writeStream(Stream<AgentResponse> stream) async {
  await stream.map((r) => stdout.write(r.output)).drain();
  stdout.writeln();
}
