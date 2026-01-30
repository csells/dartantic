/// Architecture tests to verify layered architecture constraints.
///
/// These tests enforce the six-layer architecture documented in CLAUDE.md:
/// 1. API Layer (lib/src/agent/agent.dart)
/// 2. Orchestration Layer (lib/src/agent/orchestrators/)
/// 3. Provider Abstraction Layer (dartantic_interface)
/// 4. Provider Implementation Layer (lib/src/providers/, lib/src/chat_models/)
/// 5. Infrastructure Layer (lib/src/shared/)
/// 6. Protocol Layer
///
/// Key constraints:
/// - Dependencies must flow downward only
/// - Provider-specific orchestrators belong in orchestration layer
/// - No circular dependencies between layers
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('Architecture', () {
    group('Layer Dependencies', () {
      test(
        'provider-specific orchestrators should be in orchestration layer',
        () async {
          final orchestratorDir = Directory(
            'lib/src/agent/orchestrators',
          );

          // These provider-specific orchestrators should exist in the
          // orchestration layer
          final expectedOrchestrators = [
            'anthropic_typed_output_orchestrator.dart',
            'google_double_agent_orchestrator.dart',
          ];

          final files = await orchestratorDir
              .list()
              .where((e) => e is File)
              .map((e) => e.path.split('/').last)
              .toList();

          for (final orchestrator in expectedOrchestrators) {
            expect(
              files,
              contains(orchestrator),
              reason:
                  '$orchestrator should be in agent/orchestrators/, '
                  'not in chat_models/',
            );
          }
        },
      );

      test(
        'chat_models should not contain orchestrators',
        () async {
          final chatModelsDir = Directory('lib/src/chat_models');

          // Recursively find all dart files
          final dartFiles = await chatModelsDir
              .list(recursive: true)
              .where((e) => e is File && e.path.endsWith('.dart'))
              .map((e) => e.path)
              .toList();

          // No file should be named *_orchestrator.dart
          final orchestratorFiles = dartFiles
              .where((f) => f.contains('orchestrator'))
              .toList();

          expect(
            orchestratorFiles,
            isEmpty,
            reason:
                'Orchestrators should not be in chat_models layer. '
                'Found: $orchestratorFiles',
          );
        },
      );

      test(
        'chat_models should not import from agent layer',
        () async {
          final chatModelsDir = Directory('lib/src/chat_models');

          // Recursively find all dart files
          final dartFiles = await chatModelsDir
              .list(recursive: true)
              .where((e) => e is File && e.path.endsWith('.dart'))
              .cast<File>()
              .toList();

          final violations = <String>[];

          for (final file in dartFiles) {
            final content = await file.readAsString();
            final lines = content.split('\n');

            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              // Check for imports from agent layer
              if (line.contains("import '") &&
                  line.contains('/agent/') &&
                  !line.contains('// allowed-cross-layer')) {
                violations.add(
                  '${file.path}:${i + 1}: $line',
                );
              }
            }
          }

          expect(
            violations,
            isEmpty,
            reason:
                'chat_models layer should not import from agent layer. '
                'Violations:\n${violations.join('\n')}',
          );
        },
      );

      test(
        'providers should not have circular dependencies with chat_models',
        () async {
          final providersDir = Directory('lib/src/providers');

          // Find all provider files
          final providerFiles = await providersDir
              .list()
              .where((e) => e is File && e.path.endsWith('.dart'))
              .cast<File>()
              .toList();

          final circularDeps = <String>[];

          for (final file in providerFiles) {
            final content = await file.readAsString();
            final lines = content.split('\n');
            final fileName = file.path.split('/').last;

            // Check if this provider imports an orchestrator from chat_models
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              if (line.contains("import '") &&
                  line.contains('/chat_models/') &&
                  line.contains('orchestrator')) {
                circularDeps.add(
                  '$fileName:${i + 1}: imports orchestrator from chat_models',
                );
              }
            }
          }

          expect(
            circularDeps,
            isEmpty,
            reason:
                'Providers should not import orchestrators from chat_models. '
                'This creates circular dependencies. '
                'Violations:\n${circularDeps.join('\n')}',
          );
        },
      );

      test(
        'anthropic orchestrator should not import from providers layer',
        () async {
          final orchestratorFile = File(
            'lib/src/agent/orchestrators/anthropic_typed_output_orchestrator.dart',
          );

          if (!await orchestratorFile.exists()) {
            fail(
              'anthropic_typed_output_orchestrator.dart should exist in '
              'agent/orchestrators/',
            );
          }

          final content = await orchestratorFile.readAsString();
          final lines = content.split('\n');

          final providerImports = <String>[];

          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains("import '") &&
                line.contains('/providers/')) {
              providerImports.add('Line ${i + 1}: $line');
            }
          }

          expect(
            providerImports,
            isEmpty,
            reason:
                'Anthropic orchestrator should not import from providers layer. '
                'This creates a circular dependency. '
                'Violations:\n${providerImports.join('\n')}',
          );
        },
      );

      test(
        'typed output tool name constant should be in shared location',
        () async {
          final constantsFile = File(
            'lib/src/shared/typed_output_constants.dart',
          );

          expect(
            await constantsFile.exists(),
            isTrue,
            reason:
                'typed_output_constants.dart should exist in shared/ '
                'to avoid circular dependencies between providers and '
                'orchestrators',
          );

          final content = await constantsFile.readAsString();

          expect(
            content,
            contains('kAnthropicReturnResultTool'),
            reason:
                'typed_output_constants.dart should contain '
                'kAnthropicReturnResultTool constant',
          );
        },
      );
    });

    group('Import Structure', () {
      test(
        'orchestrators.dart should export provider-specific orchestrators',
        () async {
          final orchestratorsFile = File(
            'lib/src/agent/orchestrators/orchestrators.dart',
          );

          final content = await orchestratorsFile.readAsString();

          expect(
            content,
            contains('anthropic_typed_output_orchestrator.dart'),
            reason: 'orchestrators.dart should export Anthropic orchestrator',
          );

          expect(
            content,
            contains('google_double_agent_orchestrator.dart'),
            reason: 'orchestrators.dart should export Google orchestrator',
          );
        },
      );
    });
  });
}
