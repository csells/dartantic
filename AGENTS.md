# AGENTS.md

Dartantic is a Dart monorepo for an agentic AI framework with multiple LLM provider integrations. This file is intentionally compact; deep architecture lives in `wiki/Home.md` and `docs/`, and there's a separate `CLAUDE.md` with broader notes.

## Monorepo Layout

Melos workspace declared in the root `pubspec.yaml` (no separate `melos.yaml`):

- `packages/dartantic_interface/` — core types (re-exports `genai_primitives`, `json_schema_builder`)
- `packages/dartantic_ai/` — **primary dev focus**; provider implementations, orchestrators, tests
- `packages/dartantic_firebase_ai/` — Flutter-only; requires `flutter` SDK
- `packages/dartantic_chat/` — Flutter chat UI widgets (fork of `flutter/ai`, BSD-3)
- `samples/dartantic_cli/` — CLI binary at `bin/dartantic.dart`
- `samples/chatarang/` — interactive chat sample
- `examples/` are inside each package (`packages/dartantic_ai/example/bin/` has ~40 entry points)

Toolchain: Dart `^3.10.0`. Flutter pinned via `.fvmrc` to `3.41.2` — use `fvm` if installed.

## Bootstrap

```bash
# From repo root — resolves every workspace package in one shot
dart pub get

# Or, if you have melos on PATH
melos bootstrap
```

Run `dart pub get` per package only if a single package's tooling is out of sync.

## Daily Commands

All run from a specific package directory (not the root, except `dart analyze`/`format` for the whole repo):

```bash
# Tests
cd packages/dartantic_ai && dart test                    # all
cd packages/dartantic_ai && dart test test/chat_test.dart
cd packages/dartantic_ai && dart test -n "pattern"       # by name
cd packages/dartantic_ai && dart test --timeout=10m      # long suites

# Static + format
cd packages/dartantic_ai && dart analyze
cd packages/dartantic_ai && dart format .
cd packages/dartantic_ai && dart format --set-exit-if-changed .

# Examples (CLI examples, see .vscode/launch.json for full list)
cd packages/dartantic_ai && dart run example/bin/single_turn_chat.dart

# Verbose logging for debugging
DARTANTIC_LOG_LEVEL=FINE dart run example/bin/single_turn_chat.dart
# Levels: SEVERE, WARNING, INFO, FINE
```

The shell scripts in `samples/dartantic_cli/example/` and `packages/dartantic_ai/run_all_examples.sh` are bash — on Windows, use Git Bash.

## API Keys

Integration tests and most examples call real providers. Required env vars: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, `MISTRAL_API_KEY`, `COHERE_API_KEY`, `OPENROUTER_API_KEY`, `XAI_API_KEY`. Ollama is local and needs none.

Resolution order (see `wiki/Agent-Config-Spec.md`):
1. `Agent.environment[name]` map (programmatic, works in Flutter web)
2. `~/global_env.sh` shell source
3. Process environment

Tests **silently skip** providers whose API keys are missing — failures only show up if you expect coverage from that provider.

## Testing Conventions

- Helper: `runProviderTest(desc, fn, {requiredCaps, edgeCase})` in `packages/dartantic_ai/test/test_helpers/run_provider.dart`. `edgeCase: true` restricts to Google to avoid timeouts.
- Per-provider capabilities are declared in the `providerTestCaps` map in the same file. New providers must be added there.
- Every test file starts with a `TESTING PHILOSOPHY` doc comment (see `wiki/Test-Spec.md`).
- **Do not** add `try/catch` to swallow errors in tests, examples, or production code — let exceptions surface.
- Each functionality area is tested in **exactly one** file; check for an existing test before creating a new one.
- Mock tools and helpers live in `test/test_tools.dart` and `test/test_utils.dart`.
- Use `tmp/` at repo root for scratch test files (gitignored).
- Dartantic Chat tests live in `packages/dartantic_chat/test/` and run via `flutter test`.

## Adding a Provider

1. `lib/src/providers/<name>_provider.dart` extending `Provider`
2. `lib/src/chat_models/<name>_chat/` with the chat model + `_message_mappers.dart` + options
3. Register in `Agent.providerFactories` in `packages/dartantic_ai/lib/src/agent/agent.dart:659`
4. Add to `providerTestCaps` map in `test/test_helpers/run_provider.dart`
5. Every message mapper **must** assert no `ThinkingPart` is in outbound messages (see `wiki/Provider-Implementation-Guide.md`)

## Architecture Cheatsheet

Six layers, top-down: `Agent` (API) → `orchestrators/` → `Provider`/`ChatModel` interfaces in `dartantic_interface` → per-provider implementations → `lib/src/shared/` (logging, retry HTTP, exceptions) → HTTP clients.

Tool results are always consolidated into **one** user message, never split. Thinking parts consolidate to a single `ThinkingPart` per message; final consolidated text part comes before the thinking part. The `AgentResponseAccumulator` filters streaming-only `ThinkingPart`-only messages but preserves the consolidated model message with its provider-specific signature metadata (`_anthropic_thinking_signature`, `_google_thought_signatures`).

## Style / Lint

- `all_lint_rules_community` with overrides in each `analysis_options.yaml`. `public_member_api_docs: true` is enforced — add doc comments to new public APIs.
- 80-column width, single quotes (override in `analysis_options.yaml`).
- `unnecessary_final: false` — finals are encouraged.
- No comments for removed functionality, no placeholder code, no defensive timeouts.

## Things That Will Burn You

- `Agent(providerString)` accepts many formats: `"openai"`, `"openai:gpt-4o"`, `"openai/gpt-4o"`, `"openai?chat=gpt-4o&embeddings=..."` — parsed by `ModelStringParser` in `lib/src/agent/model_string_parser.dart`.
- The `packages/dartantic_ai/example/` is a separate workspace member with its own `build_runner` step (`example/build.sh`) — only needed if you touch the example's codegen.
- `Makefile` only has `serve` (gollum wiki server). No `make test` etc.
- `.github/workflows/publish-wiki.yml` mirrors `wiki/` to a separate GitHub wiki on every push to `main` — design docs in `wiki/` should describe architecture, not code.
- `.beads/` is a Gas City dolt-backed issue tracker; ignore unless working on issues (`.beads/config.yaml` has `dolt.auto-start: false`).
- The root `pubspec.lock` exists despite the typical Dart-library `.gitignore` rule — it's committed for this workspace.
