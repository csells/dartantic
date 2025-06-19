// ignore_for_file: avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';

void main() async {
  for (final providerName in ProviderTable.providers.keys) {
    final provider = Agent.providerFor(providerName);
    print('\n# $providerName models');
    final models = await provider.listModels();
    for (final model in models) {
      final kinds = model.kinds.map((k) => k.name).join(', ');
      print(
        '- ${model.providerName}:${model.name} '
        '${model.stable ? '' : '[pre-release] '}'
        '($kinds) ',
      );
    }
  }
}
