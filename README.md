# dartantic_ai
Hello and welcome to Dartantic!

The [dartantic_ai package](https://pub.dev/packages/dartantic_ai) is an agent
framework inspired by [the pydantic-ai](https://ai.pydantic.dev/) and designed
to make building client and server-side apps in Dart with generative AI easier
and more fun!

# Table of Contents
- [Basic Agent Usage](#basic-agent-usage)
- [Features](#features)
- [Supported Providers](#supported-providers)
- [Using DotPrompt](#using-dotprompt)
- [JSON Output with JSON Schema](#json-output-with-json-schema)
- [Manual Typed Output with Object Mapping](#manual-typed-output-with-object-mapping)
- [Automatic Typed Output with Object Mapping](#automatic-typed-output-with-object-mapping)
- [Typed Tool Calling](#typed-tool-calling)
- [Agentic Behavior: Multi vs. Single Step Tool Calling](#agentic-behavior-multi-vs-single-step-tool-calling)
- [Streaming Output](#streaming-output)
- [Multi-media Input](#multi-media-input)
- [Embeddings](#embeddings)
- [Logging](#logging)
- [Model Discovery](#model-discovery)
- [MCP (Model Context Protocol) Server Support](#mcp-model-context-protocol-server-support)
- [Provider Capabilities](#provider-capabilities-1)
- [Provider Switching](#provider-switching)
- [Custom Providers](#custom-providers)

## Basic Agent Usage

The following shows simple agent usage using the `Agent()` constructor, which
takes a model string.

```dart
void main() async {
  // Create an agent with a model string and a system prompt
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
- [x] Multi-media input support via the `attachments` parameter for files,
  images, and web content
- [x] Embedding generation with `Agent.createEmbedding` and cosine similarity
  utilities
- [x] MCP (Model Context Protocol) server support for integrating external tools
  from local and remote servers
- [x] Logging support using the standard Dart `logging` package
- [x] Capabilities capture and reporting
- [x] Model discovery via `Provider.listModels()` to enumerate available models
  and their capabilities
- [x] Agentic workflows including multi-step and single-step tool calling
- [ ] Firebase AI provider (no API keys!)
- [ ] Multimedia output
- [ ] Audio transcription
- [ ] Tools + Typed Output (that's a little sticky right now)
- [ ] More OpenAI-compat providers (local and remote, e.g. Ollama, Gemma, xAI, Groq, etc.)


## Supported Providers

dartantic_ai currently supports the following AI model providers:

### Provider Capabilities

| Provider                   | Default Model      | Default Embedding Model  | Capabilities                                           | Notes                                  |
| -------------------------- | ------------------ | ------------------------ | ------------------------------------------------------ | -------------------------------------- |
| **OpenAI**                 | `gpt-4o`           | `text-embedding-3-small` | Text Generation, Embeddings, Chat, File Uploads, Tools | Full feature support                   |
| **OpenRouter**             | `gpt-4o`           | N/A                      | Text Generation, Chat, File Uploads, Tools             | No embedding support                   |
| **Google Gemini**          | `gemini-2.0-flash` | `text-embedding-004`     | Text Generation, Embeddings, Chat, File Uploads, Tools | Uses native Gemini API                 |
| **Gemini (OpenAI-compat)** | `gemini-2.0-flash` | `text-embedding-004`     | Text Generation, Embeddings, Chat, File Uploads, Tools | Uses OpenAI-compatible Gemini endpoint |

### Provider Configuration

| Provider                       | Provider Prefix | Aliases                            | API Key              | Provider Type    |
| ------------------------------ | --------------- | ---------------------------------- | -------------------- | ---------------- |
| **OpenAI**                     | `openai`        | -                                  | `OPENAI_API_KEY`     | `OpenAiProvider` |
| **OpenRouter**                 | `openrouter`    | -                                  | `OPENROUTER_API_KEY` | `OpenAiProvider` |
| **Google Gemini**              | `google`        | `gemini`, `googleai`, `google-gla` | `GEMINI_API_KEY`     | `GeminiProvider` |
| **Gemini (OpenAI-compatible)** | `gemini-compat` | -                                  | `GEMINI_API_KEY`     | `OpenAiProvider` |

### Model Naming Conventions
The model string used by `Agent` can be specified in several ways:
- Just the provider, e.g. `openai` → specifies whatever the default model for
  that provider
- provider:model, e.g. `google:2.0-flash` → specifies a provider and model,
  seperated by a **colon**
- provider/model, e.g. `googleai/gemini-2.5-pro` → specifies a provider and
  model, seperated by a **slash**

### Provider Aliases

Some providers support multiple provider prefixes. The alias can be used where the provider name is specified, e.g.
`gemini:gemini-2.0-flash` → `google:gemini-2.0-flash`.

### API Key Environment Variables

If you don't provide an API key when creating an agent, dartantic_ai will look
for API keys in the appropriate environment.

#### Example using Agent.environment

The Agent class provides an environment property that you can use to pass API keys along to the provider. This method is particularly suitable for setting API keys for multiple providers at once and for platforms that don't
have their own environments, like Flutter Web.

```dart
void main() async {
  // Set API keys for both OpenAI and Gemini using environment variables
  Agent.environment.addAll({
    'OPENAI_API_KEY': 'your-openai-api-key-here',
    'GEMINI_API_KEY': 'your-gemini-api-key-here',
  });

  // Create and test OpenAI agent without explicitly passing an apiKey
  final openAiAgent = Agent('openai', systemPrompt: 'Be concise.');
  final openAiResult = await openAiAgent.run('Why is the sky blue?');
  print('# OpenAI Agent');
  print(openAiResult.output);

  // Create and test Gemini agent without explicitly passing an apiKey
  final geminiAgent = Agent('gemini', systemPrompt: 'Be concise.');
  final geminiResult = await geminiAgent.run('Why is the sea salty?');
  print('# Gemini Agent');
  print(geminiResult.output);
}
```

For a runnable example, take a look at [agent_env.dart](example/bin/agent_env.dart).

## Using DotPrompt

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

You can find a working example in [dotprompt.dart](example/bin/dotprompt.dart).

## JSON Output with JSON Schema

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

## Manual Typed Output with Object Mapping

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

  print(result.output); // Output: TownAndCountry(town: Chicago, country: US)
}
```

## Automatic Typed Output with Object Mapping

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

  print(result.output); // Output: TownAndCountry(town: Chicago, country: US)
}
```

If you want to see more details, check out [output_types.dart](example/bin/output_types.dart).

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

For a complete implementation, see [tools.dart](example/bin/tools.dart).

## Agentic Behavior: Multi vs. Single Step Tool Calling

A key feature of an "agent" is its ability to perform multi-step reasoning. Instead
of just calling one tool and stopping, an agent can use the result of one
tool to inform its next action, chaining multiple tool calls together to solve a
complex problem without requiring further user intervention. This is the default
"agentic" behavior in `dartantic_ai`.

You can control this behavior using the `toolCallingMode` parameter when
creating an `Agent`:

- **`ToolCallingMode.multiStep`** (Default): This is the "agentic" mode. The
  agent will loop, calling tools as many times as it needs to fully resolve the
  user's prompt. It can use the output from one tool as the input for another,
  creating sophisticated chains of execution.
- **`ToolCallingMode.singleStep`**: The agent will perform only one round of
  tool calls and then stop. This is useful as an optimization if you only need
  the first set of tool calls.

#### Example: Multi-Step vs. Single-Step

Let's see the difference in action. First, we'll set up some tools and a common
prompt.

```dart
// Two simple tools for our agent
final tools = [
  Tool(
    name: 'get_current_time',
    description: 'Get the current date and time.',
    onCall: (_) async => {'time': '2025-06-21T10:00:00Z'},
  ),
  Tool(
    name: 'find_events',
    description: 'Find events for a specific date.',
    inputSchema: {
      'type': 'object',
      'properties': {'date': {'type': 'string'}},
      'required': ['date'],
    }.toSchema(),
    onCall: (args) async => {'events': ['Team Meeting at 11am']},
  ),
];

// A prompt that requires a two-step tool chain
const prompt = 'What events do I have today? Please find the current date first.';

// A helper to print the message history nicely
void printMessages(List<Message> messages) {
  for (var i = 0; i < messages.length; i++) {
    final m = messages[i];
    print('Message #${i + 1}: role=${m.role}');
    for (final part in m.parts) {
      print('  - $part');
    }
  }
  print('---');
}
```

**Multi-Step Execution (Default)**

When run in the default `multiStep` mode, the agent calls the first tool, gets
the date, and then immediately uses that date to call the second tool.

```dart
// Create an agent in the default multi-step mode
final multiStepAgent = Agent('openai', tools: tools);
final multiStepResponse = await multiStepAgent.run(prompt);
print('--- Multi-Step Mode ---');
printMessages(multiStepResponse.messages);
```

The resulting message history shows the full, two-step reasoning chain:

```
--- Multi-Step Mode ---
Message #1: role=user
  - TextPart(text: "What events do I have today? Please find the current date first.")
Message #2: role=model
  - ToolPart(kind: call, id: ..., name: get_current_time, arguments: {})
Message #3: role=model
  - ToolPart(kind: result, id: ..., name: get_current_time, result: {time: 2025-06-21T10:00:00Z})
Message #4: role=model
  - ToolPart(kind: call, id: ..., name: find_events, arguments: {date: 2025-06-21})
Message #5: role=model
  - ToolPart(kind: result, id: ..., name: find_events, result: {events: [Team Meeting at 11am]})
Message #6: role=model
  - TextPart(text: "You have one event today: a Team Meeting at 11am.")
---
```

**Single-Step Execution**

Now, let's run the exact same scenario in `singleStep` mode.

```dart
// Create an agent explicitly in single-step mode
final singleStepAgent = Agent(
  'openai',
  tools: tools,
  toolCallingMode: ToolCallingMode.singleStep,
);
final singleStepResponse = await singleStepAgent.run(prompt);
print('--- Single-Step Mode ---');
printMessages(singleStepResponse.messages);
```

The agent stops after the first round of tool calls. It finds the time but
doesn't proceed to the next logical step of finding the events.

```
--- Single-Step Mode ---
Message #1: role=user
  - TextPart(text: "What events do I have today? Please find the current date first.")
Message #2: role=model
  - ToolPart(kind: call, id: ..., name: get_current_time, arguments: {})
Message #3: role=model
  - ToolPart(kind: result, id: ..., name: get_current_time, result: {time: 2025-06-21T10:00:00Z})
Message #4: role=model
  - TextPart(text: "Okay, the current date is June 21, 2025. Now I will find your events.")
---
```

This clearly illustrates how `multiStep` mode enables autonomous, chained tool
use, which is fundamental to creating an actual "agent."

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

You can find a working example in [multi_turn.dart](example/bin/multi_turn.dart).

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

## Streaming Output

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

## Multi-media Input

dartantic_ai supports including files, images, and other media as attachments to
your prompts. Both OpenAI and Gemini providers can process multimedia content
alongside text.

### DataPart - Local Files

Use `DataPart.file()` to include local files (text, images, etc.):

```dart
import 'dart:io';
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('google');

  // Text file
  final response1 = await agent.run(
    'Can you summarize the attached file?',
    attachments: [await DataPart.file(File('bio.txt'))],
  );
  print(response1.output);

  // Image file
  final response2 = await agent.run(
    'What food do I have on hand?',
    attachments: [await DataPart.file(File('cupboard.jpg'))],
  );
  print(response2.output);
}
```

### LinkPart - Web URLs

Use `LinkPart()` to reference web images:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('openai:gpt-4o');

  final imageUrl = Uri.parse(
    'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/'
    'Gfp-wisconsin-madison-the-nature-boardwalk.jpg/2560px-'
    'Gfp-wisconsin-madison-the-nature-boardwalk.jpg'
  );

  final response = await agent.run(
    'Can you describe this image?',
    attachments: [LinkPart(imageUrl)],
  );
  print(response.output);
}
```

**Note**: Different providers may have varying support for specific file types
and web URLs. At the time of this writing, Gemini requires files uploaded to
Google AI File Service for LinkPart URLs.

You can find a working example in [multimedia.dart](example/bin/multimedia.dart).

## Embeddings

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
APIs. However, the embeddings themselves are NOT compatible between providers. This means that embeddings generated by one provider cannot be directly compared or used interchangeably with embeddings generated by another provider.

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

For a complete implementation, see [embeddings.dart](example/bin/embeddings.dart).

## Logging

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

If you want to see more details, check out [logging.dart](example/bin/logging.dart).

## Model Discovery

dartantic_ai supports discovering available models from providers using the
`listModels()` method. This returns information about each model including its
name, what kinds of operations it supports, and whether it's a stable production
model or a preview/experimental model.

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final provider = Agent.providerFor('openai');
  final models = await provider.listModels();

  for (final model in models) {
    final status = model.stable ? 'stable' : 'preview';
    print('${model.providerName}:${model.name} [$status] (${model.kinds})');
  }
}
```

### Model Stability Detection

The `stable` field helps you distinguish between production-ready models and
experimental ones:

- **Stable models**: `gpt-4o`, `gemini-2.5-pro`, `text-embedding-3-large`
- **Preview/experimental models**: `gpt-4-turbo-preview`, `gemini-2.5-pro-exp-03-25`, `o1-preview`

Until there's an API from the model providers (I'm looking at you, Google and OpenAI),
models are classified using heuristics based on their names, looking for patterns
like "preview", "experimental", "latest", version numbers, and date suffixes.

For a working example, take a look at [list_models.dart](example/bin/list_models.dart).

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
  final huggingFace = McpClient.remote(
    'huggingface',
    url: Uri.parse('https://huggingface.co/mcp'),
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
  final calculatorServer = McpClient.local(
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

For a runnable example, take a look at [mcp_servers.dart](example/bin/mcp_servers.dart).

## Provider Capabilities

dartantic_ai includes a capabilities system that allows you to check what features each provider supports. Different providers have different capabilities - for example, OpenRouter doesn't support embedding generation while OpenAI and Gemini do.

### Checking Provider Capabilities

You can check what capabilities a provider supports using the `caps` property:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final openaiAgent = Agent('openai');
  final openrouterAgent = Agent('openrouter');

  // Check capabilities
  print('OpenAI capabilities: ${openaiAgent.caps}');
  // Output: (textGeneration, embeddings, chat, fileUploads, tools)

  print('OpenRouter capabilities: ${openrouterAgent.caps}');
  // Output: (textGeneration, chat, fileUploads, tools)

  // Check specific capabilities
  final openaiSupportsEmbeddings = openaiAgent.caps.contains(ProviderCaps.embeddings);
  final openrouterSupportsEmbeddings = openrouterAgent.caps.contains(ProviderCaps.embeddings);

  print('OpenAI supports embeddings: $openaiSupportsEmbeddings'); // Output: true
  print('OpenRouter supports embeddings: $openrouterSupportsEmbeddings'); // Output: false
}
```

### Capability Types

The `ProviderCaps` enum defines the following capability types:

- **`textGeneration`** - Provider supports text generation and completion
- **`embeddings`** - Provider supports vector embedding generation
- **`chat`** - Provider supports conversational/chat interactions
- **`fileUploads`** - Provider supports file and media uploads
- **`tools`** - Provider supports tool/function calling

### Graceful Capability Handling

Check capabilities before attempting operations to handle unsupported features gracefully:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  final agent = Agent('openrouter'); // OpenRouter doesn't support embeddings

  if (agent.caps.contains(ProviderCaps.embeddings)) {
    // Safe to use embeddings
    final embedding = await agent.createEmbedding('test text');
    print('Embedding generated: ${embedding.length} dimensions');
  } else {
    print('Provider ${agent.model} does not support embeddings');
    // Use alternative approach or different provider
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

You can find a working example in [providers.dart](example/bin/providers.dart).

## Custom Providers

dartantic_ai allows you to extend its functionality by creating your own custom
providers. This is useful for integrating with LLM services that are not yet
natively supported, or for creating mock providers for testing purposes.

The process involves two main steps:
1.  Implement the `Provider` and `Model` interfaces.
2.  Register your custom provider in the `Agent.providers` table.

Once registered, your custom provider can be used just like any of the built-in
providers.

### Example: Creating and Using a Custom Echo Provider

Here's a complete example of how to create a simple `EchoProvider` that just
echos back the prompt it receives.

First, define your `Model` and `Provider` implementations:

```dart
import 'package:dartantic_ai/dartantic_ai.dart';

/// A simple model that echos back the prompt.
class EchoModel implements Model {
  @override
  Set<ProviderCaps> get caps => {ProviderCaps.textGeneration};

  @override
  String get generativeModelName => 'echo';

  @override
  String get embeddingModelName => '';

  @override
  Stream<AgentResponse> runStream({
    required String prompt,
    Iterable<Message> messages = const [],
    Iterable<Part> attachments = const [],
  }) async* {
    yield AgentResponse(
      output: prompt,
      messages: [
        ...messages,
        Message.user([TextPart(prompt)]),
        Message.model([TextPart(prompt)]),
      ],
    );
  }

  @override
  Future<Float64List> createEmbedding(String text, {EmbeddingType? type}) {
    throw UnsupportedError('EchoModel does not support embeddings.');
  }
}

/// A custom provider that serves the [EchoModel].
class EchoProvider implements Provider {
  @override
  String get name => 'echo';

  @override
  Set<ProviderCaps> get caps => {ProviderCaps.textGeneration};

  @override
  Model createModel(ModelSettings settings) => EchoModel();

  @override
  Future<Iterable<ModelInfo>> listModels() async => [
        ModelInfo(
          providerName: name,
          name: 'echo',
          kinds: const {ModelKind.chat},
          stable: true,
        ),
      ];
}
```

Next, register your provider and use it to create an `Agent`:

```dart
void main() async {
  // 1. Register your custom provider in the static table.
  Agent.providers['echo'] = (_) => EchoProvider();

  // 2. Create an agent using your provider's name.
  final agent = Agent('echo');
  final response = await agent.run('Hello, custom provider!');

  // 3. Verify that it works.
  print(response.output); // Output: Hello, custom provider!
  print(agent.model);    // Output: echo:echo
}
```

For a complete implementation, see [custom_provider.dart](example/bin/custom_provider.dart).
