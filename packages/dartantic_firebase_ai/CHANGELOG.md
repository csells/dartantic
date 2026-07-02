## 0.2.2

- Updated Firebase SDK, `dartantic_interface`, `meta`, `uuid`, and test
  dependency constraints to current compatible releases.
- Added targeted `deprecated_member_use` ignores for Firebase AI App Check and
  Auth constructor parameters while retaining the existing integration behavior.

## 0.2.1

- Fix `mapFinishReason` to handle new Firebase AI SDK finish reasons without a
  non-exhaustive switch expression warning.

## 0.2.0

- Requires `dartantic_interface` ^4.0.0 (`ModelKind.video` and related discovery
  updates). See the `dartantic_interface` 4.0.0 changelog if you switch
  exhaustively on `ModelKind`.

## 0.1.0

- Initial release of `dartantic_firebase_ai`, a Flutter-only Firebase AI provider
  for `dartantic_ai`.
- **Backends:** Google AI (Gemini Developer API via Firebase) for development,
  and Vertex AI via Firebase for production.
- **Chat:** Streaming chat, tool calling, extended thinking, structured output,
  and vision inputs aligned with Dartantic’s provider model.
- **Media:** Media generation model and options for Firebase AI image output.
- **Security (Vertex AI):** Integrates with Firebase App Check and Firebase Auth
  where applicable.
- **Safety:** Configurable safety settings via `FirebaseAiSafetyOptions`.
- Public API: `FirebaseAiProvider`, `FirebaseAiChatModel`, chat and media
  generation options, and message mappers for the Firebase AI SDK.
