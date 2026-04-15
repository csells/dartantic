// NEVER check for API keys in tests. Dartantic already validates API keys
// and throws a clear exception if one is missing. Tests should fail loudly
// when credentials are unavailable, not silently skip.
//
// File Search E2E: creates or reuses a store
// [kDartanticE2eStoreDisplayName] and uploads
// [kDartanticE2eDocumentDisplayName] if missing. See
// https://ai.google.dev/gemini-api/docs/file-search

import 'dart:convert';
import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:googleai_dart/googleai_dart.dart' as ga;
import 'package:test/test.dart';

import 'test_tools.dart';

/// Display name for the shared E2E File Search store (stable across runs).
const String kDartanticE2eStoreDisplayName = 'dartantic_ai_e2e_file_search';

/// Display name for the fixture document inside the store.
const String kDartanticE2eDocumentDisplayName = 'dartantic_e2e_retrieval_fact';

/// Token the model must recover from file search over the fixture.
const String kDartanticE2eRetrievalToken = 'DARTANTIC_E2E_FS_TOKEN_PYRAMID_9';

/// Text uploaded into the File Search store for retrieval tests.
String get kDartanticE2eFileSearchBody =>
    '''
Dartantic File Search E2E fixture document.

Verification token: $kDartanticE2eRetrievalToken

The fixture answer phrase is: red-pyramid-nine
''';

Future<ga.FileSearchStore?> _findFileSearchStoreByDisplayName(
  ga.GoogleAIClient client,
  String displayName,
) async {
  String? pageToken;
  do {
    final res = await client.fileSearchStores.list(
      pageSize: 20,
      pageToken: pageToken,
    );
    for (final store in res.fileSearchStores ?? const <ga.FileSearchStore>[]) {
      if (store.displayName == displayName) return store;
    }
    pageToken = res.nextPageToken;
  } while (pageToken != null && pageToken.isNotEmpty);
  return null;
}

Future<List<ga.Document>> _listAllStoreDocuments(
  ga.GoogleAIClient client,
  String storeResourceName,
) async {
  final out = <ga.Document>[];
  String? pageToken;
  do {
    final res = await client.fileSearchStores.listDocuments(
      parent: storeResourceName,
      pageSize: 20,
      pageToken: pageToken,
    );
    out.addAll(res.documents ?? const <ga.Document>[]);
    pageToken = res.nextPageToken;
  } while (pageToken != null && pageToken.isNotEmpty);
  return out;
}

Future<void> _waitForDocumentActive(
  ga.GoogleAIClient client,
  String documentResourceName, {
  Duration pollInterval = const Duration(seconds: 2),
  int maxAttempts = 45,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    final doc = await client.fileSearchStores.getDocument(
      name: documentResourceName,
    );
    if (doc.state == ga.DocumentState.active) return;
    if (doc.state == ga.DocumentState.failed) {
      throw StateError(
        'File Search document failed to index: $documentResourceName',
      );
    }
    await Future<void>.delayed(pollInterval);
  }
  throw StateError(
    'Timed out waiting for File Search document to become active: '
    '$documentResourceName',
  );
}

/// Ensures a File Search store and indexed test document exist, then returns
/// the store resource name (e.g. `fileSearchStores/...`).
///
/// Reuses a store with [kDartanticE2eStoreDisplayName]. Uploads
/// [kDartanticE2eFileSearchBody] when no active document with
/// [kDartanticE2eDocumentDisplayName] is present.
Future<String> ensureDartanticE2eFileSearchStoreReady(
  ga.GoogleAIClient client,
) async {
  var store = await _findFileSearchStoreByDisplayName(
    client,
    kDartanticE2eStoreDisplayName,
  );
  store ??= await client.fileSearchStores.create(
    displayName: kDartanticE2eStoreDisplayName,
  );
  final storeName = store.name;
  if (storeName == null || storeName.isEmpty) {
    throw StateError('File Search store has no name: $store');
  }

  final docs = await _listAllStoreDocuments(client, storeName);
  for (final doc in docs) {
    if (doc.displayName != kDartanticE2eDocumentDisplayName) continue;
    final name = doc.name;
    if (name == null || name.isEmpty) continue;
    if (doc.state == ga.DocumentState.active) return storeName;
    if (doc.state == ga.DocumentState.pending) {
      await _waitForDocumentActive(client, name);
      return storeName;
    }
    if (doc.state == ga.DocumentState.failed) {
      await client.fileSearchStores.deleteDocument(name: name);
    }
  }

  final bytes = utf8.encode(kDartanticE2eFileSearchBody);
  final upload = await client.fileSearchStores.upload(
    parent: storeName,
    bytes: bytes,
    fileName: 'dartantic_e2e_fixture.txt',
    mimeType: 'text/plain',
    request: const ga.UploadToFileSearchStoreRequest(
      displayName: kDartanticE2eDocumentDisplayName,
      mimeType: 'text/plain',
    ),
  );
  final docName = upload.documentName;
  if (docName == null || docName.isEmpty) {
    throw StateError('upload_to_file_search_store returned no documentName');
  }
  await _waitForDocumentActive(client, docName);
  return storeName;
}

/// `grounding_metadata` from Maps should name the Walt Disney Family Museum
/// for queries about museums near the Presidio.
void expectGroundingIncludesDisneyFamilyMuseum(Map<String, dynamic> metadata) {
  final grounding = metadata['grounding_metadata'];
  expect(
    grounding,
    isA<Map<String, dynamic>>(),
    reason: 'Expected non-null grounding_metadata from Maps grounding',
  );
  final blob = jsonEncode(grounding).toLowerCase();
  expect(
    blob.contains('disney') && blob.contains('museum'),
    isTrue,
    reason:
        'Grounding should reference the Walt Disney Family Museum '
        '(or similar): ${jsonEncode(grounding)}',
  );
}

void main() {
  group('Google server-side tooling E2E', () {
    test(
      'Code Execution: runs python code',
      () async {
        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.codeExecution},
          ),
        );

        final result = await agent.send(
          'Use code execution to calculate 12345 * 67890 and print the result.',
        );

        expect(result.output.replaceAll(',', ''), contains('838102050'));
        // We might want to check metadata for code execution result if
        // possible,
        // but checking output is a good end-to-end verification.
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Google Search: searches and returns grounded results',
      () async {
        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.googleSearch},
          ),
        );

        final result = await agent.send(
          'Search for "Dart programming language release date" and tell me '
          'the year.',
        );

        expect(result.output, contains('2011')); // Or 2013
        expect(result.output, contains('Dart'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Google Search with user tools: ToolConfig includes server invocations',
      () async {
        // Gemini rejects mixed built-in tools + function declarations unless
        // tool_config.include_server_side_tool_invocations is set.
        // GoogleChatModel sets that when both are present.
        final agent = Agent(
          'google:gemini-3-flash-preview',
          tools: [stringTool],
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.googleSearch},
          ),
        );

        final result = await agent.send(
          'Use the string_tool with input "server-side-plus-functions-e2e"',
        );

        final toolResults = result.messages
            .expand((msg) => msg.toolResults)
            .toList();
        expect(toolResults, hasLength(1));
        expect(
          toolResults.first.result,
          equals('String result: server-side-plus-functions-e2e'),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Google Search with typed output: uses double agent orchestrator',
      () async {
        // This test verifies the fix for GitHub issue #96:
        // Server-side tools combined with typed output should work.
        // The double agent orchestrator handles this by:
        // - Phase 1: Execute server-side tools (no outputSchema)
        // - Phase 2: Get structured output (no tools)
        //
        // Before the fix, this would fail with:
        // "Tool use with a response mime type: 'application/json' is
        // unsupported"
        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'language': {'type': 'string'},
            'year': {'type': 'integer'},
            'creator': {'type': 'string'},
          },
          'required': ['language', 'year', 'creator'],
        });

        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.googleSearch},
          ),
        );

        final result = await agent.sendFor<Map<String, dynamic>>(
          'Search for "Dart programming language" and return information '
          'about when it was released and who created it.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        // Verify we got valid typed output
        expect(result.output['language'], isNotNull);
        expect(result.output['year'], isA<int>());
        expect(result.output['creator'], isNotNull);

        // The year should be 2011 (announced) or 2013 (1.0 release)
        expect(result.output['year'], anyOf(equals(2011), equals(2013)));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Code Execution with typed output: uses double agent orchestrator',
      () async {
        // Test code execution server-side tool with typed output.
        //
        // Before the fix, this would fail with:
        // "Tool use with a response mime type: 'application/json' is
        // unsupported"
        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'result': {'type': 'integer'},
            'calculation': {'type': 'string'},
          },
          'required': ['result', 'calculation'],
        });

        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.codeExecution},
          ),
        );

        // 123 * 456 = 56088
        final result = await agent.sendFor<Map<String, dynamic>>(
          'Use code execution to calculate 123 * 456, then return the result '
          'in the specified JSON format.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        // Verify we got valid typed output with the correct calculation
        expect(result.output['result'], equals(56088));
        expect(result.output['calculation'], isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'URL Context: queries URLs and returns context',
      () async {
        final agent = Agent(
          'google',
          chatModelOptions: const GoogleChatModelOptions(
            serverSideTools: {GoogleServerSideTool.urlContext},
          ),
        );

        final result = await agent.send(
          'Open this url and tell me the publisher of the package: https://pub.dev/packages/dartantic_ai',
        );

        expect(result.output, contains('sellsbrothers.com'));
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'thinkingLevel high vs low: same prompt, low finishes faster',
      () async {
        const prompt = 'Whats 2+2? Respond with just the answer.';

        Future<Duration> timeSend(GoogleThinkingLevel level) async {
          final agent = Agent(
            'google:gemini-3-flash-preview',
            chatModelOptions: GoogleChatModelOptions(thinkingLevel: level),
          );
          final sw = Stopwatch()..start();
          final result = await agent.send(prompt);
          sw.stop();
          expect(result.output.toLowerCase(), contains('4'));
          return sw.elapsed;
        }

        // High first so the low run avoids connection cold-start bias.
        final highDuration = await timeSend(GoogleThinkingLevel.high);
        final lowDuration = await timeSend(GoogleThinkingLevel.low);

        expect(
          lowDuration,
          lessThan(highDuration),
          reason:
              'low thinkingLevel should be faster than high for the same '
              'prompt (high=${highDuration.inMilliseconds}ms, '
              'low=${lowDuration.inMilliseconds}ms)',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Maps grounding: Presidio museums prompt surfaces Disney Family Museum',
      () async {
        final agent = Agent(
          'google:gemini-2.5-flash',
          chatModelOptions: const GoogleChatModelOptions(
            mapsGrounding: GoogleMapsGroundingOptions(),
          ),
        );

        final result = await agent.send(
          'Using Google Maps grounding: what museums are near Presidio Park in '
          'San Francisco? List a few examples in a short answer.',
        );

        expect(result.output.toLowerCase(), contains('museum'));
        expectGroundingIncludesDisneyFamilyMuseum(result.metadata);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'Maps grounding with typed output: double agent and Disney in grounding',
      () async {
        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'examples': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Museum names near the Presidio',
            },
          },
          'required': ['examples'],
        });

        final agent = Agent(
          'google:gemini-2.5-flash',
          chatModelOptions: const GoogleChatModelOptions(
            mapsGrounding: GoogleMapsGroundingOptions(),
          ),
        );

        final result = await agent.sendFor<Map<String, dynamic>>(
          'Using Google Maps grounding: list museums near Presidio Park in San '
          'Francisco. Put museum names in the examples array of the JSON '
          'schema.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        final examples = result.output['examples'] as List<dynamic>?;
        expect(examples, isNotNull);
        expect(examples, isNotEmpty);
        expectGroundingIncludesDisneyFamilyMuseum(result.metadata);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'File Search: ensures fixture document then answers from retrieval',
      () async {
        final apiKey = Platform.environment[GoogleProvider.defaultApiKeyName]!;
        final client = ga.GoogleAIClient(
          config: ga.GoogleAIConfig(authProvider: ga.ApiKeyProvider(apiKey)),
        );
        late final String storeName;
        try {
          storeName = await ensureDartanticE2eFileSearchStoreReady(client);
        } finally {
          client.close();
        }

        final agent = Agent(
          'google:gemini-3-flash-preview',
          chatModelOptions: GoogleChatModelOptions(
            fileSearch: GoogleFileSearchToolConfig(
              fileSearchStoreNames: [storeName],
            ),
          ),
        );

        final result = await agent.send(
          'Use file search on the configured stores only. What is the '
          'verification token string in the fixture document? Reply with '
          'only that token.',
        );

        expect(result.output, contains(kDartanticE2eRetrievalToken));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'File Search with typed output: fixture then structured answer',
      () async {
        final apiKey = Platform.environment[GoogleProvider.defaultApiKeyName]!;
        final client = ga.GoogleAIClient(
          config: ga.GoogleAIConfig(authProvider: ga.ApiKeyProvider(apiKey)),
        );
        late final String storeName;
        try {
          storeName = await ensureDartanticE2eFileSearchStoreReady(client);
        } finally {
          client.close();
        }

        final outputSchema = Schema.fromMap({
          'type': 'object',
          'properties': {
            'token': {'type': 'string'},
            'phrase': {'type': 'string'},
          },
          'required': ['token', 'phrase'],
        });

        final agent = Agent(
          'google:gemini-3-flash-preview',
          chatModelOptions: GoogleChatModelOptions(
            fileSearch: GoogleFileSearchToolConfig(
              fileSearchStoreNames: [storeName],
            ),
          ),
        );

        final result = await agent.sendFor<Map<String, dynamic>>(
          'Use file search on the configured stores. Return the verification '
          'token and the fixture answer phrase (red-pyramid-nine) in the JSON '
          'schema.',
          outputSchema: outputSchema,
          outputFromJson: (json) => json,
        );

        expect(
          result.output['token'].toString().trim(),
          kDartanticE2eRetrievalToken,
        );
        expect(
          result.output['phrase'].toString().toLowerCase(),
          contains('red-pyramid-nine'),
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
