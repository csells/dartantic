/// Server-side tools available for Google (Gemini) models.
enum GoogleServerSideTool {
  /// Google's code execution tool (Python sandbox).
  codeExecution,

  /// Google Search tool (Grounding).
  googleSearch,

  /// Google URL context tool (URL context). Enables the model to query URLs in
  /// the messages to retrieve additional context.
  urlContext,
}
