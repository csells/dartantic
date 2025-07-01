## 0.9.7

- Added the ability to set embedding dimensionality
- Removed ToolCallingMode and singleStep mode. Multi-step tool calling is now
  always enabled.

## 0.9.6

- fixed an issue where the OpenAI model only processed the last tool result when
  multiple tool results existed in a single message, causing unmatched tool call
  IDs during provider switching.

## 0.9.5

- Major OpenAI Multi-Step Tool Calling Improvement: Eliminated complex probe
  mechanism (100+ lines of code) in favor of [OpenAI's native
  `parallelToolCalls`
  parameter](https://pub.dev/documentation/openai_dart/latest/openai_dart/CreateChatCompletionRequest/parallelToolCalls.html).
  This dramatically simplifies the implementation while improving reliability
  and performance.

## 0.9.4

- README & docs tweaks

## 0.9.3

- Completely revamped docs! https://docs.page/csells/dartantic_ai

## 0.9.2

- Added `Agent.environment` to allow setting environment variables
  programmatically. This is especially useful for web applications where
  traditional environment variables are not available.

## 0.9.1

- Added support for extending the provider table at runtime, allowing custom
  providers to be registered dynamically.

- Added optional `name` parameter to `DataPart` and `LinkPart` for better
  multi-media message creation ergonomics.

## 0.9.0

- Added `ToolCallingMode` to control multi-step tool calling behavior.
  - `multiStep` (default): The agent will continue to send tool results until
    all of the tool calls have been exercised.
  - `singleStep`: The agent will perform only one request-response and then
    stop.

- OpenAI Multi-Step Tool Calling by including probing for additional tool calls
  when the model responds with text instead of a tool call.

- Gemini multi-step tool calling by handling new tool calls while processing the
  response from previous tool calling.

- Schema Nullable Properties Fix: Required properties in JSON schemas now
  correctly set `nullable: false` in converted Gemini schemas, since required
  properties cannot be null by definition.

## 0.8.3

- Breaking Change: `McpServer` → `McpClient`: Renamed MCP integration class cuz
  we're not building a server!
- MCP Required Fields Preservation: Enhanced MCP integration to preserve
  required fields in tool schemas, allowing LLMs to know what parameters are
  required for each tool call. This turns out to be a critical piece in whether
  the LLM is able to call the tool correctly or not.
- Model discovery: Added `Provider.listModels()` to enumerate available models,
  and the kinds of operations they support and whether they're in stable or
  preview/experimental mode.
- Breaking Change: simplifying provider names (again!)
- no change to actual provider aliases, e.g. "gemini" still maps to "google"
- fixed a nasty fully-qualified model naming bug
- Better docs!

## 0.8.2

- Better docs!

## 0.8.1

- Breaking change: Content=>List<Part>, lots more List<> => Iterable<>

## 0.8.0

- Multimedia Input Support: Added `attachments` parameter to Agent and Model
  interfaces for including files, data and links.
- Improved OpenAI compatibility for tool calls
- Added the 'gemini-compat' provider for access to Gemini models via the OpenAI
  endpoint.
- Breaking change: everywhere I passed List<Message> I now pass
  Iterable<Message>

## 0.7.0

- Provider Capabilities System: Add support for providers to declare their
  capabilities
- baseUrl support to enable OpenAI-compatibility
- Added new "openrouter" provider
  - it's an OpenAI API implementation, but doesn't support embeddings
  - which drove support for provider capabilities...
- temperature support
- Breaking change: `McpServer.remote` now takes a `Uri` instead of a `String`
  for the URL
- Breaking change: Renamed model interface properties for clarity:
  - `Model.modelName` → `Model.generativeModelName`
  - Also added `Model.embeddingModelName`
- Breaking change: Provider capabilities API naming:
  - `Provider.caps` returns `Set<ProviderCaps>` instead of
    `Iterable<ProviderCaps>`

## 0.6.0

- MCP (Model Context Protocol) Server Support
- Message construction convenience methods:
  - Added `Content` type alias for `List<Part>` to improve readability
  - Added convenience constructors for `Message`: `Message.system()`,
    `Message.user()`, `Message.model()`
  - Added `Content.text()` extension method for easy text content creation
  - Added convenience constructors for `ToolPart`: `ToolPart.call()` and
    `ToolPart.result()`
- Breaking change: inputType/outputType to inputSchema/outputSchema; I couldn't
  stand to look at `inputType` and `outputType` in the code anymore!
- Add logging support (defaults to off) and a logging example

## 0.5.0

- Embedding generation: Add methods to generate vector embeddings for text

## 0.4.0

- Streaming responses via `Agent.runStream` and related methods.
- Multi-turn chat support
- Provider switching: seamlessly alternate between multiple providers in a
  single conversation, with full context and tool call/result compatibility.

## 0.3.0

- added [dotprompt_dart](https://pub.dev/packages/dotprompt_dart) package
  support via `Agent.runPrompt(DotPrompt prompt)`
- expanded model naming to include "providerName", "providerName:model" or
  "providerName/model", e.g. "openai" or "googleai/gemini-2.0-flash"
- move types specified by `Map<String, dynamic>` to a `JsonSchema` object; added
  `toMap()` extension method to `JsonSchema` and `toSchema` to `Map<String,
  dynamic>` to make going back and forth more convenient.
- move the provider argument to `Agent.provider` as the most flexible case, but
  also the less common one. `Agent()` will contine to take a model string.

## 0.2.0

- Define tools and their inputs/outputs easily
- Automatically generate LLM-specific tool/output schemas
- Allow for a model descriptor string that just contains a family name so that
  the provider can choose the default model.

## 0.1.0

- Multi-Model Support (just Gemini and OpenAI models so far)
- Create agents from model strings (e.g. `openai:gpt-4o`) or typed providers
  (e.g. `GoogleProvider()`)
- Automatically check environment for API key if none is provided (not web
  compatible)
- String output via `Agent.run`
- Typed output via `Agent.runFor`

## 0.0.1

- Initial version.
