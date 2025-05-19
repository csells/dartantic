## 0.3.0

- added [dotprompt_dart](https://pub.dev/packages/dotprompt_dart) package
  support via `Agent.runPrompt(DotPrompt prompt)`
- expanded model naming to include "providerName", "providerName:model" or
  "providerName/model", e.g. "openai" or "googleai/gemini-2.0-flash"
- move types specified by `Map<String, dynamic>` to a `JsonSchema` object;
  added `toMap()` extension method to `JsonSchema` and `toSchema` to
  `Map<String, dynamic>` to make going back and forth more convenient.
- move the provider argument to `Agent.provider` as the most flexible case,
  but also the less common one. `Agent()` will contine to take a model string.

## 0.2.0

- Define tools and their inputs/outputs easily
- Automatically generate LLM-specific tool/output schemas
- Allow for a model descriptor string that just contains a family name so
  that the provider can choose the default model.

## 0.1.0

- Multi-Model Support (just Gemini and OpenAI models so far)
- Create agents from model strings (e.g. `openai:gpt-4o`) or typed
  providers (e.g. `GoogleProvider()`)
- Automatically check environment for API key if none is provided (not web
  compatible)
- String output via `Agent.run`
- Typed output via `Agent.runFor`

## 0.0.1

- Initial version.
