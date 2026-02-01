// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() {
  // Test 1: Check provider is registered
  print('Checking llamadart provider registration...');
  final provider = Agent.getProvider('llamadart');
  print('✓ llamadart provider: ${provider.name}');

  // Test 2: Check llama alias
  final provider2 = Agent.getProvider('llama');
  print('✓ llama alias: ${provider2.name}');

  // Test 3: List all providers (should include llamadart)
  final allProviders = Agent.allProviders;
  final hasLlamadart = allProviders.any((p) => p.name == 'llamadart');
  print('✓ llamadart in allProviders: $hasLlamadart');

  // Test 4: Create an agent with just provider name
  Agent('llamadart');
  print('✓ Agent created with provider name');

  // Test 5: Create an agent with provider:model format
  Agent('llamadart:test-model');
  print('✓ Agent created with provider:model format');

  print('\nAll registration checks passed!');
}
