# Product Requirements Document (PRD)

## Overview

dartantic_ai is a Dart package inspired by Python's pydantic-ai, designed to
provide easy, typed access to LLM (Large Language Model) outputs and
tool/function calls across multiple LLM providers. The package aims to simplify
the integration of LLMs into Dart applications, supporting both string and
structured (typed) outputs, and enabling the definition and execution of typed
tools.

## Goals
- Provide a unified, type-safe interface for interacting with multiple LLM
  providers (OpenAI, Gemini, etc.).
- Allow easy creation of agents that can run prompts and return string or typed
  outputs.
- Enable definition and execution of typed tools/functions callable by LLMs.
- Support automatic schema generation and validation for tool inputs/outputs.
- Facilitate both simple and advanced agent workflows (e.g., chains, sequential
  execution).

## Features
- Multi-model support (OpenAI, Gemini, etc.).
- Agent creation via model string (e.g., `openai:gpt-4o`) or provider instance
  (e.g., `OpenAiProvider()`).
- Automatic environment variable detection for API keys.
- String output via `Agent.run`.
- Typed output via `Agent.runFor`.
- Easy tool definition with typed input/output.
- Automatic LLM-specific tool/output schema generation.
- Custom provider support (bring your own provider).
- Logging support using the standard Dart `logging` package with configurable
  levels.
- Model discovery via `Provider.listModels()` to enumerate available models, the
  kinds of operations they support, and their stability status (stable vs
  preview/experimental).
- (Planned) Tool execution with validated inputs.
- (Planned) Chains and sequential execution.
- (Planned) JSON mode, functions mode, flexible decoding.
- (Planned) Assistant/agent loop utilities.
- (Planned) Per-call usage statistics.

## User Stories
- As a developer, I want to create an agent with a system prompt and run a
  prompt to get a concise answer.
- As a developer, I want to use a provider directly to create an agent and run
  prompts.
- As a developer, I want to use structured prompts (DotPrompt) for more complex
  input scenarios.
- As a developer, I want to receive structured JSON output from the LLM,
  validated against a schema.
- As a developer, I want to map LLM output to custom Dart types using fromJson
  and schemaMap.
- As a developer, I want to define tools with typed input and output, and have
  the LLM call these tools as needed.
- As a developer, I want to support multiple models (starting with OpenAI and
  Gemini models), and easily switch between them.

## Requirements
### Functional
- The system MUST support agent creation via both model string and provider
  instance.
- The system MUST support running prompts and returning streaming string
  outputs.
- The system MUST support running prompts and returning typed outputs, using a
  provided schema and fromJson function.
- The system MUST support defining tools with typed input (validated via JSON
  schema) and output.
- The system MUST support automatic schema generation for tool inputs/outputs
  using annotations (e.g., SotiSchema, JsonSerializable).
- The system MUST support both OpenAI and Gemini providers, with API keys loaded
  from environment variables.
- The system MUST serialize and deserialize message history in a
  provider-agnostic way, so that message histories can be shared and replayed
  seamlessly between different providers (e.g., OpenAI and Gemini) without loss
  of tool call, tool result, or context information.
- The system SHOULD support structured prompts via DotPrompt.
- The system SHOULD allow custom providers to be added.
- The system SHOULD provide clear error messages for missing API keys or
  unsupported providers.

### Non-Functional
- The system MUST be compatible with Dart 3.7.2 or higher.
- The system SHOULD provide comprehensive documentation and usage examples.
- The system SHOULD include integration tests covering all major features and
  user stories.

## Acceptance Criteria
- [x] Agents can be created using both model strings and provider instances.
- [x] Agents can run prompts and return streaming string outputs.
- [x] Agents can run prompts and return typed outputs, mapped to custom Dart
  types.
- [x] Agents can use DotPrompt for structured prompt input.
- [x] Execute tools with validated inputs
- [x] The system supports both OpenAI and Gemini providers, with API keys loaded
  from environment variables.
- [x] The system provides clear error messages for missing API keys or
  unsupported providers.
- [x] Integration tests pass for all major features

## Implementation Considerations
### Multi-Turn Tool Calling
dartantic_ai implements sophisticated multi-turn tool calling that works across
different LLM providers, despite their different underlying behaviors. This
feature enables complex reasoning chains where models can:

1. Make multiple tool calls in sequence
2. Use the results of earlier tool calls to inform later ones
3. Produce final responses that incorporate all tool results

The implementation handles provider-specific differences:

#### Gemini Implementation
- **Simple Loop Approach**: Gemini natively supports continuous tool calling
  without special handling
- **Process Flow**:
  - Send history + messages + tools to Gemini
  - Process streaming response, collecting tool calls
  - Execute tool calls and add results to conversation
  - Gemini automatically continues with next tool calls or final response
  - Loop until no more tool calls are detected

#### OpenAI Implementation
- **Probe-Based Approach**: OpenAI requires additional handling to achieve
  multi-turn tool calling
- **Challenge**: OpenAI models often stop after making initial tool calls
  instead of continuing the reasoning chain
- **Process Flow**:
  - Send history + messages + tools to OpenAI
  - Process streaming response, collecting tool calls
  - Execute tool calls and add results to conversation
      - If model returns text instead of tool calls, use a "probe" technique:
    - Send an empty user message to prompt for additional tool calls
    - If probe reveals more tool calls, execute them and continue loop
    - If probe confirms no more tool calls, we're done
    - Cache and selectively process post-probe responses:
      - For tool calls: stream cached text and process normally
      - For text-only: discard completely (don't stream or add to history)

#### Cross-Provider Compatibility
- Tool call/result IDs are maintained consistently across providers
- Message history with tool calls can be transferred between providers
- FIFO (First-In, First-Out) matching of tool calls and results ensures correct
  pairing

### Streaming Considerations
All text responses are streamed out from the Agent as they come in from the LLM.
For post-probe responses, we implement special buffering logic:
- The entire response is cached without streaming
- If the cached response contains tool calls:
  - Stream the cached text (if any)
  - Process tool calls normally
  - Continue the conversation flow
- If the cached response contains only text:
  - Discard the text completely
  - Don't add anything to message history
  - Exit as if the response never happened

### Future Optimizations
A future optimization would be to skip the probe message entirely when an Agent has no tools configured. Since there would be no possibility of additional tool calls in this scenario, the probe step would be unnecessary overhead.

This implementation enables complex multi-step reasoning chains like:
```dart
// Example: Calendar assistant that needs multiple tool calls
final agent = Agent(
  'google',
  systemPrompt: 'You are a helpful calendar assistant.',
  tools: [
    Tool(name: 'get-current-date-time', ...),
    Tool(name: 'get-calendar-schedule', ...),
  ],
);

// With a single prompt, the agent will:
// 1. Call get-current-date-time to determine today's date
// 2. Use that result to call get-calendar-schedule with the correct date
// 3. Return a final response incorporating all information
final response = await agent.run("What's on my schedule today?");
```

## Milestones

### Milestone 1: Core Agent Functionality
- [x] Agent creation via model string (e.g., `openai:gpt-4o`) or provider
  instance (e.g., `OpenAiProvider()`).
- [x] Running prompts and returning string outputs (`Agent.run`).
- [x] Running prompts and returning typed outputs (`Agent.runFor`).
- [x] DotPrompt support for structured prompt input (`Agent.runPrompt`).
- [x] Provider resolution and abstraction (OpenAI, Gemini, etc.).
- [x] Output mapping via `outputFromJson` for typed results.
- [x] Passing system prompts to models.

### Milestone 2: Multi-turn Chat, Streaming
- [x] **Streaming responses**: LLM responses can be streamed via
  `Agent.runStream`, `Agent.runPromptStream`, and similar methods, all of which
  return a `Stream<AgentResponse>`. This allows real-time consumption of output
  as it's generated. Streaming is a core, stable feature of the API, and is the
  primary way to consume real-time output from the agent. Note: `Agent.run`
  returns a `Future<AgentResponse>` with the full response, not a stream.

  ```dart
  // Example of streaming with Agent.runStream
  import 'dart:io';
  import 'package:dartantic_ai/dartantic_ai.dart';

  void main() async {
    final agent = Agent('openai:gpt-4o');
    final stream = agent.runStream('Tell me a short story about a brave robot.');
    await for (final response in stream) {
      stdout.write(response.output);
    }
  }
  ```
- [x] **Multi-turn chat**: The system supports passing a list of `Message`
  objects (with roles: system, user, model, etc.) to the agent for
  context-aware, conversational LLM interactions.
  - The `Message` class supports roles (`system`, `user`, `model`) and content
    parts (including text and media).
  - The `Agent.runStream` and related methods accept a `messages` parameter,
    which is a list of `Message` objects representing the conversation history.
  - The agent ensures that the prompt and message history are included in the
    request, and the response includes the updated message history.
  - Tests verify that when an empty message history is provided, the agent
    includes both the user prompt and the model response in the resulting
    message list.

- [x] **Tool calls and provider switching**: Tool calls are supported and
  threaded through message history, including across provider boundaries (OpenAI
  <-> Gemini). Tool call/result IDs are now stable and compatible, allowing
  seamless cross-provider chat and tool usage. Tests verify that tool calls and
  results are present in the message history and that provider switching works
  as expected.

- [x] **API changes**:
  - `AgentResponse` includes the full message history after each response.
  - The `Agent` interface supports chat-like workflows by accepting and
    returning message lists.
  - The `Message` class supports serialization/deserialization for easy storage
    and replay of conversations.

- [x] **Provider-specific implementations**:
  - OpenAI: Maps `Message` to OpenAI chat API, supports streaming and tool
    calls.
  - Gemini: Maps `Message` to Gemini API, supports streaming and tool calls,
    with cross-provider message history compatibility.

- [x] **Testing**:
  - Integration tests cover streaming, multi-turn chat, tool calls, typed
    output, and provider switching (including cross-provider tool call/result
    threading).

**Summary of current status:**  
- Multi-turn chat, streaming, message roles, and content types are fully
  implemented and tested.
- Tool calls and provider switching (OpenAI <-> Gemini) are implemented and
  tested, with stable tool call/result IDs across providers.
- Message history serialization/deserialization is provider-agnostic and robust.
- Remaining gaps: advanced agent loop (auto tool loop until schema is
  satisfied), multi-media input as prompt, and some advanced error handling.


### Milestone 3: RAG and Embedding Support
- [x] **Embedding generation**: Add methods to generate vector embeddings for
  text:
  - `Future<Float64List> createEmbedding(String text, {EmbeddingType type})`
  - Introduce `EmbeddingType` enum (document, query).
  - `Agent.cosineSimilarity()` static method for comparing embeddings.
  - Comprehensive integration tests covering both OpenAI and Gemini providers.

### Milestone 4: Message API Convenience Methods
- [x] **Enhanced Message Construction**: Added convenience methods to simplify
  message and content creation:
  - `Content` type alias for `List<Part>` to improve readability and semantic
    clarity.
  - Convenience constructors for `Message` class:
    - `Message.system(Content content)` - Creates system messages
    - `Message.user(Content content)` - Creates user messages  
    - `Message.model(Content content)` - Creates model messages
  - `Content.text(String text)` extension method to easily create text-only
    content.
  - Convenience constructors for `ToolPart` class:
    - `ToolPart.call({required String id, required String name, Map<String,
      dynamic> arguments})` - Creates tool calls
    - `ToolPart.result({required String id, required String name, Map<String,
      dynamic> result})` - Creates tool results
  - These methods significantly reduce boilerplate when working with messages,
    making the API more ergonomic for common use cases like creating simple text
    messages or tool interactions.

### Milestone 5: MCP Server Support
- [x] **MCP (Model Context Protocol) Server Integration**: Add support for
  connecting to MCP servers to extend Agent capabilities with external tools:
  - `McpClient` class with factory constructors for local and remote servers:
    - `McpClient.local()` - Connect to local MCP servers via stdio
    - `McpClient.remote()` - Connect to remote MCP servers via HTTP
  - `Future<List<Tool>> getTools()` method to discover and convert MCP tools to
    Agent Tools
  - Lazy connection pattern - servers connect automatically on first tool use
  - Support for both stdio transport (local processes) and HTTP transport
    (remote servers)
  - Users combine MCP tools with local tools before creating Agent:
    ```dart
    final mcpClient = McpClient.local(
      'filesystem-server',
      command: 'filesystem-server',
    );
    final mcpTools = await mcpClient.getTools();
    final agent = Agent('google', tools: [...localTools, ...mcpTools]);
    ```
  - Proper resource management with `disconnect()` method for cleanup
  - Type-safe tool execution - MCP tools return `Map<String, dynamic>` like
    local tools
  - Agent initialization remains synchronous while MCP tool discovery is async
  - Comprehensive integration tests with live remote MCP server (Hugging Face)
    verify connection, tool discovery, execution, error handling, and Agent
    integration

### Milestone 6: Logging and Instrumentation
- [x] **Logging Support**: Implemented structured logging using the standard
  Dart `logging` package for debugging and monitoring:
  - Users can configure logging by setting up listeners:
    ```dart
    import 'package:logging/logging.dart';
    
    // Configure logging to see dartantic_ai internal operations
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
    ```

### Milestone 7: Provider Capabilities System
- [x] **Provider Capability Declaration and Reporting**: Add support for
  providers to declare their capabilities and allow the system to query what
  features are available:
  - `ProviderCaps` enum defining capability types:
    - `textGeneration` - Provider supports text generation/chat
    - `embeddings` - Provider supports embedding generation  
    - `chat` - Provider supports conversational interactions
    - `fileUploads` - Provider supports file/media uploads
    - `tools` - Provider supports tool calls
  - `Provider` interface extended with `caps` property returning
    `Iterable<ProviderCaps>`
  - `Agent` property to check capabilities:
    - `Iterable<ProviderCaps> caps` - Get all capabilities of current provider
  - Graceful degradation when operations aren't supported:
    - Clear error messages indicating which capabilities are missing
    - Ability to test for capabilities before attempting operations
    - Provider-specific capability documentation
  - Integration tests verify capability reporting across all providers (OpenAI,
    Gemini, OpenRouter, etc.)
  - Examples showing how to check capabilities and handle unsupported operations
    gracefully

### Milestone 8: Dartantic provider for Flutter AI Toolkit
- [ ] Implement the `LlmProvider` interface in terms of `Agent`

### Milestone 9: Multi-media input and output
- [x] **Multi-media input support**: Added `attachments` parameter to Agent and
  Model interfaces for including files, images, and other media:
  - `Agent.runStream()`, `Agent.run()`, and related methods accept `attachments:
    Content` parameter
  - `Model.runStream()` interface includes `required Content attachments`
  - Support for text files via `DataPart.file(File('path.txt'))`
  - Support for image files via `DataPart.file(File('image.jpg'))`  
  - Support for web images via `LinkPart(Uri.parse('https://...'))`
  - Both OpenAI and Gemini providers handle multimedia content appropriately
  - Comprehensive examples in `example/bin/multimedia.dart` demonstrate file
    summaries, image descriptions, and visual content analysis

- [ ] **Multi-media output support**: Enable agents to generate multimedia
  content (images, audio, etc.) in addition to text:
  - Update `AgentResponse` to support multimedia content parts in output
  - Support models that can generate images (e.g., DALL-E, Imagen)
  - Support models that can generate audio or other media types
  - Handle multimedia content in message history for multi-turn conversations
  - Examples demonstrating image generation, audio synthesis, etc.

### Milestone 10: Typed Response + Tools + Simple Agent Loop
- [ ] e.g. two tools, typed response and we keep looping till the LLM is done
- Just like pydantic-ai can do!

```python
"""
city_info_demo.py  –  pydantic-ai example with tools + typed output
---------------------------------------------------------------
Given a user-supplied list of city names, the assistant:
  • calls get_time()  – fetches the current local time
  • calls get_temp()  – fetches the current temperature in °C
  • returns a typed list of CityReport objects
The pydantic-ai library auto-loops until the model has filled the
schema without any unresolved tool calls.
"""

import os
import json
import httpx
from typing import List, Optional
from pydantic import BaseModel, Field
from pydantic_ai import OpenAIChat, tool

# --------------------------------------------------------------------
# 1.  Two simple tools (worldtimeapi + open-meteo)
# --------------------------------------------------------------------
# Hard-code lat/lon + timezone for a few demo cities.
CITY_META = {
    "London":     {"lat": 51.5072, "lon": -0.1276, "tz": "Europe/London"},
    "New York":   {"lat": 40.7128, "lon": -74.0060, "tz": "America/New_York"},
    "Tokyo":      {"lat": 35.6895, "lon": 139.6917, "tz": "Asia/Tokyo"},
    "Sydney":     {"lat": -33.8688, "lon": 151.2093, "tz": "Australia/Sydney"},
}

@tool(name="get_time",
      description="Return the current local time for a known city.")
def get_time(city: str) -> Optional[str]:
    meta = CITY_META.get(city)
    if not meta:
        return None
    tz = meta["tz"]
    url = f"https://worldtimeapi.org/api/timezone/{tz}"
    try:
        resp = httpx.get(url, timeout=8)
        resp.raise_for_status()
        return resp.json()["datetime"]         # ISO-8601 string
    except Exception:
        return None

@tool(name="get_temp",
      description="Return the current temperature in °C for a known city.")
def get_temp(city: str) -> Optional[float]:
    meta = CITY_META.get(city)
    if not meta:
        return None
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={meta['lat']}&longitude={meta['lon']}"
        "&current_weather=true"
    )
    try:
        resp = httpx.get(url, timeout=8)
        resp.raise_for_status()
        return resp.json()["current_weather"]["temperature"]
    except Exception:
        return None

# --------------------------------------------------------------------
# 2.  Typed response schema
# --------------------------------------------------------------------
class CityReport(BaseModel):
    city: str
    local_time: str = Field(..., description="ISO-8601 local time string")
    temp_c: float   = Field(..., description="Temperature in Celsius")

class CityReportList(BaseModel):
    reports: List[CityReport]

# --------------------------------------------------------------------
# 3.  Build chat task (schema + tools)
# --------------------------------------------------------------------
assistant = OpenAIChat(
    model          = "gpt-4o-mini",     # any GPT-4-class model
    response_model = CityReportList,
    tools          = [get_time, get_temp],
    temperature    = 0.2,
)

# --------------------------------------------------------------------
# 4.  User prompt (cities could come from argv, etc.)
# --------------------------------------------------------------------
CITIES = ["London", "Tokyo", "New York", "Sydney"]

prompt = f"""
You are a helpful assistant.
For each city in this list, return its current local time and temperature:

{', '.join(CITIES)}

• Call get_time(city) and get_temp(city) as needed.
• If a tool returns null, skip that city.
• Respond **only** with JSON that matches the CityReportList schema.
"""

# --------------------------------------------------------------------
# 5.  One call – pydantic-ai auto-loops until typed schema is satisfied
# --------------------------------------------------------------------
city_info: CityReportList = assistant(prompt)
print(json.dumps(city_info.model_dump(), indent=2))
```
