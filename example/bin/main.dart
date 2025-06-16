// ignore_for_file: avoid_print, unreachable_from_main

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dotprompt_dart/dotprompt_dart.dart';
import 'package:example/temp_tool_call.dart';
import 'package:example/time_tool_call.dart';
import 'package:example/town_and_country.dart';

void main() async {
  await helloWorldExample();
  await outputTypeExampleWithJsonSchemaAndStringOutput();
  await outputTypeExampleWithJsonSchemaAndOutjectOutput();
  await outputTypeExampleWithSotiSchema();
  await toolExample();
  await toolExampleWithTypedOutput();
  await dotPromptExample();
  await multiTurnChatExample();
  await providerSwitchingExample();
  await embeddingExample();
  exit(0);
}

Future<void> helloWorldExample() async {
  print('\nhelloWorldExample');

  final agent = Agent(
    'openai',
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  final response = await agent.run('Where does "hello world" come from?');
  print(response.output);
}

Future<void> outputTypeExampleWithJsonSchemaAndStringOutput() async {
  print('\noutputTypeExampleWithJsonSchemaAndStringOutput');

  final tncSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  final agent = Agent('openai', outputSchema: tncSchema.toSchema());
  await agent
      .runStream('The windy city in the US of A.')
      .map((result) => stdout.write(result.output))
      .drain();
  print('');
}

Future<void> outputTypeExampleWithJsonSchemaAndOutjectOutput() async {
  print('\noutputTypeExampleWithJsonSchemaAndOutjectOutput');

  final tncSchema = <String, dynamic>{
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  final agent = Agent(
    'openai',
    outputSchema: tncSchema.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );

  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );

  print(result.output);
}

Future<void> outputTypeExampleWithSotiSchema() async {
  print('\noutputTypeExampleWithSotiSchema');

  final agent = Agent(
    'openai',
    outputSchema: TownAndCountry.schemaMap.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );
  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );
  print(result.output);
}

Future<void> toolExample() async {
  print('\ntoolExample');

  final agent = Agent(
    'openai',
    systemPrompt:
        'Be sure to include the name of the location in your response. Show '
        'the time as local time. Do not ask any follow up questions.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputSchema: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  await agent
      .runStream('What is the time and temperature in New York City?')
      .map((event) => stdout.write(event.output))
      .drain();
  print('');
}

// NOTE: can the Agent handle tools+typed output itself even if the underlying
// models don't support it?
Future<void> toolExampleWithTypedOutput() async {
  print('\ntoolExampleWithTypedOutput');

  final agent = Agent(
    'openai',
    systemPrompt:
        'Be sure to include the name of the location in your response. '
        'Show all dates and times in ISO 8601 format.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
      Tool(
        name: 'temp',
        description: 'Get the current temperature in a given location',
        inputSchema: TempFunctionInput.schemaMap.toSchema(),
        onCall: onTempCall,
      ),
    ],
  );

  await agent
      .runStream(
        'What is the time and temperature in New York City and Chicago?',
      )
      .map((event) => stdout.write(event.output))
      .drain();
  print('');

  // TODO: this doesn't work yet; perhaps it needs a RefProvider.sync() to
  // resolve the LocTimeTemp schema? this would require a call to direct call to
  // JsonSchema.create() instead of the toSchema() extension method.
  // final agent2 = Agent(
  //   'openai',
  //   systemPrompt: "Translate the user's prompt into a tool call.",
  //   outputType: ListOfLocTimeTemps.schemaMap.toSchema(),
  //   outputFromJson: ListOfLocTimeTemps.fromJson,
  // );

  // final result2 = await agent2.runFor<ListOfLocTimeTemps>(result.output);
  // print(result2.output);
}

Future<void> dotPromptExample() async {
  print('\ndotPromptExample');

  final prompt = DotPrompt('''
---
model: openai
input:
  default:
    length: 3
    text: "The quick brown fox jumps over the lazy dog."
---
Summarize this in {{length}} words: {{text}}
''');

  await Agent.runPromptStream(
    prompt,
  ).map((event) => stdout.write(event.output)).drain();
  print('');
}

Future<void> multiTurnChatExample() async {
  print('\nmultiTurnChatExample');

  final agent = Agent(
    'openai',
    systemPrompt: 'You are a helpful assistant. Keep responses concise.',
  );

  // Start with empty message history
  var messages = <Message>[];

  // First turn
  final response1 = await agent.run(
    'What is the capital of France?',
    messages: messages,
  );
  print('User: What is the capital of France?');
  print('Assistant: ${response1.output}');

  // Update message history with the response
  messages = response1.messages;

  // Second turn - the agent should remember the context
  final response2 = await agent.run(
    'What is the population of that city?',
    messages: messages,
  );
  print('User: What is the population of that city?');
  print('Assistant: ${response2.output}');

  print('\nMessage history contains ${response2.messages.length} messages');
}

Future<void> providerSwitchingExample() async {
  print('\nproviderSwitchingExample');

  // Start with OpenAI agent
  final openaiAgent = Agent(
    'openai',
    systemPrompt: 'Be helpful and call tools when needed.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  // First interaction with OpenAI
  final response1 = await openaiAgent.run('What time is it in London?');
  print('OpenAI response: ${response1.output}');

  // Switch to Gemini agent, passing the message history
  final geminiAgent = Agent(
    'gemini',
    systemPrompt: 'Be helpful and call tools when needed.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  // Continue conversation with Gemini using the message history
  final response2 = await geminiAgent.run(
    'What about New York?',
    messages: response1.messages,
  );
  print('Gemini response: ${response2.output}');

  print('\nTool calls work seamlessly across providers!');
}

Future<void> embeddingExample() async {
  print('\nembeddingExample');

  final agent = Agent('openai');

  // Generate embeddings for different types of content
  const documentText =
      'Machine learning is a subset of artificial '
      'intelligence that enables computers to learn and make decisions '
      'from data.';
  const queryText = 'What is machine learning?';
  const unrelatedText = 'The weather today is sunny and warm.';

  // Create document embedding
  final documentEmbedding = await agent.createEmbedding(
    documentText,
    type: EmbeddingType.document,
  );
  print('Document embedding created: ${documentEmbedding.length} dimensions');

  // Create query embedding
  final queryEmbedding = await agent.createEmbedding(
    queryText,
    type: EmbeddingType.query,
  );
  print('Query embedding created: ${queryEmbedding.length} dimensions');

  // Create embedding for unrelated content
  final unrelatedEmbedding = await agent.createEmbedding(
    unrelatedText,
    type: EmbeddingType.document,
  );
  print('Unrelated embedding created: ${unrelatedEmbedding.length} dimensions');

  // Calculate similarities using cosine similarity
  final docQuerySimilarity = Agent.cosineSimilarity(
    documentEmbedding,
    queryEmbedding,
  );
  final docUnrelatedSimilarity = Agent.cosineSimilarity(
    documentEmbedding,
    unrelatedEmbedding,
  );

  print(
    '\nSimilarity between document and query: '
    '${docQuerySimilarity.toStringAsFixed(4)}',
  );
  print(
    'Similarity between document and unrelated: '
    '${docUnrelatedSimilarity.toStringAsFixed(4)}',
  );

  // The query should be more similar to the document than the unrelated text
  if (docQuerySimilarity > docUnrelatedSimilarity) {
    print('✓ Query is more similar to document than unrelated text');
  } else {
    print('✗ Unexpected similarity results');
  }

  // Test with Gemini provider for comparison
  print('\nTesting with Gemini provider...');
  final geminiAgent = Agent('gemini');

  final geminiDocEmbedding = await geminiAgent.createEmbedding(
    documentText,
    type: EmbeddingType.document,
  );
  print('Gemini document embedding: ${geminiDocEmbedding.length} dimensions');

  final geminiQueryEmbedding = await geminiAgent.createEmbedding(
    queryText,
    type: EmbeddingType.query,
  );

  final geminiSimilarity = Agent.cosineSimilarity(
    geminiDocEmbedding,
    geminiQueryEmbedding,
  );
  print('Gemini similarity: ${geminiSimilarity.toStringAsFixed(4)}');
}
