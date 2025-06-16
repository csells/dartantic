# dartantic_ai
The [dartantic_ai package for Dart](https://pub.dev/packages/dartantic_ai) is
inspired by [the pydantic-ai package for Python](https://ai.pydantic.dev/) to
provide easy, typed access to LLM outputs and tool/function calls across
multiple LLMs.

# Table of Contents
- [Alpha](#alpha)
- [Features](#features)
- [Usage](#usage)
- [Typed Tool Calling](#typed-tool-calling)
- [Embedding Generation](#embedding-generation)
- [Logging and Debugging](#logging-and-debugging)
- [MCP (Model Context Protocol) Server Support](#mcp-model-context-protocol-server-support)
- [Provider Switching](#provider-switching)

## Alpha
Only supporting Gemini and OpenAI models via API keys in this limited release.

## Features
The following are the target features for this package:
- [x] Multi-Model Support
- [x] Create agents from model strings (e.g. `openai:gpt-4o`) or typed providers
  (e.g. `GeminiProvider()`)
- [x] Automatically check environment for API key if none is provided (not web
  compatible)
- [x] Streaming string output via `Agent.runStream`
- [x] Multi-turn chat/message history support via the `messages` parameter and
  the `Message` class (with roles and content types)
- [x] Typed output via `Agent.runFor`
- [x] Define tools and their inputs/outputs easily
- [x] Automatically generate LLM-specific tool/output schemas
- [x] Bring your own provider
- [x] Execute tools with validated inputs
- [x] Embedding generation with `Agent.createEmbedding` and cosine similarity
  utilities
- [x] MCP (Model Context Protocol) server support for integrating external tools
  from local and remote servers
- [x] Logging support using the standard Dart `logging` package
- [ ] Chains and Sequential Execution
- [ ] JSON Mode, Functions Mode, Flexible Decoding
- [ ] Simple Assistant/Agent loop utilities
- [ ] Per call usage statistics

## Usage

The following are some examples that work in the current build.

### Basic Agent Usage

The following shows simple agent usage using the `Agent()` constructor, which
takes a model string.

```dart
void main() async {
  // Create an agent with a system prompt
  final agent = Agent(
    'openai',  // Can also use 'openai:gpt-4o' or 'openai/gpt-4o'
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  // Run the agent with a prompt (non-streaming)
  final result = await agent.run('Where does "hello world" come from?');
  print(result.output); // Output: one sentence on the origin of "hello world"
}
```

Alternatively, you can use the `Agent()` constructor which takes a provider
directly:

```dart
void main() async {
  // Create an agent with a provider
  final agent = Agent.provider(
    OpenAiProvider(),
    systemPrompt: 'Be concise, reply with one sentence.',
  );

  // Run the agent with a prompt (non-streaming)
  final result = await agent.run('Where does "hello world" come from?');
  print(result.output); // Output: one sentence on the origin of "hello world"
}
```

### Using DotPrompt

You can also use the `Agent.runPrompt()` method with a `DotPrompt` object for
more structured prompts:

```dart
void main() async {
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

  final result = await Agent.runPrompt(prompt);
  print(result.output); // Output: Fox jumps dog.
}
```

### JSON Output with JSON Schema

The following example provides JSON output using a hand-written `schemaMap`
property, which configures the underlying LLM to response in JSON.


```dart
void main() async {
  // Define a JSON schema for structured output
  final townCountrySchema = {
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  // Create an agent with the schema
  final agent = Agent(
    'openai',
    outputSchema: townCountrySchema.toSchema(),
  );

  // Get structured output as a JSON object
  final result = await agent.run('The windy city in the US of A.');
  print(result.output); // Output: {"town":"Chicago","country":"United States"}
}
```

### Manual Typed Output with Object Mapping

The following example provides typed output using automatic json decoding from a
hand-written `fromJson` method and a hand-written `schemaMap` property.


```dart
// Create a data class in your code
class TownAndCountry {
  final String town;
  final String country;

  TownAndCountry({required this.town, required this.country});

  factory TownAndCountry.fromJson(Map<String, dynamic> json) => TownAndCountry(
      town: json['town'],
      country: json['country'],
    );

  static Map<String, dynamic> get schemaMap => {
    'type': 'object',
    'properties': {
      'town': {'type': 'string'},
      'country': {'type': 'string'},
    },
    'required': ['town', 'country'],
    'additionalProperties': false,
  };

  @override
  String toString() => 'TownAndCountry(town: $town, country: $country)';
}

void main() async {
  // Use runFor with a type parameter for automatic conversion
  final agent = Agent(
    'openai',
    outputSchema: TownAndCountry.schemaMap.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );

  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );

  print(result.output); // Output: TownAndCountry(town: Chicago, country: United States)
}
```

### Automatic Typed Output with Object Mapping

The following example provides typed output using
[json_serializable](https://pub.dev/packages/json_serializable) for automatic
json decoding and [soti_schema](https://pub.dev/packages/soti_schema) for
automatic Json Schema definition.

```dart
// Create a data class in your code
@SotiSchema()
@JsonSerializable()
class TownAndCountry {
  TownAndCountry({required this.town, required this.country});

  factory TownAndCountry.fromJson(Map<String, dynamic> json) =>
      _$TownAndCountryFromJson(json);

  final String town;
  final String country;

  Map<String, dynamic> toJson() => _$TownAndCountryToJson(this);

  @jsonSchema
  static Map<String, dynamic> get schemaMap => _$TownAndCountrySchemaMap;

  @override
  String toString() => 'TownAndCountry(town: $town, country: $country)';
}

void main() async {
  // Use runFor with a type parameter for automatic conversion
  final agent = Agent(
    'openai',
    outputSchema: TownAndCountry.schemaMap.toSchema(),
    outputFromJson: TownAndCountry.fromJson,
  );

  final result = await agent.runFor<TownAndCountry>(
    'The windy city in the US of A.',
  );

  print(result.output); // Output: TownAndCountry(town: Chicago, country: United States)
}
```

## Typed Tool Calling

Imagine you'd like to provided your AI Agent with some tools to call. You'd like
those to be typed without manually creating a JSON Schema object to define the
parameters. You can define the parameters to your tool with a Dart class:

```dart
@SotiSchema()
@JsonSerializable()
class TimeFunctionInput {
  TimeFunctionInput({required this.timeZoneName});

  /// The name of the time zone to get the time in (e.g. "America/New_York")
  final String timeZoneName;

  static TimeFunctionInput fromJson(Map<String, dynamic> json) =>
      _$TimeFunctionInputFromJson(json);

  @jsonSchema
  static Map<String, dynamic> get schemaMap => _$TimeFunctionInputSchemaMap;
}
```
The use of the JSON serializer and Soti Schema annotations causes the creation
of a schemaMap property that provides a JSON schema at runtime that defines our
tool:

```dart
Future<void> toolExample() async {
  final agent = Agent(
    'openai',
    systemPrompt: 'Show the time as local time.',
    tools: [
      Tool(
        name: 'time',
        description: 'Get the current time in a given time zone',
        inputSchema: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  final result = await agent.run('What is time is it in New York City?');
  print(result.output);
}
```

This code defines a tool that gets the current time for a particular time zone.
The tool's input arguments are defined via the generated JSON schema.

The tool doesn't need to define a schema for the output of the tool -- the LLM
will take whatever data you give it -- but we still need to be able to convert
the output type to JSON:

```dart
@JsonSerializable()
class TimeFunctionOutput {
  TimeFunctionOutput({required this.time});

  /// The time in the given time zone
  final DateTime time;

  Map<String, dynamic> toJson() => _$TimeFunctionOutputToJson(this);
}
```

We can now use the JSON serialization support in these two types to implement
the tool call function:

```dart
Future<Map<String, dynamic>?> onTimeCall(Map<String, dynamic> input) async {
  // parse the JSON input into a type-safe object
  final timeInput = TimeFunctionInput.fromJson(input);

  tz_data.initializeTimeZones();
  final location = tz.getLocation(timeInput.timeZoneName);
  final now = tz.TZDateTime.now(location);

  // construct a type-safe object, then translate to JSON to return
  return TimeFunctionOutput(time: now).toJson();
}
```

In this way, we use the tool input type to define the format of the JSON we're
expecting from the LLM and to decode the input JSON into a typed object for our
implementation of the `onTimeCall` function. Likewise, we use the tool output
type to gather the returned data before encoding that back into JSON for the
return to the LLM.

Since the LLM is a little more lax about the data you return to it, you may
decide to define a Dart type for your input parameters and just bundle up the
return data manually, like so:

```dart
Future<Map<String, dynamic>?> onTimeCall(Map<String, dynamic> input) async {
  // parse the JSON input into a type-safe object
  final timeInput = TimeFunctionInput.fromJson(input);

  tz_data.initializeTimeZones();
  final location = tz.getLocation(timeInput.timeZoneName);
  final now = tz.TZDateTime.now(location);

  // return a JSON map directly as output
  return {'time': now};
}
```

Not only is this simpler code, but it frees you from maintaining a separate type
for output.

### Multi-turn Chat (Message History)

You can pass a list of `Message` objects to the agent for context-aware,
multi-turn conversations. Each message has a role (`system`, `user`, `model`)
and a list of content parts (text, media, etc.). All providers (just OpenAI and
Gemini for now) support this interface.

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_ai/src/models/message.dart';

void main() async {
  final agent = Agent(
    'openai:gpt-4o',
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
  print('Assistant: ${response1.output}'); // Output: The capital of France is Paris.

  // Update message history with the response
  messages = response1.messages;

  // Second turn - the agent should remember the context
  final response2 = await agent.run(
    'What is the population of that city?',
    messages: messages,
  );
  print('User: What is the population of that city?');
  print('Assistant: ${response2.output}'); // Output: Paris has approximately 2.1 million people in the city proper.

  print('Message history contains ${response2.messages.length} messages'); // Output: Message history contains 4 messages
}
```

### Message Construction Convenience Methods

dartantic_ai provides several convenience methods to simplify creating messages
and content:

#### Content Type Alias and Text Creation

The `Content` type alias makes working with message content more readable:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  // Create text content easily
  final textContent = Content.text('Hello, how can I help you?');

  // Equivalent to: [TextPart('Hello, how can I help you?')]
  print(textContent); // Output: [TextPart(text: "Hello, how can I help you?")]
}
```

#### Message Role Constructors

Create messages for specific roles without specifying the role explicitly:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  // Create messages using convenience constructors
  final userMessage = Message.user(Content.text('What is 2 + 2?'));
  final modelMessage = Message.model(Content.text('2 + 2 equals 4.'));

  // Use them in a conversation
  final messages = [userMessage, modelMessage];

  final agent = Agent('openai');
  final response = await agent.run('What about 3 + 3?', messages: messages);
  print(response.output); // Output: 3 + 3 equals 6.
}
```

These convenience methods reduce boilerplate when working with messages.

### Streaming Output

`Agent.runStream` returns a `Stream<AgentResponse>`, allowing you to process
output as it is generated by the LLM in real time. This is useful for displaying
partial results to users or for handling long responses efficiently. Note:
`Agent.run` returns a `Future<AgentResponse>` with the full response, not a
stream.

```dart
import 'dart:io';
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('openai:gpt-4o');
  final stream = agent.runStream('Tell me a short story about a brave robot.');
  await for (final response in stream) {
    stdout.write(response.output); // Output: Once upon a time, there was a brave robot named... (streaming in real-time)
  }
}
```

## Embedding Generation

dartantic_ai supports generating vector embeddings for text using both OpenAI
and Gemini providers. Embeddings are useful for semantic search, clustering, and
building RAG (Retrieval-Augmented Generation) applications.

### Basic Embedding Usage

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('openai');

  // Generate a document embedding
  final documentText = 'Machine learning is a subset of artificial intelligence.';
  final documentEmbedding = await agent.createEmbedding(
    documentText,
    type: EmbeddingType.document,
  );
  print('Document embedding: ${documentEmbedding.length} dimensions'); // Output: Document embedding: 1536 dimensions

  // Generate a query embedding
  final queryText = 'What is machine learning?';
  final queryEmbedding = await agent.createEmbedding(
    queryText,
    type: EmbeddingType.query,
  );
  print('Query embedding: ${queryEmbedding.length} dimensions'); // Output: Query embedding: 1536 dimensions
}
```

### Embedding Similarity and Search

Use the built-in cosine similarity function to compare embeddings for semantic
search:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('openai');

  // Create embeddings for different texts
  final text1 = 'The cat sat on the mat.';
  final text2 = 'A cat is sitting on a mat.';
  final text3 = 'The weather is sunny today.';

  final embedding1 = await agent.createEmbedding(text1, type: EmbeddingType.document);
  final embedding2 = await agent.createEmbedding(text2, type: EmbeddingType.document);
  final embedding3 = await agent.createEmbedding(text3, type: EmbeddingType.document);

  // Calculate similarities
  final similarity1vs2 = Agent.cosineSimilarity(embedding1, embedding2);
  final similarity1vs3 = Agent.cosineSimilarity(embedding1, embedding3);

  print('Similarity between similar texts: ${similarity1vs2.toStringAsFixed(4)}'); // Output: Similarity between similar texts: 0.8934
  print('Similarity between different texts: ${similarity1vs3.toStringAsFixed(4)}'); // Output: Similarity between different texts: 0.2156

  // Similar texts should have higher similarity
  if (similarity1vs2 > similarity1vs3) {
    print('✓ Similar texts are more semantically related'); // Output: ✓ Similar texts are more semantically related
  }
}
```

### Cross-Provider Embedding Support

Both OpenAI and Gemini providers support embedding generation with consistent
APIs:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final text = 'Artificial intelligence is transforming technology.';

  // OpenAI embeddings
  final openaiAgent = Agent('openai');
  final openaiEmbedding = await openaiAgent.createEmbedding(text, type: EmbeddingType.document);
  print('OpenAI embedding: ${openaiEmbedding.length} dimensions'); // Output: OpenAI embedding: 1536 dimensions

  // Gemini embeddings
  final geminiAgent = Agent('gemini');
  final geminiEmbedding = await geminiAgent.createEmbedding(text, type: EmbeddingType.document);
  print('Gemini embedding: ${geminiEmbedding.length} dimensions'); // Output: Gemini embedding: 768 dimensions

  // Note: Different providers may have different embedding dimensions
  // But the API and similarity calculations work the same way
}
```

## Logging and Debugging

dartantic_ai provides logging support using the standard Dart `logging` package.
This allows you to see detailed information about internal operations, including
LLM requests/responses, tool execution, and provider operations.

### Enabling Logging

To enable logging for dartantic_ai operations, configure the logging package:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:logging/logging.dart';

void main() async {
  // Configure logging to see dartantic_ai internal operations
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final agent = Agent('openai');
  final result = await agent.run('Hello world!');
  print(result.output);
}
```

### Filtering dartantic_ai Logs Only

To filter dartantic_ai logs specifically:

```dart
import 'package:logging/logging.dart';

void main() async {
  // Configure logging for dartantic_ai specifically
  hierarchicalLoggingEnabled = true;
  final dartanticLogger = Logger('dartantic_ai');
  dartanticLogger.level = Level.ALL;
  dartanticLogger.onRecord.listen((record) {
    print('[dartantic_ai] ${record.level.name}: ${record.message}');
  });

  // Your agent code here...
}
```

This is particularly useful for debugging tool execution, understanding provider
behavior, or troubleshooting unexpected responses.

## MCP (Model Context Protocol) Server Support

dartantic_ai supports connecting to MCP servers to extend Agent capabilities
with external tools. MCP servers can run locally (via stdio) or remotely (via
HTTP), providing access to file systems, databases, web APIs, and other external
resources.

### MCP Server Features

- **Dual Transport Support**: Connect to local servers via stdio or remote
  servers via HTTP
- **Lazy Connection**: Servers connect automatically when first accessed
- **Tool Discovery**: Automatically discover and convert MCP tools to Agent
  Tools
- **Type Safety**: MCP tools integrate seamlessly with local tools, returning
  `Map<String, dynamic>`
- **Resource Management**: Proper cleanup with `disconnect()` method


### Remote MCP Server Usage

Connect to remote MCP servers and use their tools with your Agent:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final huggingFace = McpServer.remote(
    'huggingface',
    url: 'https://huggingface.co/mcp',
  );

  final agent = Agent(
    'google',
    systemPrompt:
        'You are a helpful assistant with access to various tools; '
        'use the right one for the right job!',
    tools: [...await huggingFace.getTools()],
  );

  try {
    const query = 'Who is hugging face?';
    await agent.runStream(query).map((r) => stdout.write(r.output)).drain();
  } finally {
    await huggingFace.disconnect();
  }
}
```

### Local MCP Server Usage

Connect to local MCP servers running as separate processes:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  // Connect to a local MCP server (e.g., a calculator server)
  final calculatorServer = McpServer.local(
    'calculator',
    command: 'dart',
    args: ['run', 'calculator_mcp_server.dart'],
  );

  final agent = Agent(
    'openai',
    systemPrompt: 'You are a helpful calculator assistant. '
        'Use the available tools to perform calculations.',
    tools: [...await calculatorServer.getTools()],
  );

  try {
    final result = await agent.run('What is 15 multiplied by 27?');
    print(result.output); // The agent will use the calculator tool and provide the answer
  } finally {
    await calculatorServer.disconnect();
  }
}
```

## Provider Switching

dartantic_ai supports seamless switching between OpenAI and Gemini providers
within a single conversation. You can alternate between providers (e.g., OpenAI
→ Gemini → OpenAI) and the message history—including tool calls and tool
results—remains compatible and threaded correctly. This enables robust
multi-provider workflows, such as starting a conversation with one provider and
continuing it with another, or leveraging provider-specific strengths in a
single chat.

- Message history is serialized and deserialized in a provider-agnostic way.
- Tool call and result IDs are stable and compatible across providers.
- Integration tests verify that tool calls and results are preserved and
  threaded correctly when switching providers.

This feature allows you to build advanced, resilient LLM applications that can
leverage multiple providers transparently.

### Example: Switching Providers in a Conversation

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final openaiAgent = Agent.provider(OpenAiProvider(), systemPrompt: 'You are a helpful assistant.');
  final geminiAgent = Agent.provider(GeminiProvider(), systemPrompt: 'You are a helpful assistant.');

  // Start conversation with OpenAI
  var response = await openaiAgent.run('What animal says "moo"?');
  print('OpenAI: ${response.output}'); // Output: A cow says "moo".
  var history = response.messages;

  // Continue conversation with Gemini
  response = await geminiAgent.run('What animal says "quack"?', messages: history);
  print('Gemini: ${response.output}'); // Output: A duck says "quack".
  history = response.messages;

  // Store some info with OpenAI
  response = await openaiAgent.run('My favorite animal is the platypus.', messages: history);
  print('OpenAI: ${response.output}'); // Output: That's great! Platypuses are fascinating creatures.
  history = response.messages;

  // Retrieve info with Gemini
  response = await geminiAgent.run('What animal did I say I liked?', messages: history);
  print('Gemini: ${response.output}'); // Output: You said your favorite animal is the platypus.
}
```
