# AGENT.md - dartantic_ai Development Guide

## Commands
- **Test**: `dart test` (all tests), `dart test test/dartantic_ai_test.dart`
  (single file)
- **Lint**: Included in `package:all_lint_rules_community/all.yaml` 
- **Format**: `dart format .`
- **Build**: `dart pub get` (no compilation step for library)

## Architecture
- **Agent Layer**: `Agent` class orchestrates all functionality, uses providers
  to create models
- **Provider Layer**: `Provider` interface + `ProviderTable` factory (OpenAI,
  Gemini)
- **Model Layer**: `Model` interface for running prompts and creating embeddings
- **Tool Layer**: `Tool` class for typed external functions with JSON schema
  validation
- **Message Layer**: `Message`/`Part` system for multi-turn conversations and
  content types

## Code Style & Conventions
- **Immutability**: Prefer `final` fields, builder pattern with named parameters
- **Types**: Explicit typing via JSON schema, fromJson functions,
  `JsonSerializable` annotations, prefer types to `dynamic`
- **Syntax**: Prefer for expressions over `map().toList()`, switch expressions
  over switch statements
- **Formatting**: Generate code to fit into 80 columns
- **Exceptions**: Catch expressions should use on to specific exception types
  but NOT catch Error objects; an unhandled Error object represents an issue
  that should be fixed.

## MCP Servers
When in doubt, take advantage of these MCP servers:
- **dart-mcp-server**: Use when looking up information about Dart packages
- **deepwiki**: Use when looking up implementation details about any GitHub repo
