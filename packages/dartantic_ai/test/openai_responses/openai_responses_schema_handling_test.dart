/// Tests that OpenAI Responses properly handles schemas without properties.
///
/// The OpenAI Responses API requires the 'properties' field on object schemas,
/// even when empty. This is handled automatically by the provider via
/// OpenAIUtils.prepareSchemaForOpenAI(), so users don't need to specify
/// explicit empty properties in their tool definitions.
library;

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAI Responses Schema Handling', () {
    test('tool without inputSchema works (uses default S.object())', () async {
      // Tool with no inputSchema - relies on default S.object() which has
      // no 'properties' field. The provider should add it automatically.
      final noSchemaTool = Tool<Map<String, dynamic>>(
        name: 'no_schema_tool',
        description: 'A tool with no inputSchema defined',
        onCall: (_) => 'success from no-schema tool',
      );

      final agent = Agent('openai-responses', tools: [noSchemaTool]);
      final result = await agent.send('Call the no_schema_tool');

      expect(result.output.toLowerCase(), contains('success'));
    });

    test('tool with explicit empty properties works', () async {
      // Tool with explicit empty properties - should work the same
      final emptyPropsTool = Tool<Map<String, dynamic>>(
        name: 'empty_props_tool',
        description: 'A tool with explicit empty properties',
        inputSchema: Schema.fromMap({
          'type': 'object',
          'properties': <String, dynamic>{},
        }),
        onCall: (_) => 'success from empty-props tool',
      );

      final agent = Agent('openai-responses', tools: [emptyPropsTool]);
      final result = await agent.send('Call the empty_props_tool');

      expect(result.output.toLowerCase(), contains('success'));
    });

    test('typed output with tool without properties works', () async {
      // Combine typed output with a no-params tool
      final dateTool = Tool<Map<String, dynamic>>(
        name: 'get_date',
        description: 'Returns the current date',
        onCall: (_) => '2024-01-15',
      );

      final outputSchema = Schema.fromMap({
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'The date returned'},
          'formatted': {'type': 'string', 'description': 'Formatted response'},
        },
        'required': ['date', 'formatted'],
      });

      final agent = Agent('openai-responses', tools: [dateTool]);
      final result = await agent.sendFor<Map<String, dynamic>>(
        'Get the current date using the tool and return it',
        outputSchema: outputSchema,
        outputFromJson: (json) => json,
      );

      expect(result.output, isA<Map<String, dynamic>>());
      expect(result.output['date'], isNotNull);
    });

    test('multiple tools without properties work together', () async {
      final tool1 = Tool<Map<String, dynamic>>(
        name: 'tool_one',
        description: 'First tool with no params',
        onCall: (_) => 'result from tool one',
      );

      final tool2 = Tool<Map<String, dynamic>>(
        name: 'tool_two',
        description: 'Second tool with no params',
        onCall: (_) => 'result from tool two',
      );

      final agent = Agent('openai-responses', tools: [tool1, tool2]);
      final result = await agent.send(
        'Call both tool_one and tool_two and tell me the results',
      );

      expect(result.output.toLowerCase(), contains('tool'));
    });
  });
}
