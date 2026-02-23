import 'package:dartantic_interface/dartantic_interface.dart';

import '../agent/orchestrators/streaming_orchestrator.dart';

/// Interface for chat models that provide orchestrators.
abstract interface class ChatOrchestratorProvider {
  /// Selects the appropriate orchestrator and tools for this model.
  ///
  /// The tools list may be modified by the provider, e.g. Anthropic injects
  /// the return_result tool for typed output.
  ///
  /// [hasServerSideTools] indicates whether provider-specific server-side tools
  /// (like Google Search or Code Execution) are configured. This affects
  /// orchestrator selection since server-side tools may require special
  /// handling with typed output.
  (StreamingOrchestrator, List<Tool>?) getChatOrchestratorAndTools({
    required Schema? outputSchema,
    required List<Tool>? tools,
    bool hasServerSideTools = false,
  });
}
