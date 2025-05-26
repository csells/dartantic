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
- The system MUST support running prompts and returning string outputs.
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
- [ ] Agents can be created using both model strings and provider instances.
- [ ] Agents can run prompts and return string outputs.
- [ ] Agents can run prompts and return typed outputs, mapped to custom Dart types.
- [ ] Agents can use DotPrompt for structured prompt input.
- [ ] Agents can define and use tools with typed input/output, validated via JSON schema.
- [ ] The system supports both OpenAI and Gemini providers, with API keys loaded from environment variables.
- [ ] The system provides clear error messages for missing API keys or unsupported providers.
- [ ] Integration tests pass for all major features, including:
  - Basic agent usage (string and typed output)
  - JSON schema output
  - Tool usage (time, temperature, etc.)
  - Provider switching (OpenAI, Gemini)
  - DotPrompt usage 

## Milestones

### Milestone 1: Core Agent Functionality (Implemented)
- Agent creation via model string (e.g., `openai:gpt-4o`) or provider instance
  (e.g., `OpenAiProvider()`).
- Running prompts and returning string outputs (`Agent.run`).
- Running prompts and returning typed outputs (`Agent.runFor`).
- DotPrompt support for structured prompt input (`Agent.runPrompt`).
- Provider resolution and abstraction (OpenAI, Gemini, etc.).
- Output mapping via `outputFromJson` for typed results.
- Passing system prompts to models.

### Milestone 2: Multi-turn Chat, Streaming, and Embedding Support
- **Multi-turn chat**: Add support for passing a list of `ChatMessage` objects
  (with roles: system, user, assistant, tool, function) to the agent for
  context-aware, conversational LLM interactions.
  - Introduce `ChatMessageRole` enum and `ChatMessage` class with role, content,
    and optional tool/function fields.
  - Update `Agent` and provider interfaces to accept and process message
    history.
- **Streaming responses**: Add support for streaming LLM responses via a
  `Stream<AgentResponse>` API, allowing real-time consumption of output as it is
  generated.
- **Embedding generation**: Add methods to generate vector embeddings for text:
  - `Future<List<double>> createEmbedding(String text, {EmbeddingType type})`
  - `Future<List<List<double>>> createEmbeddings(List<String> texts,
    {EmbeddingType type})`
  - Introduce `EmbeddingType` enum (document, query).
- **API changes**:
  - Extend `AgentResponse` to include the full message history.
  - Add new methods to `Agent` for chat, streaming, and embedding.
- **Provider-specific implementations**:
  - OpenAI: Map `ChatMessage` to OpenAI chat API, support streaming and
    embedding endpoints.
  - Gemini: Map `ChatMessage` to Gemini API, support streaming if available, and
    implement embedding (or throw if not supported).
- **Testing & Documentation**:
  - Add tests for multi-turn chat, streaming, and embedding APIs.
  - Update documentation and usage examples to cover new features.

