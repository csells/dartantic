// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:json_schema/json_schema.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  runApp(const App());
}

class App extends StatelessWidget {
  static const title = 'Example: Function Calls';

  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: title, home: ChatPage());
}

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: AgentChatView(
      provider: DartanticProvider(
        agent: Agent(
          'gemini?chat=gemini-2.0-flash',
          tools: [
            Tool<Map<String, dynamic>>(
              name: 'get_temperature',
              description: 'Get the current local temperature',
              onCall: (args) async => {'temperature': 0, 'unit': 'C'},
            ),
            Tool<Map<String, dynamic>>(
              name: 'get_time',
              description: 'Get the current local time',
              onCall:
                  (args) async => {
                    'time': DateTime(1970, 1, 1).toIso8601String(),
                  },
            ),
            Tool<Map<String, dynamic>>(
              name: 'c_to_f',
              description: 'Convert a temperature from Celsius to Fahrenheit',
              inputSchema: JsonSchema.create({
                'type': 'object',
                'properties': {
                  'temperature': {
                    'type': 'number',
                    'description': 'The temperature in Celsius',
                  },
                },
                'required': ['temperature'],
              }),
              onCall:
                  (args) async => {
                    'temperature':
                        (args['temperature'] as num).toDouble() * 1.8 + 32,
                  },
            ),
          ],
        ),
      ),
      suggestions: [
        'can you get the current time?',
        'can you get the current time and temp?',
        'can you get the current temp in Fahrenheit?',
      ],
      welcomeMessage: '''
Welcome to the function calls example!
This example includes three tools:
- current time: always returns 1970-01-01T00:00:00Z
- current temperature: always returns 0°C
- convert from Celsius to Fahrenheit

The hardcoded values are for demonstration purposes. Not only can you ask Gemini
to use these tools one at time, like:

_can you get the current time?_

but you can ask them in combination, like:

_can you get the current time and temp?_

you can even ask it to use the results of one function call in another, like:

_can you get the current temp in Fahrenheit?_
''',
    ),
  );
}
