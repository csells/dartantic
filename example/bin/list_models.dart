// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  for (final providerName in ProviderTable.providers.keys) {
    final provider = Agent.providerFor(providerName);
    final aliasOrName = provider.alias ?? provider.name;
    print('\n# Provider: $aliasOrName');
    assert(aliasOrName == providerName);
    try {
      final models = await provider.listModels();
      for (final model in models) {
        print('- Model: ${model.name}');
        print('  - Kind: ${model.kind}');
        print('  - Provider: ${model.providerName}');
      }
    } on Exception catch (e) {
      print('Exception: $e');
      // waiting on https://github.com/davidmigloz/langchain_dart/issues/734
      // ignore: avoid_catching_errors
    } on Error catch (e) {
      print('Error: $e');
    }
  }
}
