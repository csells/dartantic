## 0.8.0

- Multimedia Input Support: Added `attachments` parameter to Agent and Model
  interfaces for including files, data and links.
- Improvided OpenAI compatibiliy for tool calls
- Added the 'gemini-compat' provider for access to Gemini models via the
  OpenAI endpoint.

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
