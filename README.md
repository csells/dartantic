# dartantic_ai
The [dartantic_ai package for Dart](https://pub.dev/packages/dartantic_ai) is
inspired by [the pydantic-ai package for Python](https://ai.pydantic.dev/) to
provide easy, typed access to LLM outputs and tool/function calls across
multiple LLMs.

## Alpha
Only supporting Gemini and OpenAI models via API keys in this limited release.

## Features
The following are the target features for this package:
- [x] Multi-Model Support
- [x] Create agents from model strings (e.g. `openai:gpt-4o`) or typed
  providers (e.g. `GoogleProvider()`)
- [x] Automatically check environment for API key if none is provided (not web
  compatible)
- [x] String output via `Agent.run`
- [x] Typed output via `Agent.runFor`
- [x] Define tools and their inputs/outputs easily
- [x] Automatically generate LLM-specific tool/output schemas
- [x] Bring your own provider
- [ ] Execute tools with validated inputs
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

  // Run the agent with a prompt
  final result = await agent.run('Where does "hello world" come from?');
  print(result.output); // Output: one sentence on the origin on "hello world"
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

  // Run the agent with a prompt
  final result = await agent.run('Where does "hello world" come from?');
  print(result.output); // Output: one sentence on the origin on "hello world"
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
  print(result.output); // Output: Quick brown fox.
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
    outputType: townCountrySchema.toSchema(),
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
  
  TownAndcountry({required this.town, required this.country});
  
  factory TownAndcountry.fromJson(Map<String, dynamic> json) => TownAndcountry(
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
  String toString() => 'TownAndcountry(town: $town, country: $country)';
}

void main() async {
  // Use runFor with a type parameter for automatic conversion 
  final agent = Agent(
    'openai',
    outputType: TownAndcountry.schemaMap.toSchema(),
    outputFromJson: TownAndcountry.fromJson,
  );

  final result = await agent.runFor<TownAndcountry>(
    'The windy city in the US of A.',
  );

  print(result.output); // Output: TownAndcountry(town: Chicago, country: United States)
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
class TownAndcountry {
  TownAndcountry({required this.town, required this.country});

  factory TownAndcountry.fromJson(Map<String, dynamic> json) =>
      _$TownAndcountryFromJson(json);

  final String town;
  final String country;

  Map<String, dynamic> toJson() => _$TownAndcountryToJson(this);

  @jsonSchema
  static Map<String, dynamic> get schemaMap => _$TownAndcountrySchemaMap;

  @override
  String toString() => 'TownAndcountry(town: $town, country: $country)';
}

void main() async {
  // Use runFor with a type parameter for automatic conversion 
  final agent = Agent(
    'openai',
    outputType: TownAndcountry.schemaMap.toSchema(),
    outputFromJson: TownAndcountry.fromJson,
  );

  final result = await agent.runFor<TownAndcountry>(
    'The windy city in the US of A.',
  );

  print(result.output); // Output: TownAndcountry(town: Chicago, country: United States)
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
        inputType: TimeFunctionInput.schemaMap.toSchema(),
        onCall: onTimeCall,
      ),
    ],
  );

  final result = await agent.run(
    'What is time is it in New York City?',
  );

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