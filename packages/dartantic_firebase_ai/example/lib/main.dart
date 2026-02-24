import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:firebase_ai_example/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Simple chat example using the Firebase AI ChatModel directly.
///
/// Demonstrates low-level streaming without the Agent orchestration layer.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SimpleChatApp());
}

/// Root widget for the simple chat example.
class SimpleChatApp extends StatelessWidget {
  /// Creates the simple chat app.
  const SimpleChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase AI Simple Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const SimpleChatScreen(),
    );
  }
}

/// A minimal chat screen that streams responses from the ChatModel.
class SimpleChatScreen extends StatefulWidget {
  /// Creates the simple chat screen.
  const SimpleChatScreen({super.key});

  @override
  State<SimpleChatScreen> createState() => _SimpleChatScreenState();
}

class _SimpleChatScreenState extends State<SimpleChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _provider = FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
  late final FirebaseAIChatModel _chatModel;

  String _streamingText = '';
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _chatModel = _provider.createChatModel(
      name: 'gemini-2.5-flash',
    ) as FirebaseAIChatModel;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatModel.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    _controller.clear();
    setState(() {
      _messages.add(ChatMessage.user(text));
      _streamingText = '';
      _isStreaming = true;
    });
    _scrollToBottom();

    final buffer = StringBuffer();
    await for (final chunk in _chatModel.sendStream(_messages)) {
      final delta = chunk.output.text;
      buffer.write(delta);
      setState(() => _streamingText = buffer.toString());
      _scrollToBottom();
    }

    setState(() {
      _messages.add(ChatMessage.model(buffer.toString()));
      _streamingText = '';
      _isStreaming = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase AI Simple Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_streamingText.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _MessageBubble(message: _messages[index]);
                }
                return _MessageBubble(
                  message: ChatMessage.model(_streamingText),
                  isStreaming: true,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isStreaming,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isStreaming ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.isStreaming = false});

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.parts.text),
      ),
    );
  }
}
