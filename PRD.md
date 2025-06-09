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
- As a developer, I want to support both OpenAI and Gemini models, and easily
  switch between them.

## Requirements
### Functional
- The system MUST support agent creation via both model string and provider
  instance.
- The system MUST support running prompts and returning streaming string outputs.
- The system MUST support running prompts and returning typed outputs, using a
  provided schema and fromJson function.
- The system MUST support defining tools with typed input (validated via JSON
  schema) and output.
- The system MUST support automatic schema generation for tool inputs/outputs
  using annotations (e.g., SotiSchema, JsonSerializable).
- The system MUST support both OpenAI and Gemini providers, with API keys loaded
  from environment variables.
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
- [x] Agents can run prompts and return typed outputs, mapped to custom Dart types.
- [x] Agents can use DotPrompt for structured prompt input.
- [ ] Agents can define and use tools with typed input/output, validated via JSON schema.
- [x] The system supports both OpenAI and Gemini providers, with API keys loaded from environment variables.
- [x] The system provides clear error messages for missing API keys or unsupported providers.
- [x] Integration tests pass for all major features, including:
  - Basic agent usage (string and typed output)
  - JSON schema output
  - Tool usage (time, temperature, etc.)
  - Provider switching (OpenAI, Gemini)
  - DotPrompt usage 

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
- [ ] **Multi-turn chat**: Add support for passing a list of `ChatMessage`
  objects (with roles: system, user, assistant, tool, function) to the agent for
  context-aware, conversational LLM interactions.
  - Introduce `ChatMessageRole` enum and `ChatMessage` class with role, content,
    and optional tool/function fields.
  - Update `Agent` and provider interfaces to accept and process message
    history.
  - Update `AgentResponse` to return message history.
  - [ ] **API changes**:
  - Extend `AgentResponse` to include the full message history.
  - Add new methods to `Agent` for chat, streaming, and embedding.
- [ ] **Provider-specific implementations**:
  - OpenAI: Map `ChatMessage` to OpenAI chat API, support streaming and
    embedding endpoints.
  - Gemini: Map `ChatMessage` to Gemini API, support streaming if available, and
    implement embedding (or throw if not supported).

### Milestone 3: Multi-media input
- [ ] `Model.runStream` should take a `Message` as a prompt, so that it can
  include media parts
- [ ] `Agent.runXxx()` should be updated to support a prompt message, including
  multi-media parts

### Milestone 4: Dartantic provider for Flutter AI Toolkit
- [ ] Implement the `LlmProvider` interface in terms of `Agent`

### Milestone 5: RAG and Embedding Support
- [ ] **Embedding generation**: Add methods to generate vector embeddings for
  text:
  - `Future<List<double>> createEmbedding(String text, {EmbeddingType type})`
  - Introduce `EmbeddingType` enum (document, query).

### Milestone 6: Typed Response + Tools + Simple Agent Loop
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
