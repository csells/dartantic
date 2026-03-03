import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as a;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart' show WhereNotNullExtension;

import '../../shared/anthropic_thinking_metadata.dart';
import '../helpers/message_part_helpers.dart';
import 'anthropic_chat.dart';
import 'anthropic_server_side_tool_types.dart';
import 'anthropic_tool_event_state.dart';

final Logger _logger = Logger('dartantic.chat.mappers.anthropic');

// Anthropic's default for Claude 3.5 Sonnet and similar models
const _defaultMaxTokens = 4096;
const _defaultThinkingBudgetTokens = 4096;
const _defaultMaxTokensWithThinking = 8192; // Room for thinking + response

/// Calculates the appropriate maxTokens value.
///
/// When thinking is enabled, ensures maxTokens is large enough to accommodate
/// both the thinking budget and the response.
/// Defaults to 4096 tokens (Anthropic's default for modern Claude models).
int _calculateMaxTokens({
  required AnthropicChatOptions? options,
  required AnthropicChatOptions defaultOptions,
  required a.ThinkingConfig? thinkingConfig,
}) {
  // If maxTokens is explicitly set, use it
  if (options?.maxTokens != null) return options!.maxTokens!;
  if (defaultOptions.maxTokens != null) return defaultOptions.maxTokens!;

  // If thinking is enabled, use larger default
  if (thinkingConfig != null) {
    return _defaultMaxTokensWithThinking;
  }

  // Otherwise use Anthropic's default for modern Claude models
  return _defaultMaxTokens;
}

/// Builds the ThinkingConfig from options, or null if thinking is disabled.
///
/// If thinkingBudgetTokens is not specified, uses a reasonable default.
/// The Anthropic SDK will validate constraints (minimum, maximum, etc.).
a.ThinkingConfig? _buildThinkingConfig(
  bool enableThinking,
  AnthropicChatOptions? options,
  AnthropicChatOptions defaultOptions,
) {
  if (!enableThinking) return null;

  // Get explicit budget if provided, otherwise use our default
  // Let Anthropic SDK validate the actual constraints
  final budgetTokens =
      options?.thinkingBudgetTokens ??
      defaultOptions.thinkingBudgetTokens ??
      _defaultThinkingBudgetTokens;

  return a.ThinkingConfig.enabled(budgetTokens: budgetTokens);
}

/// Maps a server tool config to an appropriate SDK tool definition.
///
/// Server-side tools (code_execution, web_search, etc.) require special
/// handling because they should NOT include `input_schema` in the API request.
a.ToolDefinition _mapServerToolConfig(AnthropicServerToolConfig config) {
  // Use SDK's built-in WebSearchTool for web search
  if (config.type.startsWith('web_search_')) {
    return a.ToolDefinition.builtIn(a.BuiltInTool.webSearch());
  }

  // Use SDK's CodeExecutionTool for code execution
  if (config.type.startsWith('code_execution_')) {
    return a.ToolDefinition.custom(_ServerTool(type: config.type));
  }

  // For other server tools (web_fetch, etc.), use a wrapper that serializes
  // without input_schema
  return a.ToolDefinition.custom(
    _ServerTool(type: config.type, name: config.name),
  );
}

/// A tool wrapper for server-side tools that don't require input_schema.
///
/// This extends [a.Tool] and overrides [toJson] to exclude the input_schema
/// field, which is required for server-side tools like code_execution and
/// web_fetch.
class _ServerTool extends a.Tool {
  /// Creates a server tool with the given type and optional name.
  _ServerTool({required String type, String? name})
    : super(
        type: type,
        name: name ?? _nameFromType(type),
        inputSchema: const a.InputSchema(properties: {}),
      );

  static String _nameFromType(String type) {
    // Extract base name from versioned type (e.g., code_execution_20250825 ->
    // code_execution)
    final match = RegExp(r'^(.+?)_\d+$').firstMatch(type);
    return match?.group(1) ?? type;
  }

  @override
  Map<String, dynamic> toJson() => {'type': type, 'name': name};
}

/// Creates an Anthropic [a.MessageCreateRequest] from a list of messages and
/// options.
a.MessageCreateRequest createMessageRequest(
  List<ChatMessage> messages, {
  required String modelName,
  required bool enableThinking,
  required AnthropicChatOptions? options,
  required AnthropicChatOptions defaultOptions,
  List<Tool>? tools,
  double? temperature,
  Schema? outputSchema,
}) {
  // Handle tools
  final hasTools = tools != null && tools.isNotEmpty;

  final systemMsg = messages.firstOrNull?.role == ChatMessageRole.system
      ? (messages.firstOrNull!.parts.firstOrNull as TextPart?)?.text
      : null;

  final structuredTools = hasTools ? tools.toTool() : null;
  final manualServerToolConfigs =
      options?.serverTools ?? defaultOptions.serverTools;
  final serverSideToolSet =
      options?.serverSideTools ?? defaultOptions.serverSideTools;
  final mergedServerToolConfigs = mergeAnthropicServerToolConfigs(
    manualConfigs: manualServerToolConfigs,
    serverSideTools: serverSideToolSet,
  );
  final serverTools = mergedServerToolConfigs
      .map(_mapServerToolConfig)
      .toList();
  final hasServerTools = serverTools.isNotEmpty;

  _logger.fine(
    'Creating Anthropic message request for ${messages.length} messages',
  );
  final messagesDtos = messages.toMessages();

  _logger.fine(
    'Tool configuration: hasTools=$hasTools, toolCount=${tools?.length ?? 0}',
  );

  // Build thinking config first to check if thinking is enabled
  final thinkingConfig = _buildThinkingConfig(
    enableThinking,
    options,
    defaultOptions,
  );

  // Calculate appropriate maxTokens based on whether thinking is enabled
  final maxTokens = _calculateMaxTokens(
    options: options,
    defaultOptions: defaultOptions,
    thinkingConfig: thinkingConfig,
  );

  final allTools = <a.ToolDefinition>[
    ...serverTools,
    if (structuredTools != null) ...structuredTools,
  ];
  final resolvedToolChoice = _resolveToolChoice(
    options: options,
    defaultOptions: defaultOptions,
    hasStructuredTools: structuredTools != null,
    hasServerTools: hasServerTools,
  );

  return a.MessageCreateRequest(
    model: modelName,
    messages: messagesDtos,
    maxTokens: maxTokens,
    stopSequences: options?.stopSequences ?? defaultOptions.stopSequences,
    system: systemMsg != null ? a.SystemPrompt.text(systemMsg) : null,
    temperature:
        temperature ?? options?.temperature ?? defaultOptions.temperature,
    topK: options?.topK ?? defaultOptions.topK,
    topP: options?.topP ?? defaultOptions.topP,
    metadata: a.Metadata(userId: options?.userId ?? defaultOptions.userId),
    tools: allTools.isEmpty ? null : allTools,
    toolChoice: resolvedToolChoice,
    thinking: thinkingConfig,
  );
}

a.ToolChoice? _resolveToolChoice({
  required AnthropicChatOptions? options,
  required AnthropicChatOptions defaultOptions,
  required bool hasStructuredTools,
  required bool hasServerTools,
}) {
  final toolChoice = options?.toolChoice ?? defaultOptions.toolChoice;

  if (toolChoice == null) {
    if (!hasStructuredTools && !hasServerTools) return null;
    return a.ToolChoice.auto();
  }

  switch (toolChoice.type) {
    case AnthropicToolChoiceType.auto:
      return a.ToolChoice.auto();
    case AnthropicToolChoiceType.any:
      return a.ToolChoice.any();
    case AnthropicToolChoiceType.required:
      final name = toolChoice.name;
      if (name == null || name.isEmpty) {
        throw ArgumentError(
          'AnthropicToolChoice.required requires a non-empty tool name.',
        );
      }
      return a.ToolChoice.tool(name);
  }
}

/// Extension on [List<msg.Message>] to convert messages to Anthropic SDK
/// messages.
extension MessageListMapper on List<ChatMessage> {
  /// Converts this list of [ChatMessage]s to a list of Anthropic SDK
  /// [a.InputMessage]s.
  ///
  /// Note: Unlike other providers, Anthropic REQUIRES thinking blocks to be
  /// sent back in multi-turn conversations when extended thinking is enabled.
  /// ThinkingPart is converted to thinking blocks here, with the signature
  /// retrieved from message metadata.
  List<a.InputMessage> toMessages() {
    _logger.fine('Converting $length messages to Anthropic format');
    final result = <a.InputMessage>[];
    final consecutiveToolMessages = <ChatMessage>[];

    void flushToolMessages() {
      if (consecutiveToolMessages.isNotEmpty) {
        _logger.fine(
          'Flushing ${consecutiveToolMessages.length} '
          'consecutive tool messages',
        );
        result.add(_mapToolMessages(consecutiveToolMessages));
        consecutiveToolMessages.clear();
      }
    }

    for (final message in this) {
      switch (message.role) {
        case ChatMessageRole.system:
          flushToolMessages();
          continue; // System message set in request params
        case ChatMessageRole.user:
          // Check if this is a tool result message
          if (message.parts.whereType<ToolPart>().isNotEmpty) {
            _logger.fine(
              'Adding user message with tool parts to consecutive tool '
              'messages',
            );
            consecutiveToolMessages.add(message);
          } else {
            flushToolMessages();
            final res = _mapUserMessage(message);
            result.add(res);
          }
        case ChatMessageRole.model:
          flushToolMessages();
          final res = _mapModelMessage(message);
          result.add(res);
      }
    }

    flushToolMessages(); // Flush any remaining tool messages
    return result;
  }

  a.InputMessage _mapUserMessage(ChatMessage message) {
    final textParts = message.parts.whereType<TextPart>().toList();
    final dataParts = message.parts.whereType<DataPart>().toList();
    _logger.fine(
      'Mapping user message: ${textParts.length} text parts, '
      '${dataParts.length} data parts',
    );

    if (dataParts.isEmpty) {
      // Text-only message
      final text = message.parts.text;
      if (text.isEmpty) {
        throw ArgumentError(
          'User message cannot have empty content. '
          'Message parts: ${message.parts}',
        );
      }
      return a.InputMessage.user(text);
    } else {
      // Multimodal message
      final blocks = <a.InputContentBlock>[];

      for (final part in message.parts) {
        if (part is TextPart) {
          blocks.add(a.InputContentBlock.text(part.text));
        } else if (part is DataPart) {
          blocks.add(_mapDataPartToBlock(part));
        }
      }

      return a.InputMessage.userBlocks(blocks);
    }
  }

  a.InputContentBlock _mapDataPartToBlock(DataPart dataPart) {
    if (dataPart.mimeType.startsWith('image/')) {
      // Images: Use native image blocks for better quality
      return a.InputContentBlock.image(
        a.ImageSource.base64(
          mediaType: switch (dataPart.mimeType) {
            'image/jpeg' => a.ImageMediaType.jpeg,
            'image/png' => a.ImageMediaType.png,
            'image/gif' => a.ImageMediaType.gif,
            'image/webp' => a.ImageMediaType.webp,
            _ => throw AssertionError(
              'Unsupported image MIME type: ${dataPart.mimeType}',
            ),
          },
          data: base64Encode(dataPart.bytes),
        ),
      );
    } else {
      // Non-images: Use dartantic_ai format as text
      final base64Data = base64Encode(dataPart.bytes);
      return a.InputContentBlock.text(
        '[media: ${dataPart.mimeType}] '
        'data:${dataPart.mimeType};base64,$base64Data',
      );
    }
  }

  a.InputMessage _mapModelMessage(ChatMessage message) {
    final textParts = message.parts.whereType<TextPart>().toList();
    final toolParts = message.parts.whereType<ToolPart>().toList();
    final thinkingParts = message.parts.whereType<ThinkingPart>().toList();
    _logger.fine(
      'Mapping model message: ${textParts.length} text parts, '
      '${toolParts.length} tool parts, ${thinkingParts.length} thinking parts',
    );

    if (toolParts.isEmpty && thinkingParts.isEmpty) {
      // Text-only response (no tools, no thinking)
      final text = message.parts.text;
      if (text.isEmpty && message.parts.isNotEmpty) {
        throw ArgumentError(
          'Assistant message has empty text content. '
          'Message parts: ${message.parts}',
        );
      }
      return a.InputMessage.assistant(text);
    } else {
      // Response with tool calls and/or thinking
      final blocks = <a.InputContentBlock>[];

      // Thinking blocks are not sent back to the API. The API handles
      // thinking continuity internally when the thinking config is enabled.
      final thinkingSignature = AnthropicThinkingMetadata.getSignature(
        message.metadata,
      );
      _logger.fine(
        'Model message metadata keys: ${message.metadata.keys}; '
        'thinking signature present: ${thinkingSignature != null}',
      );

      // Add tool_use blocks
      blocks.addAll(
        toolParts.map(
          (toolPart) => a.InputContentBlock.toolUse(
            id: toolPart.callId,
            name: toolPart.toolName,
            input: toolPart.arguments ?? {},
          ),
        ),
      );

      return a.InputMessage.assistantBlocks(blocks);
    }
  }

  a.InputMessage _mapToolMessages(List<ChatMessage> messages) {
    _logger.fine(
      'Mapping ${messages.length} tool messages to Anthropic blocks',
    );
    final blocks = <a.InputContentBlock>[];

    for (final message in messages) {
      for (final part in message.parts) {
        if (part is ToolPart && part.kind == ToolPartKind.result) {
          blocks.add(
            a.InputContentBlock.toolResult(
              toolUseId: part.callId,
              content: [
                a.ToolResultContent.text(
                  ToolResultHelpers.serialize(part.result),
                ),
              ],
            ),
          );
        }
      }
    }

    return a.InputMessage.userBlocks(blocks);
  }
}

/// Extension on [a.Message] to convert an Anthropic SDK message to a
/// [ChatResult].
extension MessageMapper on a.Message {
  /// Converts this Anthropic SDK [a.Message] to a [ChatResult].
  ChatResult<ChatMessage> toChatResult() {
    final parts = _mapMessageContent(content);
    final message = ChatMessage(role: ChatMessageRole.model, parts: parts);
    _logger.fine(
      'Converting Anthropic message to ChatResult with ${parts.length} parts',
    );

    return ChatResult<ChatMessage>(
      id: id,
      output: message,
      messages: [message],
      finishReason: _mapFinishReason(stopReason),
      metadata: {'model': model, 'stop_sequence': stopSequence},
      usage: _mapUsage(usage),
    );
  }
}

/// A [StreamTransformer] that converts a stream of Anthropic
/// [a.MessageStreamEvent]s into [ChatResult]s.
class MessageStreamEventTransformer
    extends
        StreamTransformerBase<a.MessageStreamEvent, ChatResult<ChatMessage>> {
  /// Creates a [MessageStreamEventTransformer].
  MessageStreamEventTransformer();

  /// Aggregated server-side tool event state for the current message.
  final AnthropicEventMappingState _toolState = AnthropicEventMappingState();

  /// The last message ID.
  String? lastMessageId;

  /// Map of content block index -> tool call ID.
  final Map<int, String> _toolCallIdByIndex = {};

  /// Map of content block index -> tool name.
  final Map<int, String> _toolNameByIndex = {};

  /// Accumulator for tool arguments during streaming (by content block index).
  final Map<int, StringBuffer> _toolArgumentsByIndex = {};

  /// Seed arguments captured from ToolUseBlock.start when provided fully.
  final Map<int, Map<String, dynamic>> _toolSeedArgsByIndex = {};

  /// Tracks content block indices associated with Anthropic server-side tools.
  final Set<int> _serverToolIndices = <int>{};

  /// Tracks server-side tool use IDs (e.g., code execution invocations).
  final Set<String> _serverToolUseIds = <String>{};

  /// Maps content block indices to server-side tool use IDs.
  final Map<int, String> _serverToolIdByIndex = <int, String>{};

  /// Records server-side tool names keyed by tool use ID.
  final Map<String, String> _serverToolNamesById = <String, String>{};

  /// Stores raw tool payloads before normalization.
  final Map<String, Map<String, Object?>> _rawToolContentById =
      <String, Map<String, Object?>>{};

  /// Accumulator for thinking content during streaming.
  final StringBuffer _thinkingBuffer = StringBuffer();

  /// Signature from the thinking block (if present).
  String? _thinkingSignature;

  /// Whether the current message included any tool calls.
  bool _messageHasToolCalls = false;

  /// Records a signature delta emitted when thinking is enabled with tools.
  void recordSignatureDelta(String signature) {
    if (signature.isEmpty) {
      return;
    }
    _thinkingSignature = signature;
  }

  /// Registers the raw payload emitted for a server-side tool call.
  void registerRawToolContent(String toolUseId, Map<String, Object?> raw) {
    _rawToolContentById[toolUseId] = Map<String, Object?>.from(raw);
  }

  /// Binds this transformer to a stream of [a.MessageStreamEvent]s, producing a
  /// stream of [ChatResult]s.
  @override
  Stream<ChatResult<ChatMessage>> bind(Stream<a.MessageStreamEvent> stream) =>
      stream
          .map(
            (event) => switch (event) {
              final a.MessageStartEvent e => _mapMessageStartEvent(e),
              final a.MessageDeltaEvent e => _mapMessageDeltaEvent(e),
              final a.ContentBlockStartEvent e => _mapContentBlockStartEvent(e),
              final a.ContentBlockDeltaEvent e => _mapContentBlockDeltaEvent(e),
              final a.ContentBlockStopEvent e => _mapContentBlockStopEvent(e),
              final a.MessageStopEvent e => _mapMessageStopEvent(e),
              a.PingEvent() => null,
              a.ErrorEvent() => null,
            },
          )
          .whereNotNull();

  ChatResult<ChatMessage> _mapMessageStartEvent(a.MessageStartEvent e) {
    final message = e.message;

    final msgId = message.id;
    lastMessageId = msgId;
    final parts = _mapMessageContent(e.message.content);
    _logger.fine(
      'Processing message start event: messageId=$msgId, parts=${parts.length}',
    );

    return ChatResult<ChatMessage>(
      id: msgId,
      output: ChatMessage(role: ChatMessageRole.model, parts: parts),
      messages: [ChatMessage(role: ChatMessageRole.model, parts: parts)],
      finishReason: _mapFinishReason(e.message.stopReason),
      metadata: {
        'model': e.message.model,
        if (e.message.stopSequence != null)
          'stop_sequence': e.message.stopSequence,
      },
      usage: _mapUsage(e.message.usage),
    );
  }

  ChatResult<ChatMessage> _mapMessageDeltaEvent(a.MessageDeltaEvent e) {
    final metadata = <String, dynamic>{
      if (e.delta.stopSequence != null) 'stop_sequence': e.delta.stopSequence,
    };
    final containerId = _extractContainerId(e.delta);
    if (containerId != null) metadata['container_id'] = containerId;

    // When there's a stop reason, include aggregated tool metadata since all
    // content blocks have completed by this point. This ensures the "complete"
    // chunk has the full tool metadata.
    final finishReason = _mapFinishReason(e.delta.stopReason);
    if (finishReason != FinishReason.unspecified) {
      metadata.addAll(_toolState.toMetadata());
    }

    return ChatResult<ChatMessage>(
      id: lastMessageId,
      output: ChatMessage(role: ChatMessageRole.model, parts: const []),
      messages: const [],
      finishReason: finishReason,
      metadata: metadata,
      usage: _mapMessageDeltaUsage(e.usage),
    );
  }

  ChatResult<ChatMessage> _mapContentBlockStartEvent(
    a.ContentBlockStartEvent e,
  ) {
    final cb = e.contentBlock;

    if (cb is a.ToolUseBlock) {
      if (_isServerToolName(cb.name)) {
        _serverToolIndices.add(e.index);
        _serverToolUseIds.add(cb.id);
        _serverToolIdByIndex[e.index] = cb.id;
        _serverToolNamesById[cb.id] = cb.name;

        return _buildServerToolMetadataChunk({
          'type': 'server_tool_use',
          'tool_use_id': cb.id,
          'tool_name': cb.name,
          'input': cb.input,
        });
      }

      _toolCallIdByIndex[e.index] = cb.id;
      _toolNameByIndex[e.index] = cb.name;
      _messageHasToolCalls = true;

      final input = cb.input;
      if (input.isNotEmpty) {
        _toolSeedArgsByIndex[e.index] = Map<String, dynamic>.from(input);
      }

      return ChatResult<ChatMessage>(
        id: lastMessageId,
        output: ChatMessage(role: ChatMessageRole.model, parts: const []),
        messages: const [],
        finishReason: FinishReason.unspecified,
        metadata: const {},
        usage: null,
      );
    }

    // Handle web search tool result blocks
    if (cb is a.WebSearchToolResultBlock &&
        _serverToolUseIds.contains(cb.toolUseId)) {
      final rawPayload = _rawToolContentById.remove(cb.toolUseId);
      final contentJson = rawPayload ?? cb.content.toJson();
      final event = <String, Object?>{
        'type': 'tool_result',
        'tool_use_id': cb.toolUseId,
        'tool_name': _serverToolNamesById[cb.toolUseId] ?? cb.toolUseId,
        'content': contentJson,
        if (rawPayload != null) 'raw_content': rawPayload,
      };

      final toolKey =
          (event['tool_name'] as String?) ??
          AnthropicServerToolTypes.codeExecution;

      // For web_fetch, extract DataParts from the content structure
      final webFetchParts = _isWebFetchTool(cb.toolUseId)
          ? _extractWebFetchDataParts(contentJson)
          : const <Part>[];

      final outputMessage = webFetchParts.isEmpty
          ? null
          : ChatMessage(role: ChatMessageRole.model, parts: webFetchParts);
      final messageList = outputMessage != null ? [outputMessage] : null;
      return _buildToolMetadataChunk(
        toolKey: toolKey,
        event: event,
        output: outputMessage,
        messages: messageList,
      );
    }

    final parts = _mapContentBlock(cb);
    _logger.fine(
      'Processing content block start event: index=${e.index}, '
      'parts=${parts.length}, contentBlock=$cb',
    );

    if (cb is a.ThinkingBlock) {
      _thinkingSignature = cb.signature.isNotEmpty ? cb.signature : null;
    }

    return ChatResult<ChatMessage>(
      id: lastMessageId,
      output: ChatMessage(role: ChatMessageRole.model, parts: parts),
      messages: [ChatMessage(role: ChatMessageRole.model, parts: parts)],
      finishReason: FinishReason.unspecified,
      metadata: const {},
      usage: null,
    );
  }

  String? _extractContainerId(a.MessageDelta delta) {
    try {
      final dynamic json = delta.toJson();
      if (json is Map<String, Object?>) {
        final container = json['container'];
        if (container is Map<String, Object?>) {
          final id = container['id'];
          if (id is String && id.isNotEmpty) {
            return id;
          }
        }
        final containerId = json['container_id'];
        if (containerId is String && containerId.isNotEmpty) {
          return containerId;
        }
      }
    } on Object catch (e) {
      // Container ID is optional metadata, so we log and continue
      _logger.fine('Failed to extract container ID from delta: $e');
    }
    return null;
  }

  ChatResult<ChatMessage> _mapContentBlockDeltaEvent(
    a.ContentBlockDeltaEvent e,
  ) {
    if (_serverToolIndices.contains(e.index) && e.delta is a.InputJsonDelta) {
      final delta = e.delta as a.InputJsonDelta;
      final toolUseId = _serverToolIdByIndex[e.index];
      final event = <String, Object?>{
        'type': 'server_tool_input_delta',
        'tool_use_id': toolUseId,
        'partial_json': delta.partialJson,
      };
      if (toolUseId != null) {
        final toolName = _serverToolNamesById[toolUseId];
        if (toolName != null) event['tool_name'] = toolName;
      }
      final toolKey =
          (event['tool_name'] as String?) ??
          AnthropicServerToolTypes.codeExecution;
      return _buildToolMetadataChunk(toolKey: toolKey, event: event);
    }

    // Handle ThinkingBlockDelta to accumulate thinking and emit as ThinkingPart
    if (e.delta is a.ThinkingDelta) {
      final delta = e.delta as a.ThinkingDelta;
      _thinkingBuffer.write(delta.thinking);
      _logger.fine('ThinkingDelta: "${delta.thinking}"');

      return ChatResult<ChatMessage>(
        id: lastMessageId,
        output: ChatMessage(
          role: ChatMessageRole.model,
          parts: [ThinkingPart(delta.thinking)],
        ),
        messages: const [],
        finishReason: FinishReason.unspecified,
        metadata: const {},
        usage: null,
      );
    }

    // Handle InputJsonDelta specially to accumulate arguments
    if (e.delta is a.InputJsonDelta &&
        _toolCallIdByIndex.containsKey(e.index)) {
      final delta = e.delta as a.InputJsonDelta;
      _toolArgumentsByIndex.putIfAbsent(e.index, StringBuffer.new);
      _toolArgumentsByIndex[e.index]!.write(delta.partialJson);

      // If we start receiving deltas, prefer them over any seeded args
      if (_toolSeedArgsByIndex.containsKey(e.index)) {
        _toolSeedArgsByIndex.remove(e.index);
      }

      // Return empty result for accumulation
      return ChatResult<ChatMessage>(
        id: lastMessageId,
        output: ChatMessage(role: ChatMessageRole.model, parts: const []),
        messages: const [],
        finishReason: FinishReason.unspecified,
        metadata: const {},
        usage: null,
      );
    }

    final parts = _mapContentBlockDelta(_toolCallIdByIndex[e.index], e.delta);
    _logger.fine(
      'Processing content block delta event: index=${e.index}, '
      'parts=${parts.length}',
    );
    return ChatResult<ChatMessage>(
      id: lastMessageId,
      output: ChatMessage(role: ChatMessageRole.model, parts: parts),
      messages: [ChatMessage(role: ChatMessageRole.model, parts: parts)],
      finishReason: FinishReason.unspecified,
      metadata: const {},
      usage: null,
    );
  }

  ChatResult<ChatMessage>? _mapContentBlockStopEvent(
    a.ContentBlockStopEvent e,
  ) {
    if (_serverToolIndices.remove(e.index)) {
      final toolUseId = _serverToolIdByIndex.remove(e.index);
      final toolName = toolUseId != null
          ? _serverToolNamesById[toolUseId]
          : null;
      final event = <String, Object?>{
        'type': 'server_tool_use_completed',
        'tool_use_id': toolUseId,
      };
      if (toolName != null) event['tool_name'] = toolName;
      final toolKey = toolName ?? AnthropicServerToolTypes.codeExecution;
      return _buildToolMetadataChunk(toolKey: toolKey, event: event);
    }

    // If we have accumulated arguments for this tool, create a complete tool
    // part
    final toolId = _toolCallIdByIndex.remove(e.index);
    final toolName = _toolNameByIndex.remove(e.index);

    if (toolId != null) {
      final argsBuffer = _toolArgumentsByIndex.remove(e.index);
      final argsJson = argsBuffer?.toString() ?? '';
      final seededArgs = _toolSeedArgsByIndex.remove(e.index);

      // Return a result with the complete tool call
      return ChatResult<ChatMessage>(
        id: lastMessageId,
        output: ChatMessage(
          role: ChatMessageRole.model,
          parts: [
            ToolPart.call(
              callId: toolId,
              toolName: toolName ?? '',
              arguments: argsJson.isNotEmpty
                  ? json.decode(argsJson)
                  : (seededArgs ?? <String, dynamic>{}),
            ),
          ],
        ),
        messages: const [],
        finishReason: FinishReason.unspecified,
        metadata: const {},
        usage: null,
      );
    }

    return null;
  }

  ChatResult<ChatMessage>? _mapMessageStopEvent(a.MessageStopEvent e) {
    // Capture state before clearing
    final thinkingSignature = _thinkingSignature;
    final hasToolCalls = _messageHasToolCalls;
    final toolMetadata = _toolState.toMetadata();

    // Clear all tracking state
    lastMessageId = null;
    _toolCallIdByIndex.clear();
    _toolNameByIndex.clear();
    _toolArgumentsByIndex.clear();
    _toolSeedArgsByIndex.clear();
    _serverToolIndices.clear();
    _serverToolUseIds.clear();
    _serverToolIdByIndex.clear();
    _serverToolNamesById.clear();
    _thinkingBuffer.clear();
    _thinkingSignature = null;
    _messageHasToolCalls = false;
    _toolState.reset();

    // Store signature in metadata only when tool calls are present (for
    // replay). Thinking text was already streamed via ThinkingBlockDelta
    // events, so we only need to emit metadata here.
    final hasSignature =
        thinkingSignature != null && thinkingSignature.isNotEmpty;
    final messageMetadata = hasToolCalls && hasSignature
        ? AnthropicThinkingMetadata.buildMetadata(signature: thinkingSignature)
        : <String, Object?>{};

    // Only emit if we have metadata or tool metadata to pass through.
    // Thinking content was already streamed as ThinkingBlockDelta events and
    // will be accumulated by MessageAccumulator - emitting it again here would
    // cause duplication.
    if (messageMetadata.isEmpty && toolMetadata.isEmpty) {
      return null;
    }

    return ChatResult<ChatMessage>(
      id: lastMessageId,
      output: ChatMessage(
        role: ChatMessageRole.model,
        parts: const [],
        metadata: messageMetadata,
      ),
      messages: const [],
      finishReason: FinishReason.unspecified,
      metadata: toolMetadata,
      usage: null,
    );
  }

  ChatResult<ChatMessage> _buildToolMetadataChunk({
    required String toolKey,
    required Map<String, Object?> event,
    ChatMessage? output,
    List<ChatMessage>? messages,
  }) {
    _toolState.recordToolEvent(toolKey, event);
    return ChatResult<ChatMessage>(
      id: lastMessageId,
      output:
          output ?? ChatMessage(role: ChatMessageRole.model, parts: const []),
      messages: messages ?? const [],
      finishReason: FinishReason.unspecified,
      metadata: {
        toolKey: [Map<String, Object?>.from(event)],
      },
      usage: null,
    );
  }

  ChatResult<ChatMessage> _buildServerToolMetadataChunk(
    Map<String, Object?> event,
  ) {
    final sanitized = Map<String, Object?>.from(event)
      ..removeWhere((_, value) => value == null);

    final toolKey =
        sanitized['tool_name'] as String? ??
        AnthropicServerToolTypes.codeExecution;

    return _buildToolMetadataChunk(toolKey: toolKey, event: sanitized);
  }

  bool _isServerToolName(String name) =>
      name == 'code_execution' ||
      name == 'bash_code_execution' ||
      name == 'text_editor_code_execution' ||
      name == 'web_search' ||
      name == 'web_fetch';

  bool _isWebFetchTool(String? toolUseId) {
    if (toolUseId == null) return false;
    final toolName = _serverToolNamesById[toolUseId];
    return toolName == 'web_fetch';
  }

  /// Extracts DataParts from web_fetch tool result content.
  ///
  /// Web fetch returns content in a nested structure with base64 or text data.
  /// This mirrors the extraction logic in AnthropicToolDeliverableTracker.
  List<Part> _extractWebFetchDataParts(Object? content) {
    if (content is! Map<String, Object?>) return const [];

    final inner = content['content'];
    if (inner is! Map<String, Object?>) return const [];

    // Look for source data in content.content or content.source
    final source =
        (inner['content'] as Map<String, Object?>?) ??
        (inner['source'] as Map<String, Object?>?);
    if (source == null) return const [];

    final sourceType = source['type'] as String?;
    final data = source['data'] as String?;
    final mediaType =
        source['media_type'] as String? ?? source['mediaType'] as String?;

    if (data == null || data.isEmpty) return const [];

    Uint8List? bytes;
    if (sourceType == 'text' || sourceType == null) {
      bytes = Uint8List.fromList(utf8.encode(data));
    } else if (sourceType == 'base64' || sourceType == 'bytes') {
      bytes = base64Decode(data);
    }

    if (bytes == null) return const [];

    final resolvedMime = mediaType ?? 'text/plain';
    final title = inner['title'] as String?;
    final extension = _preferredTextExtension(resolvedMime);
    final sanitizedTitle = title != null && title.trim().isNotEmpty
        ? title.replaceAll(RegExp(r'[\\/:]'), '_')
        : null;
    final baseName = () {
      if (sanitizedTitle != null && sanitizedTitle.isNotEmpty) {
        // Append an extension derived from the MIME type when the title lacks
        // one.
        final hasExtension =
            sanitizedTitle.contains('.') &&
            sanitizedTitle.split('.').last.isNotEmpty;
        if (extension != null && !hasExtension) {
          return '$sanitizedTitle.$extension';
        }
        return sanitizedTitle;
      }
      return extension != null
          ? 'web_fetch_document.$extension'
          : 'web_fetch_document';
    }();

    return [DataPart(bytes, mimeType: resolvedMime, name: baseName)];
  }

  String? _preferredTextExtension(String mimeType) {
    if (mimeType == 'text/plain') return 'txt';
    return PartHelpers.extensionFromMimeType(mimeType);
  }
}

/// Maps a list of Anthropic [a.ContentBlock]s to message parts.
List<Part> _mapMessageContent(List<a.ContentBlock> content) => [
  // Extract text parts from TextBlocks
  ...content.whereType<a.TextBlock>().map((t) => TextPart(t.text)),
  // Do not emit tool use parts here; they stream via block events.
];

/// Maps an Anthropic [a.ContentBlock] to message parts.
List<Part> _mapContentBlock(a.ContentBlock contentBlock) =>
    switch (contentBlock) {
      final a.TextBlock t => [TextPart(t.text)],
      // Do not emit tool use blocks at start; emit at stop with full args.
      final a.ToolUseBlock _ => const [],
      // Server tool use blocks are handled separately via metadata.
      a.ServerToolUseBlock() => const [],
      // Thinking blocks are filtered from message parts (metadata only).
      a.ThinkingBlock() => const [],
      // Redacted thinking blocks are not mapped to parts.
      a.RedactedThinkingBlock() => const [],
      // Web search result blocks are handled separately via metadata.
      a.WebSearchToolResultBlock() => const [],
      // Other server-side tool result blocks are handled via metadata.
      a.WebFetchToolResultBlock() => const [],
      a.CodeExecutionToolResultBlock() => const [],
      a.BashCodeExecutionToolResultBlock() => const [],
      a.TextEditorCodeExecutionToolResultBlock() => const [],
      a.ToolSearchToolResultBlock() => const [],
      a.ContainerUploadBlock() => const [],
      a.CompactionBlock() => const [],
    };

/// Maps an Anthropic [a.ContentBlockDelta] to message parts.
List<Part> _mapContentBlockDelta(
  String? lastToolId,
  a.ContentBlockDelta blockDelta,
) => switch (blockDelta) {
  final a.TextDelta t => [TextPart(t.text)],
  final a.InputJsonDelta _ => const [],
  // Thinking deltas handled in _mapContentBlockDeltaEvent (metadata only).
  a.ThinkingDelta() => const [],
  // Signature deltas are handled separately for thinking block integrity.
  a.SignatureDelta() => const [],
  // Citations deltas are not mapped to parts.
  a.CitationsDelta() => const [],
  // Compaction deltas are not mapped to parts.
  a.CompactionDelta() => const [],
};

/// Extension on [List<Tool>] to convert tool specs to Anthropic SDK tools.
extension ToolSpecListMapper on List<Tool> {
  /// Converts this list of [Tool]s to a list of Anthropic SDK
  /// [a.ToolDefinition]s.
  List<a.ToolDefinition> toTool() {
    _logger.fine('Converting $length tools to Anthropic format');
    return map(_mapTool).toList(growable: false);
  }

  a.ToolDefinition _mapTool(Tool tool) {
    final schemaMap = Map<String, dynamic>.from(tool.inputSchema.value);
    final rawProperties = schemaMap['properties'];
    final properties = rawProperties is Map
        ? Map<String, dynamic>.from(rawProperties)
        : <String, dynamic>{};
    return a.ToolDefinition.custom(
      a.Tool(
        name: tool.name,
        description: tool.description,
        inputSchema: a.InputSchema(
          properties: properties,
          required: (schemaMap['required'] as List?)?.cast<String>(),
        ),
      ),
    );
  }
}

/// Maps an Anthropic [a.StopReason] to a [FinishReason].
FinishReason _mapFinishReason(a.StopReason? reason) => switch (reason) {
  a.StopReason.endTurn => FinishReason.stop,
  a.StopReason.maxTokens => FinishReason.length,
  a.StopReason.stopSequence => FinishReason.stop,
  a.StopReason.toolUse => FinishReason.toolCalls,
  a.StopReason.pauseTurn => FinishReason.stop,
  a.StopReason.refusal => FinishReason.stop,
  a.StopReason.compaction => FinishReason.stop,
  a.StopReason.modelContextWindowExceeded => FinishReason.length,
  null => FinishReason.unspecified,
};

/// Maps Anthropic [a.Usage] to [LanguageModelUsage].
LanguageModelUsage _mapUsage(a.Usage? usage) => LanguageModelUsage(
  promptTokens: usage?.inputTokens,
  responseTokens: usage?.outputTokens,
  totalTokens: usage?.inputTokens != null && usage?.outputTokens != null
      ? usage!.inputTokens + usage.outputTokens
      : null,
);

/// Maps Anthropic [a.MessageDeltaUsage] to [LanguageModelUsage].
LanguageModelUsage _mapMessageDeltaUsage(a.MessageDeltaUsage? usage) =>
    LanguageModelUsage(
      responseTokens: usage?.outputTokens,
      totalTokens: usage?.outputTokens,
    );
