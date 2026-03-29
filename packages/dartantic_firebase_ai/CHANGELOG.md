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
