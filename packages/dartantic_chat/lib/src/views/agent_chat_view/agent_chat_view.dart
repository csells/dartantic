// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/widgets.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_dialog.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../llm_exception.dart';
import '../../platform_helper/platform_helper.dart' as ph;
import '../../providers/interface/chat_history_provider.dart';
import '../../styles/chat_view_style.dart';
import '../chat_history_view.dart';
import '../chat_input/chat_input.dart';
import '../response_builder.dart';
import 'agent_response.dart';

/// A widget that displays a chat interface for interacting with an AI agent.
///
/// This widget provides a complete chat interface, including a message history
/// view and an input area for sending new messages. It is configured with a
/// [ChatHistoryProvider] to manage the chat interactions.
///
/// Example usage:
/// ```dart
/// AgentChatView(
///   provider: MyProvider(),
///   style: ChatViewStyle(
///     backgroundColor: Colors.white,
///     // ... other style properties
///   ),
/// )
/// ```
@immutable
class AgentChatView extends StatefulWidget {
  /// Creates an [AgentChatView] widget.
  ///
  /// This widget provides a chat interface for interacting with an AI agent.
  /// It requires a [ChatHistoryProvider] to manage the chat interactions and
  /// can be customized with various style and configuration options.
  ///
  /// - [provider]: The [ChatHistoryProvider] that manages the chat
  ///   interactions.
  /// - [style]: Optional. The [ChatViewStyle] to customize the appearance of
  ///   the chat interface.
  /// - [responseBuilder]: Optional. A custom [ResponseBuilder] to handle the
  ///   display of agent responses.
  /// - [messageSender]: Optional. A custom [ChatStreamGenerator] to handle the
  ///   sending of messages. If provided, this is used instead of the
  ///   `sendMessageStream` method of the provider. It's the responsibility of
  ///   the caller to ensure that the [messageSender] properly streams the
  ///   response. This is useful for augmenting the user's prompt with
  ///   additional information, in the case of prompt engineering or RAG. It's
  ///   also useful for simple logging.
  /// - [suggestions]: Optional. A list of predefined suggestions to display
  ///   when the chat history is empty. Defaults to an empty list.
  /// - [welcomeMessage]: Optional. A welcome message to display when the chat
  ///   is first opened.
  /// - [onCancelCallback]: Optional. The action to perform when the user
  ///   cancels a chat operation. By default, a snackbar is displayed with the
  ///   canceled message.
  /// - [onErrorCallback]: Optional. The action to perform when an
  ///   error occurs during a chat operation. By default, an alert dialog is
  ///   displayed with the error message.
  /// - [cancelMessage]: Optional. The message to display when the user cancels
  ///   a chat operation. Defaults to 'CANCEL'.
  /// - [errorMessage]: Optional. The message to display when an error occurs
  ///   during a chat operation. Defaults to 'ERROR'.
  /// - [enableAttachments]: Optional. Whether to enable file and image
  ///   attachments in the chat input.
  /// - [enableVoiceNotes]: Optional. Whether to enable voice notes in the chat
  ///   input.
  AgentChatView({
    required ChatHistoryProvider provider,
    ChatViewStyle? style,
    ResponseBuilder? responseBuilder,
    ChatStreamGenerator? messageSender,
    List<String> suggestions = const [],
    String? welcomeMessage,
    this.onCancelCallback,
    this.onErrorCallback,
    this.cancelMessage = 'CANCEL',
    this.errorMessage = 'ERROR',
    this.enableAttachments = true,
    this.enableVoiceNotes = true,
    this.autofocus,
    super.key,
  }) : viewModel = ChatViewModel(
         provider: provider,
         responseBuilder: responseBuilder,
         messageSender: messageSender,
         style: style,
         suggestions: suggestions,
         welcomeMessage: welcomeMessage,
         enableAttachments: enableAttachments,
         enableVoiceNotes: enableVoiceNotes,
       );

  /// Whether to enable file and image attachments in the chat input.
  ///
  /// When set to false, the attachment button and related functionality will be
  /// disabled.
  final bool enableAttachments;

  /// Whether to enable voice notes in the chat input.
  ///
  /// When set to false, the voice recording button and related functionality
  /// will be disabled.
  final bool enableVoiceNotes;

  /// The view model containing the chat state and configuration.
  ///
  /// This [ChatViewModel] instance holds the provider, transcript,
  /// response builder, welcome message, and icon for the chat interface.
  /// It encapsulates the core data and functionality needed for the chat view.
  late final ChatViewModel viewModel;

  /// The action to perform when the user cancels a chat operation.
  ///
  /// By default, a snackbar is displayed with the canceled message.
  final void Function(BuildContext context)? onCancelCallback;

  /// The action to perform when an error occurs during a chat operation.
  ///
  /// By default, an alert dialog is displayed with the error message.
  final void Function(BuildContext context, LlmException error)?
  onErrorCallback;

  /// The text message to display when the user cancels a chat operation.
  ///
  /// Defaults to 'CANCEL'.
  final String cancelMessage;

  /// The text message to display when an error occurs during a chat operation.
  ///
  /// Defaults to 'ERROR'.
  final String errorMessage;

  /// Whether to autofocus the chat input field when the view is displayed.
  ///
  /// Defaults to `null`, which means it will be determined based on the
  /// presence of suggestions. If there are no suggestions, the input field
  /// will be focused automatically.
  final bool? autofocus;

  @override
  State<AgentChatView> createState() => _AgentChatViewState();
}

class _AgentChatViewState extends State<AgentChatView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  AgentResponse? _pendingPromptResponse;
  ChatMessage? _initialMessage;
  ChatMessage? _associatedResponse;
  AgentResponse? _pendingSttResponse;

  @override
  void initState() {
    super.initState();
    widget.viewModel.provider.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    super.dispose();
    widget.viewModel.provider.removeListener(_onHistoryChanged);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // for AutomaticKeepAliveClientMixin

    final chatStyle = ChatViewStyle.resolve(widget.viewModel.style);
    return ListenableBuilder(
      listenable: widget.viewModel.provider,
      builder: (context, child) => ChatViewModelProvider(
        viewModel: widget.viewModel,
        child: GestureDetector(
          onTap: () {
            // Dismiss keyboard when tapping anywhere in the view
            FocusScope.of(context).unfocus();
          },
          child: Container(
            color: chatStyle.backgroundColor,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ChatHistoryView(
                        // can only edit if we're not waiting on the agent or if
                        // we're not already editing an agent response
                        onEditMessage:
                            _pendingPromptResponse == null &&
                                _associatedResponse == null
                            ? _onEditMessage
                            : null,
                        onSelectSuggestion: _onSelectSuggestion,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: ChatInput(
                    initialMessage: _initialMessage,
                    autofocus:
                        widget.autofocus ??
                        widget.viewModel.suggestions.isEmpty,
                    onCancelEdit: _associatedResponse != null
                        ? _onCancelEdit
                        : null,
                    onSendMessage: _onSendMessage,
                    onCancelMessage: _pendingPromptResponse == null
                        ? null
                        : _onCancelMessage,
                    onTranslateStt: _onTranslateStt,
                    onCancelStt: _pendingSttResponse == null
                        ? null
                        : _onCancelStt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSendMessage(String prompt, Iterable<Part> attachments) async {
    _initialMessage = null;
    _associatedResponse = null;

    // check the viewmodel for a user-provided message sender to use instead
    final sendMessageStream =
        widget.viewModel.messageSender ??
        widget.viewModel.provider.sendMessageStream;

    _pendingPromptResponse = AgentResponse(
      stream: sendMessageStream(prompt, attachments: attachments),
      // update during the streaming response input so that the end-user can see
      // the response as it streams in
      onUpdate: (_) => setState(() {}),
      onDone: _onPromptDone,
    );

    setState(() {});
  }

  void _onPromptDone(LlmException? error) {
    setState(() => _pendingPromptResponse = null);
    unawaited(_showLlmException(error));
  }

  void _onCancelMessage() => _pendingPromptResponse?.cancel();

  void _onEditMessage(ChatMessage message) {
    assert(_pendingPromptResponse == null);

    // remove the last model message
    final history = widget.viewModel.provider.history.toList();
    assert(history.last.role == ChatMessageRole.model);
    final modelMessage = history.removeLast();

    // remove the last user message
    assert(history.last.role == ChatMessageRole.user);
    final userMessage = history.removeLast();

    // set the history to the new history
    widget.viewModel.provider.history = history;

    // set the text to the last userMessage to provide initial prompt and
    // attachments for the user to edit
    setState(() {
      _initialMessage = userMessage;
      _associatedResponse = modelMessage;
    });
  }

  Future<void> _onTranslateStt(
    XFile file,
    Iterable<Part> currentAttachments,
  ) async {
    assert(widget.enableVoiceNotes);
    _initialMessage = null;
    _associatedResponse = null;

    final response = StringBuffer();
    _pendingSttResponse = AgentResponse(
      stream: widget.viewModel.provider.transcribeAudio(file),
      onUpdate: (text) => response.write(text),
      onDone: (error) async => _onSttDone(
        error,
        response.toString().trim(),
        file,
        currentAttachments,
      ),
    );

    setState(() {});
  }

  Future<void> _onSttDone(
    LlmException? error,
    String response,
    XFile file,
    Iterable<Part> attachments,
  ) async {
    assert(_pendingSttResponse != null);
    setState(() {
      // Preserve any existing attachments from the current input
      _initialMessage = ChatMessage.user(response, parts: attachments.toList());
      _pendingSttResponse = null;
    });

    // delete the file now that the agent has translated it
    unawaited(ph.deleteFile(file));

    // show any error that occurred
    unawaited(_showLlmException(error));
  }

  void _onCancelStt() => _pendingSttResponse?.cancel();

  Future<void> _showLlmException(LlmException? error) async {
    if (error == null) return;

    switch (error) {
      case LlmCancelException():
        if (widget.onCancelCallback != null) {
          widget.onCancelCallback!(context);
        } else {
          AdaptiveSnackBar.show(context, 'Operation canceled by user');
        }
        break;
      case LlmFailureException():
      case LlmException():
        if (widget.onErrorCallback != null) {
          widget.onErrorCallback!(context, error);
        } else {
          await AdaptiveAlertDialog.show(
            context: context,
            content: Text(error.toString()),
            showOK: true,
          );
        }
    }
  }

  void _onSelectSuggestion(String suggestion) => _onSendMessage(suggestion, []);

  void _onHistoryChanged() {
    // if the history is cleared, clear the initial message
    if (widget.viewModel.provider.history.isEmpty) {
      setState(() {
        _initialMessage = null;
        _associatedResponse = null;
      });
    }
  }

  void _onCancelEdit() {
    assert(_initialMessage != null);
    assert(_associatedResponse != null);

    // add the original message and response back to the history
    final history = widget.viewModel.provider.history.toList();
    history.addAll([_initialMessage!, _associatedResponse!]);
    widget.viewModel.provider.history = history;

    setState(() {
      _initialMessage = null;
      _associatedResponse = null;
    });
  }
}
