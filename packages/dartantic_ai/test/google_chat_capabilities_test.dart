import 'package:dartantic_ai/src/chat_models/google_chat/google_chat_options.dart';
import 'package:dartantic_ai/src/chat_models/google_chat/google_message_mappers.dart';
import 'package:dartantic_ai/src/chat_models/google_chat/google_thinking_config_mapper.dart';
import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:googleai_dart/googleai_dart.dart' as ga;
import 'package:test/test.dart';

void main() {
  group('GenerateContentResponseMapper.toChatResult', () {
    test('maps groundingMetadata into result metadata', () {
      const response = ga.GenerateContentResponse(
        candidates: [
          ga.Candidate(
            content: ga.Content.model([ga.TextPart('answer')]),
            finishReason: ga.FinishReason.stop,
            groundingMetadata: ga.GroundingMetadata(
              webSearchQueries: ['dart lang'],
            ),
          ),
        ],
      );

      final result = response.toChatResult('gemini-test');

      final gm = result.metadata['grounding_metadata'] as Map<String, dynamic>?;
      expect(gm, isNotNull);
      expect(gm!['webSearchQueries'], equals(['dart lang']));
    });
  });

  group('ChatToolListMapper.toToolList', () {
    test(
      'includes fileSearch in tool JSON when only file search is enabled',
      () {
        List<Tool>? noTools;
        final list = noTools.toToolList(
          enableCodeExecution: false,
          enableGoogleSearch: false,
          enableUrlContext: false,
          fileSearch: const ga.FileSearch(
            fileSearchStoreNames: ['fileSearchStores/abc'],
            topK: 3,
            metadataFilter: 'region = us',
          ),
        );

        expect(list, isNotNull);
        final json = list!.single.toJson();
        expect(json['fileSearch'], isA<Map<String, dynamic>>());
        final fs = json['fileSearch']! as Map<String, dynamic>;
        expect(fs['fileSearchStoreNames'], ['fileSearchStores/abc']);
        expect(fs['topK'], 3);
        expect(fs['metadataFilter'], 'region = us');
      },
    );

    test('includes googleMaps in tool JSON when only maps is enabled', () {
      List<Tool>? noTools;
      final list = noTools.toToolList(
        enableCodeExecution: false,
        enableGoogleSearch: false,
        enableUrlContext: false,
        googleMaps: const ga.GoogleMaps(enableWidget: true),
      );

      expect(list, isNotNull);
      final json = list!.single.toJson();
      expect(json['googleMaps'], isA<Map<String, dynamic>>());
      final gm = json['googleMaps']! as Map<String, dynamic>;
      expect(gm['enableWidget'], true);
    });
  });

  group('buildGoogleGenerationThinkingConfig', () {
    test('returns null when thinking disabled and no thinking level', () {
      expect(
        buildGoogleGenerationThinkingConfig(
          enableThinking: false,
          thinkingBudgetTokens: 100,
          thinkingLevel: null,
        ),
        isNull,
      );
    });

    test('thinking level applies without enableThinking', () {
      final config = buildGoogleGenerationThinkingConfig(
        enableThinking: false,
        thinkingBudgetTokens: null,
        thinkingLevel: GoogleThinkingLevel.low,
      );
      expect(config, isNotNull);
      expect(config!.thinkingLevel, ga.ThinkingLevel.low);
      expect(config.thinkingBudget, isNull);
      expect(config.includeThoughts, isNull);
    });

    test('thinking level with enableThinking sets includeThoughts', () {
      final config = buildGoogleGenerationThinkingConfig(
        enableThinking: true,
        thinkingBudgetTokens: null,
        thinkingLevel: GoogleThinkingLevel.high,
      );
      expect(config, isNotNull);
      expect(config!.thinkingLevel, ga.ThinkingLevel.high);
      expect(config.thinkingBudget, isNull);
      expect(config.includeThoughts, true);
    });

    test('uses explicit thinking budget when level is not set', () {
      final config = buildGoogleGenerationThinkingConfig(
        enableThinking: true,
        thinkingBudgetTokens: 2048,
        thinkingLevel: null,
      );
      expect(config!.thinkingBudget, 2048);
      expect(config.thinkingLevel, isNull);
    });

    test('defaults thinking budget to -1 when neither level nor budget', () {
      final config = buildGoogleGenerationThinkingConfig(
        enableThinking: true,
        thinkingBudgetTokens: null,
        thinkingLevel: null,
      );
      expect(config!.thinkingBudget, -1);
    });

    test('throws ArgumentError when both level and budget are set', () {
      expect(
        () => buildGoogleGenerationThinkingConfig(
          enableThinking: false,
          thinkingBudgetTokens: 100,
          thinkingLevel: GoogleThinkingLevel.low,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
