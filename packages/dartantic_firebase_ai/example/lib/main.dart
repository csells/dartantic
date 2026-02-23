import 'package:flutter/material.dart';
import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase AI Provider Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final List<String> _logs = [];
  bool _providerReady = false;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  void _initializeProvider() {
    setState(() {
      _logs.add('🚀 Initializing Firebase AI Provider...');
    });

    try {
      // Register Firebase AI providers with new naming
      Agent.providerFactories['firebase-vertex'] = () =>
          FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
      Agent.providerFactories['firebase-google'] = () =>
          FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);

      setState(() {
        _logs.add('✅ FirebaseAIProvider registered successfully');
        _logs.add('✅ Vertex AI provider available as: firebase-vertex');
        _logs.add('✅ Google AI provider available as: firebase-google');
        _logs.add('✅ Supports model: gemini-2.0-flash-exp');
        _logs.add('✅ Capabilities: chatVision');
        _providerReady = true;
      });

      // Test agent creation
      _testAgentCreation();
    } catch (e) {
      setState(() {
        _logs.add('❌ Provider registration failed: $e');
      });
    }
  }

  void _testAgentCreation() {
    try {
      // Create agent with Firebase AI (using Vertex AI backend)
      final agent = Agent('firebase-vertex:gemini-2.0-flash-exp');

      setState(() {
        _logs.add('🎯 Agent created successfully!');
        _logs.add('✅ Model: firebase-vertex:gemini-2.0-flash-exp');
        _logs.add('✅ Ready for chat operations');
        _logs.add('✅ Agent instance: ${agent.runtimeType}');
        _logs.add('');
        _logs.add('📋 Provider Integration Status:');
        _logs.add('• Provider: ✅ Registered');
        _logs.add('• Agent: ✅ Created');
        _logs.add('• Configuration: ✅ Complete');
        _logs.add('');
        _logs.add('💡 In a real app with Firebase configured,');
        _logs.add('   you would call agent.sendStream(prompt)');
        _logs.add('   to get AI responses!');
      });
    } catch (e) {
      setState(() {
        _logs.add('❌ Agent creation failed: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase AI Provider Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _providerReady ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _providerReady
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          color: _providerReady ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Provider Status',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _providerReady
                          ? 'Firebase AI Provider is ready!'
                          : 'Initializing...',
                      style: TextStyle(
                        color: _providerReady
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Initialization Log:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _logs
                          .map(
                            (log) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Text(
                                log,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Steps:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Configure Firebase in your project'),
                    const Text('2. Add Firebase credentials'),
                    const Text(
                      '3. Call agent.sendStream(prompt) for AI responses',
                    ),
                    const Text('4. Handle streaming responses in your UI'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
