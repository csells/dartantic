/// Constants related to typed output functionality.
///
/// These constants are placed in the shared layer to avoid circular
/// dependencies between the providers layer and orchestrators layer.
library;

/// The name of Anthropic's return_result tool used for typed output.
///
/// This constant is used by:
/// - `AnthropicProvider` to inject the tool
/// - `AnthropicTypedOutputOrchestrator` to detect the tool call
const String kAnthropicReturnResultTool = 'return_result';
