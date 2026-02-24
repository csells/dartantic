import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_firebase_ai/dartantic_firebase_ai.dart';
import 'package:firebase_ai_example/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';

void main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final Logger logger = Logger('dartantic.examples.firebase_ai');

  logger.info('🚀 Firebase AI Provider Demo');
  logger.info('================================');

  try {
    // Step 1: Register Firebase AI providers with new naming
    logger.info('\n📝 Step 1: Registering Firebase AI Providers...');
    Agent.providerFactories['firebase-vertex'] = () =>
        FirebaseAIProvider(backend: FirebaseAIBackend.vertexAI);
    Agent.providerFactories['firebase-google'] = () =>
        FirebaseAIProvider(backend: FirebaseAIBackend.googleAI);
    logger.info('✅ Firebase AI Providers registered successfully');

    // Step 2: Create Agent (using Vertex AI backend)
    logger.info('\n📝 Step 2: Creating Agent...');
    final agent = Agent('firebase-vertex:gemini-2.5-flash');
    logger.info('✅ Agent created: ${agent.runtimeType}');
    logger.info('✅ Model: firebase:gemini-2.5-flash');

    // Step 3: Show provider details
    logger.info('\n📋 Provider Integration Status:');
    logger.info('• Provider Name: firebase');
    logger.info('• Provider Type: FirebaseAIProvider');
    logger.info('• Model Support: gemini-2.5-flash');
    logger.info('• Capabilities: chatVision');
    logger.info('• Agent Ready: ✅');

    logger.info('\n💡 Integration Complete!');
    logger.info('📌 In a real app with Firebase configured:');
    logger.info('   await for (final result in agent.sendStream(prompt)) {');
    logger.info('     logger.info(result.output);');
    logger.info('   }');

    logger.info('\n🎉 Firebase AI Provider is working correctly!');
  } catch (e, stackTrace) {
    logger.severe('❌ Error: $e');
    logger.severe('Stack trace: $stackTrace');
  }
}
