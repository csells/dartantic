// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

import '../../chat_view_model/chat_view_model.dart';
import '../../chat_view_model/chat_view_model_provider.dart';
import '../../dialogs/adaptive_snack_bar/adaptive_snack_bar.dart';
import '../../styles/styles.dart';
import 'attachments_action_bar.dart';
import 'attachments_view.dart';
import 'chat_input_constants.dart';
import 'command_menu_controller.dart';
import 'input_button.dart';
import 'input_state.dart';
import 'slash_command_parser.dart';
import 'text_or_audio_input.dart';

/// A widget that provides a chat input interface with support for text input,
/// speech-to-text, and attachments.
@immutable
class ChatInput extends StatefulWidget {
  /// Creates a [ChatInput] widget.
  ///
  /// The [onSendMessage] and [onTranslateStt] parameters are required.
  ///
  /// [initialMessage] can be provided to pre-populate the input field.
  ///
  /// [onCancelMessage] and [onCancelStt] are optional callbacks for cancelling
  /// message submission or speech-to-text translation respectively.
  const ChatInput({
    required this.onSendMessage,
    required this.onTranslateStt,
    required this.attachments,
    required this.onAttachments,
    required this.onRemoveAttachment,
    required this.onClearAttachments,
    required this.onReplaceAttachments,
    this.initialMessage,
    this.onCancelEdit,
    this.onCancelMessage,
    this.onCancelStt,
    this.autofocus = true,
    super.key,
  }) : assert(
         !(onCancelMessage != null && onCancelStt != null),
         'Cannot be submitting a prompt and doing stt at the same time',
       ),
       assert(
         !(onCancelEdit != null && initialMessage == null),
         'Cannot cancel edit of a message if no initial message is provided',
       );

  /// Callback function triggered when a message is sent.
  ///
  /// Takes a [String] for the message text and [`Iterable<Part>`] for
  /// any attachments.
  final void Function(String, Iterable<Part>) onSendMessage;

  /// Callback function triggered when speech-to-text translation is requested.
  ///
  /// Takes an [XFile] representing the audio file to be translated and the
  /// current attachments.
  final void Function(XFile file, Iterable<Part> attachments) onTranslateStt;

  /// The initial message to populate the input field, if any.
  final ChatMessage? initialMessage;

  /// Optional callback function to cancel an ongoing edit of a message, passed
  /// via [initialMessage], that has already received a response. To allow for a
  /// non-destructive edit, if the user cancels the editing of the message, we
  /// call [onCancelEdit] to revert to the original message and response.
  final void Function()? onCancelEdit;

  /// Optional callback function to cancel an ongoing message submission.
  final void Function()? onCancelMessage;

  /// Optional callback function to cancel an ongoing speech-to-text
  /// translation.
  final void Function()? onCancelStt;

  /// Whether the input should automatically focus
  final bool autofocus;

  /// The current list of attachments associated with the message.
  ///
  /// This list contains all the files, images, or other media that have been
  /// attached to the current message. The parent widget is responsible for
  /// maintaining and updating this list.
  final List<Part> attachments;

  /// Callback function called when new attachments are added.
  ///
  /// This is triggered when the user adds attachments through any supported method
  /// (drag and drop, file picker, etc.). The parent widget would update its
  /// state to include these new attachments.
  ///
  /// The [attachments] parameter contains the newly added attachment parts.
  final void Function(Iterable<Part> attachments) onAttachments;

  /// Callback function called when an attachment is removed.
  ///
  /// This is triggered when the user removes a previously added attachment.
  /// The parent widget would update its state to remove the specified attachment.
  ///
  /// The [attachment] parameter specifies which attachment was removed.
  final void Function(Part attachment) onRemoveAttachment;

  /// Callback function called when all attachments should be cleared.
  final VoidCallback onClearAttachments;

  /// Callback function called when attachments should be replaced.
  ///
  /// This is triggered when the user replaces attachments through any supported
  /// method (drag and drop, file picker, etc.). The parent widget would update
  /// its state to replace the attachments.
  ///
  /// The [attachments] parameter contains the newly added attachment parts.
  final ValueChanged<List<DataPart>> onReplaceAttachments;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  // Notes on the way focus works in this widget:
  // - we use a focus node to request focus when the input is submitted or
  //   cancelled
  // - we leave the text field enabled so that it never artifically loses focus
  //   (you can't have focus on a disabled widget)
  // - this means we're not taking back focus after a submission or a
  //   cancellation is complete from another widget in the app that might have
  //   it, e.g. if we attempted to take back focus in didUpdateWidget
  // - this also means that we don't need any complicated logic to request focus
  //   in didUpdateWidget only the first time after a submission or cancellation
  //   that would be required to keep from stealing focus from other widgets in
  //   the app
  // - also, if the user is submitting and they press Enter while inside the
  //   text field, we want to put the focus back in the text field but otherwise
  //   ignore the Enter key; it doesn't make sense for Enter to cancel - they
  //   can use the Cancel button for that.
  // - the reason we need to request focus in the onSubmitted function of the
  //   TextField is because apparently it gives up focus as part of its
  //   implementation somehow (just how is something to discover)
  // - the reason we need to request focus in the implementation of the separate
  //   submit/cancel button is because  clicking on another widget when the
  //   TextField is focused causes it to lose focus (as it should)
  final _focusNode = FocusNode();

  final _textController = TextEditingController();
  final _waveController = WaveformRecorderController();
  final _commandMenuController = CommandMenuController();
  final _actionBarKey = GlobalKey();
  final _textFieldKey = GlobalKey();

  Offset? _menuOffset;
  ChatViewModel? _viewModel;
  ChatInputStyle? _inputStyle;
  ChatViewStyle? _chatStyle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel = ChatViewModelProvider.of(context);
    _chatStyle = ChatViewStyle.resolve(_viewModel!.style);
    _inputStyle = ChatInputStyle.resolve(_viewModel!.style?.chatInputStyle);
  }

  @override
  void didUpdateWidget(ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != null) {
      // Load the initial message's text and attachments when:
      // 1. Starting an edit operation (user clicked edit on a previous message)
      // 2. Receiving transcribed text from speech-to-text (preserves existing
      //    attachments)
      // 3. Selecting a suggestion from the chat interface
      final message = widget.initialMessage!;
      _textController.text = message.text;
      // Extract non-text parts as attachments
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReplaceAttachments(
            message.parts.whereType<DataPart>().toList(),
          );
        }
      });
    } else if (oldWidget.initialMessage != null) {
      // Clear both text and attachments when initialMessage becomes null
      // This happens when the user cancels an edit operation, ensuring
      // the input field returns to a clean state
      _textController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onClearAttachments();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.onKeyEvent = (node, event) => _handleCommandKeyEvent(event);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _waveController.dispose();
    _commandMenuController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _inputStyle!.backgroundColor,
    padding: const EdgeInsets.all(ChatInputConstants.containerPadding),
    child: Column(
      children: [
        AttachmentsView(
          attachments: widget.attachments,
          onRemove: widget.onRemoveAttachment,
        ),
        if (widget.attachments.isNotEmpty)
          const SizedBox(height: ChatInputConstants.attachmentsSpacing),
        ValueListenableBuilder(
          valueListenable: _textController,
          builder: (context, value, child) => ListenableBuilder(
            listenable: Listenable.merge([
              _waveController,
              _commandMenuController,
            ]),
            builder: (context, child) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_viewModel!.enableAttachments)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: ChatInputConstants.actionButtonBottomPadding,
                    ),
                    child: AttachmentActionBar(
                      key: _actionBarKey,
                      onAttachments: widget.onAttachments,
                      commandMenuController: _commandMenuController,
                      menuOffset: _menuOffset,
                      onSelection: _clearCommandText,
                    ),
                  ),
                Expanded(
                  child: TextOrAudioInput(
                    inputStyle: _inputStyle!,
                    waveController: _waveController,
                    onCancelEdit: widget.onCancelEdit,
                    onRecordingStopped: onRecordingStopped,
                    onSubmitPrompt: onSubmitPrompt,
                    textController: _textController,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    inputState: _inputState,
                    cancelButtonStyle: _chatStyle!.cancelButtonStyle!,
                    voiceNoteRecorderStyle: _chatStyle!.voiceNoteRecorderStyle!,
                    onAttachments: widget.onAttachments,
                    key: _textFieldKey,
                    allowSubmit: !_commandMenuController.isOpen,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: ChatInputConstants.actionButtonBottomPadding,
                  ),
                  child: InputButton(
                    inputState: _inputState,
                    chatStyle: _chatStyle!,
                    onSubmitPrompt: onSubmitPrompt,
                    onCancelPrompt: onCancelPrompt,
                    onStartRecording: onStartRecording,
                    onStopRecording: onStopRecording,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  InputState get _inputState {
    if (_waveController.isRecording) return InputState.isRecording;
    if (widget.onCancelMessage != null) return InputState.canCancelPrompt;
    if (widget.onCancelStt != null) return InputState.canCancelStt;
    if (_textController.text.trim().isEmpty) {
      return _viewModel!.enableVoiceNotes
          ? InputState.canStt
          : InputState.disabled;
    }
    return InputState.canSubmitPrompt;
  }

  void onSubmitPrompt() {
    assert(_inputState == InputState.canSubmitPrompt);

    // the mobile vkb can still cause a submission even if there is no text
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    widget.onSendMessage(text, List.from(widget.attachments));
    _textController.clear();
    widget.onClearAttachments();
    _focusNode.requestFocus();
  }

  void onCancelPrompt() {
    assert(_inputState == InputState.canCancelPrompt);
    widget.onCancelMessage!();
    _focusNode.requestFocus();
  }

  Future<void> onStartRecording() async {
    await _waveController.startRecording();
  }

  Future<void> onStopRecording() async {
    await _waveController.stopRecording();
  }

  KeyEventResult _handleCommandKeyEvent(KeyEvent event) {
    if (!_commandMenuController.isOpen) return KeyEventResult.ignored;

    final isDownOrRepeat = event is KeyDownEvent || event is KeyRepeatEvent;
    final logicalKey = event.logicalKey;
    final physicalKey = event.physicalKey;

    final isDown =
        logicalKey == LogicalKeyboardKey.arrowDown ||
        physicalKey == PhysicalKeyboardKey.arrowDown;
    final isUp =
        logicalKey == LogicalKeyboardKey.arrowUp ||
        physicalKey == PhysicalKeyboardKey.arrowUp;
    final isEnter =
        logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter ||
        physicalKey == PhysicalKeyboardKey.enter ||
        physicalKey == PhysicalKeyboardKey.numpadEnter;

    // Handle navigation keys (only on Down/Repeat)
    if (isDownOrRepeat) {
      if (isDown) {
        _commandMenuController.selectNext();
        return KeyEventResult.handled;
      } else if (isUp) {
        _commandMenuController.selectPrevious();
        return KeyEventResult.handled;
      } else if (isEnter) {
        _commandMenuController.triggerSelected(onSelection: _clearCommandText);
        return KeyEventResult.handled;
      }
    } else {
      // For Up events, we still want to "handle" Enter so it doesn't leak
      // to the TextField or other listeners.
      if (isEnter) {
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void onRecordingStopped() {
    final file = _waveController.file;

    if (file == null) {
      AdaptiveSnackBar.show(context, 'Unable to record audio');
      return;
    }

    // Pass current attachments to onTranslateStt
    widget.onTranslateStt(file, List.from(widget.attachments));
  }

  // -- Slash command handling --

  void _hideCommandMenu() {
    _commandMenuController.close();
    _menuOffset = null;
  }

  void _onTextChanged() {
    final result = SlashCommandParser.parse(
      _textController.text,
      _textController.selection,
    );

    if (!result.isActive) {
      _hideCommandMenu();
      return;
    }

    _attemptToShowMenuWithOffset(result.slashIndex, result.filterText);
  }

  static const int _maxMenuRetries = 3;

  void _attemptToShowMenuWithOffset(
    int slashIndex,
    String filterText, {
    int retryCount = 0,
  }) {
    final textFieldBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final actionBarBox =
        _actionBarKey.currentContext?.findRenderObject() as RenderBox?;

    if (textFieldBox != null && actionBarBox != null) {
      _calculateMenuOffset(
        TextSelection.collapsed(offset: slashIndex + 1),
        textFieldBox,
        actionBarBox,
      );
      _commandMenuController.open(filterQuery: filterText);
      return;
    }

    _retryOrGiveUp(slashIndex, filterText, retryCount);
  }

  void _retryOrGiveUp(int slashIndex, String filterText, int retryCount) {
    _menuOffset = null;
    if (retryCount >= _maxMenuRetries) {
      assert(
        false,
        'Command menu: render boxes unavailable after $_maxMenuRetries '
        'post-frame retries. Menu will not open.',
      );
      _commandMenuController.close();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Re-validate against current text to detect stale captured values
      final currentResult = SlashCommandParser.parse(
        _textController.text,
        _textController.selection,
      );
      if (!currentResult.isActive || currentResult.slashIndex != slashIndex) {
        _hideCommandMenu();
        return;
      }

      _attemptToShowMenuWithOffset(
        slashIndex,
        currentResult.filterText,
        retryCount: retryCount + 1,
      );
    });
  }

  void _calculateMenuOffset(
    TextSelection selection,
    RenderBox textFieldRenderBox,
    RenderBox actionBarRenderBox,
  ) {
    final textStyle = _inputStyle?.textStyle ?? const TextStyle(fontSize: 14.0);

    final textPainter =
        TextPainter(
          text: TextSpan(
            text: _textController.text.substring(0, selection.baseOffset),
            style: textStyle,
          ),
          textDirection: Directionality.of(context),
          textAlign: TextAlign.start,
          maxLines: null,
        )..layout(
          maxWidth:
              textFieldRenderBox.size.width -
              ChatInputConstants.textOrAudioInputHorizontalPadding -
              ChatInputConstants.chatTextFieldHorizontalPadding,
        );

    final caretOffset = textPainter.getOffsetForCaret(
      TextPosition(offset: selection.baseOffset),
      Rect.zero,
    );

    // Adjust for the padding/alignment within TextOrAudioInput
    final adjustedCaretOffset = Offset(
      caretOffset.dx +
          ChatInputConstants.textOrAudioInputLeftPadding +
          ChatInputConstants.chatTextFieldPadding,
      caretOffset.dy +
          ChatInputConstants.textOrAudioInputBaseTopPadding +
          ChatInputConstants.chatTextFieldVerticalPadding +
          (widget.onCancelEdit != null
              ? ChatInputConstants.textOrAudioInputEditModeAdditionalPadding
              : 0.0),
    );

    final globalCaretPos = textFieldRenderBox.localToGlobal(
      adjustedCaretOffset,
    );
    final localCaretPos = actionBarRenderBox.globalToLocal(globalCaretPos);

    textPainter.dispose();

    setState(() {
      _menuOffset = localCaretPos;
    });
  }

  void _clearCommandText() {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid || selection.baseOffset == 0) return;

    final cursorPos = selection.baseOffset;
    final slashIndex = text.substring(0, cursorPos).lastIndexOf('/');
    if (slashIndex == -1) return;

    _textController.value = SlashCommandParser.clearCommandText(
      text,
      cursorPos,
      slashIndex,
    );
  }
}
