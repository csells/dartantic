// ignore_for_file: lines_longer_than_80_chars, avoid_print

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import 'package:test/test.dart';

void main() {
  group('GeminiModel.toolsFrom', () {
    test('converts simple string parameter tool', () {
      final tools = [
        Tool(
          name: 'search_web',
          description: 'Search the web for information',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'string',
                    'description': 'The search query to execute',
                  },
                },
                'required': ['query'],
              }.toSchema(),
          onCall: (input) async => {'result': 'mock search result'},
        ),
      ];

      _testToolCollectionConversion('simple string parameter', tools);
    });

    test('converts complex nested object tool', () {
      final tools = [
        Tool(
          name: 'create_user',
          description: 'Create a new user account',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'user': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string', 'description': 'Full name'},
                      'email': {
                        'type': 'string',
                        'description': 'Email address',
                      },
                      'age': {'type': 'integer', 'description': 'Age in years'},
                      'active': {
                        'type': 'boolean',
                        'description': 'Account status',
                      },
                    },
                    'required': ['name', 'email'],
                  },
                  'settings': {
                    'type': 'object',
                    'properties': {
                      'theme': {
                        'type': 'string',
                        'enum': ['light', 'dark', 'auto'],
                        'description': 'UI theme preference',
                      },
                      'notifications': {'type': 'boolean'},
                    },
                  },
                },
                'required': ['user'],
              }.toSchema(),
          onCall: (input) async => {'userId': '12345'},
        ),
      ];

      _testToolCollectionConversion('complex nested object', tools);
    });

    test('converts array parameter tool', () {
      final tools = [
        Tool(
          name: 'batch_process',
          description: 'Process multiple items',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'items': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'id': {'type': 'string'},
                        'value': {'type': 'number'},
                      },
                      'required': ['id'],
                    },
                    'description': 'Array of items to process',
                  },
                  'options': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description': 'Processing options',
                  },
                },
                'required': ['items'],
              }.toSchema(),
          onCall: (input) async => {'processed': true},
        ),
      ];

      _testToolCollectionConversion('array parameter', tools);
    });

    test('converts tool with enum values', () {
      final tools = [
        Tool(
          name: 'set_status',
          description: 'Set user status',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'status': {
                    'type': 'string',
                    'enum': ['online', 'away', 'busy', 'offline'],
                    'description': 'User status',
                  },
                  'priority': {
                    'type': 'string',
                    'enum': ['low', 'medium', 'high'],
                    'description': 'Priority level',
                  },
                },
                'required': ['status'],
              }.toSchema(),
          onCall: (input) async => {'success': true},
        ),
      ];

      _testToolCollectionConversion('enum values', tools);
    });

    test('converts tool with no input schema', () {
      final tools = [
        Tool(
          name: 'get_time',
          description: 'Get current time',
          onCall: (input) async => {'time': DateTime.now().toIso8601String()},
        ),
      ];

      _testToolCollectionConversion('no input schema', tools);
    });

    test('converts multiple tools', () {
      final tools = [
        Tool(
          name: 'tool1',
          description: 'First tool',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'param1': {'type': 'string'},
                },
              }.toSchema(),
          onCall: (input) async => {'result': 'tool1'},
        ),
        Tool(
          name: 'tool2',
          description: 'Second tool',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'param2': {'type': 'integer'},
                },
              }.toSchema(),
          onCall: (input) async => {'result': 'tool2'},
        ),
      ];

      _testToolCollectionConversion('multiple tools', tools);
    });

    test('handles empty tools list', () {
      final geminiTools = GeminiModel.toolsFrom([]).toList();
      expect(geminiTools, isEmpty);
    });

    test('converts complex real-world tool with nested arrays and objects', () {
      final tools = [
        Tool(
          name: 'create_workflow',
          description: 'Create a complex workflow with multiple steps',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'workflow': {
                    'type': 'object',
                    'properties': {
                      'name': {
                        'type': 'string',
                        'description': 'Workflow name',
                      },
                      'description': {'type': 'string'},
                      'steps': {
                        'type': 'array',
                        'items': {
                          'type': 'object',
                          'properties': {
                            'id': {'type': 'string'},
                            'type': {
                              'type': 'string',
                              'enum': [
                                'action',
                                'condition',
                                'loop',
                                'parallel',
                              ],
                            },
                            'config': {
                              'type': 'object',
                              'properties': {
                                'timeout': {'type': 'integer'},
                                'retry_count': {'type': 'integer'},
                                'parameters': {
                                  'type': 'array',
                                  'items': {
                                    'type': 'object',
                                    'properties': {
                                      'key': {'type': 'string'},
                                      'value': {'type': 'string'},
                                      'encrypted': {'type': 'boolean'},
                                    },
                                    'required': ['key', 'value'],
                                  },
                                },
                              },
                            },
                          },
                          'required': ['id', 'type'],
                        },
                      },
                    },
                    'required': ['name', 'steps'],
                  },
                  'metadata': {
                    'type': 'object',
                    'properties': {
                      'tags': {
                        'type': 'array',
                        'items': {'type': 'string'},
                      },
                      'priority': {
                        'type': 'string',
                        'enum': ['low', 'medium', 'high', 'critical'],
                      },
                    },
                  },
                },
                'required': ['workflow'],
              }.toSchema(),
          onCall: (input) async => {'workflowId': 'wf-12345'},
        ),
      ];

      _testToolCollectionConversion('complex nested workflow', tools);
    });

    test('converts Zapier Google Calendar tools', () {
      final tools = [
        // Tools with empty schema
        Tool(
          name: 'add_tools',
          description: 'Add new actions to your MCP provider',
          inputSchema: {'type': 'object', 'properties': {}}.toSchema(),
          onCall: (input) async => {'success': true},
        ),
        Tool(
          name: 'edit_tools',
          description: 'Edit your existing MCP provider actions',
          inputSchema: {'type': 'object', 'properties': {}}.toSchema(),
          onCall: (input) async => {'success': true},
        ),
        // Event retrieval tool
        Tool(
          name: 'google_calendar_retrieve_event_by_id',
          description: 'Finds a specific event by its ID in your calendar.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'instructions': {
                    'type': 'string',
                    'description':
                        'Instructions for running this tool. Any '
                        'parameters that are not given a value will be guessed '
                        'based on the instructions.',
                  },
                  'event_id': {'type': 'string', 'description': 'Event ID'},
                  'calendarid': {'type': 'string', 'description': 'Calendar'},
                },
                'required': ['instructions'],
              }.toSchema(),
          onCall: (input) async => {'event': 'mock_event'},
        ),
        // Event search tool with complex parameters
        Tool(
          name: 'google_calendar_find_event',
          description:
              'Finds an event in your calendar. (Fixed parameters: '
              'calendarid: csells@sellsbrothers.com)',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'instructions': {
                    'type': 'string',
                    'description':
                        'Instructions for running this tool. Any '
                        'parameters that are not given a value will be guessed '
                        'based on the instructions.',
                  },
                  'end_time': {
                    'type': 'string',
                    'description':
                        'This field sets the EARLIEST timestamp '
                        "(lower boundary) to find events. So the events' "
                        'start_time will be greater than this timestamp: e.g. '
                        'To find events scheduled for today, the end_time should '
                        'be set to the earliest of today e.g. To find events '
                        'scheduled for this week, the end_time should be set to '
                        'earliest of this week e.g. To find events scheduled for '
                        'yesterday, the end_time should be set to earliest of '
                        'yesterday e.g. To find events scheduled for tomorrow, '
                        'the end_time should be set to earliest of tomorrow',
                  },
                  'ordering': {'type': 'string', 'description': 'Sort Order'},
                  'eventTypes': {'type': 'string', 'description': 'Event Type'},
                  'start_time': {
                    'type': 'string',
                    'description':
                        'This field sets the LATEST timestamp '
                        "(upper boundary) to find events. So the events' "
                        'end_time will be less than this timestamp: e.g. To find '
                        'events scheduled for today, the start_time should be set '
                        "to 'today at 11:59pm' e.g. To find events scheduled "
                        "for this week, the start_time should be set to 'this "
                        "week last day at 11:59pm' e.g. To find events scheduled "
                        'for yesterday, the start_time should be set to '
                        "'yesterday 11:59pm' e.g. To find events scheduled for "
                        "tomorrow, the start_time should be set to 'tomorrow  "
                        "11:59pm'",
                  },
                  'search_term': {
                    'type': 'string',
                    'description':
                        'ONLY generate a value for this field if '
                        'explicitly asked to filter events. Will search across '
                        'the event name and description. Does not include '
                        'canceled events. **Note**: Search operators such as '
                        '`AND` or `OR` do not work here. If you search for more '
                        'than one word (e.g. `apple banana`) we will only find '
                        'events with both `apple` *AND* `banana` in them, rather '
                        'than events that contains `apple` *OR* `banana`. You can '
                        'also use a negative modifier to exclude terms (example: '
                        '"-apple")',
                  },
                  'expand_recurring': {
                    'type': 'string',
                    'description': 'Expand Recurring Events',
                  },
                },
                'required': ['instructions'],
              }.toSchema(),
          onCall: (input) async => {'events': []},
        ),
        // Busy periods tool
        Tool(
          name: 'google_calendar_find_busy_periods_in_calendar',
          description:
              'Finds busy time periods in your calendar for a specific '
              'timeframe.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'instructions': {
                    'type': 'string',
                    'description':
                        'Instructions for running this tool. Any '
                        'parameters that are not given a value will be guessed '
                        'based on the instructions.',
                  },
                  'end_time': {'type': 'string', 'description': 'End Time'},
                  'calendarid': {'type': 'string', 'description': 'Calendar'},
                  'start_time': {'type': 'string', 'description': 'Start Time'},
                },
                'required': ['instructions'],
              }.toSchema(),
          onCall: (input) async => {'busy_periods': []},
        ),
        // Quick add event tool
        Tool(
          name: 'google_calendar_quick_add_event',
          description:
              'Create an event from a piece of text. Google parses '
              'the text for date, time, and description info.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'instructions': {
                    'type': 'string',
                    'description':
                        'Instructions for running this tool. Any '
                        'parameters that are not given a value will be guessed '
                        'based on the instructions.',
                  },
                  'text': {'type': 'string', 'description': 'Describe Event'},
                  'attendees': {'type': 'string', 'description': 'Attendees'},
                  'calendarid': {'type': 'string', 'description': 'Calendar'},
                },
                'required': ['instructions'],
              }.toSchema(),
          onCall: (input) async => {'event_created': true},
        ),
      ];

      _testToolCollectionConversion('Zapier Google Calendar', tools);
    });

    test('converts HuggingFace tools with constraints and defaults', () {
      final tools = [
        // Tool with empty schema
        Tool(
          name: 'hf_whoami',
          description:
              'Hugging Face tools are being used anonymously and '
              'may be rate limited. Call this tool for instructions on '
              'joining and authenticating.',
          inputSchema: {'type': 'object', 'properties': {}}.toSchema(),
          onCall: (input) async => {'user': 'anonymous'},
        ),
        // Space search with constraints
        Tool(
          name: 'space_search',
          description:
              'Find Hugging Face Spaces using semantic search. '
              'Include links to the Space when presenting the results.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'string',
                    'minLength': 1,
                    'maxLength': 100,
                    'description': 'Semantic Search Query',
                  },
                  'limit': {
                    'type': 'number',
                    'default': 10,
                    'description': 'Number of results to return',
                  },
                  'mcp': {
                    'type': 'boolean',
                    'default': false,
                    'description': 'Only return MCP Server enabled Spaces',
                  },
                },
                'required': ['query'],
              }.toSchema(),
          onCall: (input) async => {'spaces': []},
        ),
        // Model search with enums and constraints
        Tool(
          name: 'model_search',
          description:
              'Find Machine Learning models hosted on Hugging Face. '
              'Returns comprehensive information about matching models '
              'including downloads, likes, tags, and direct links. Include '
              'links to the models in your response',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'string',
                    'description':
                        'Search term. Leave blank and specify "sort" '
                        'and "limit" to get e.g. "Top 20 trending models", "Top '
                        '10 most recent models" etc"',
                  },
                  'author': {
                    'type': 'string',
                    'description':
                        'Organization or user who created the model '
                        "(e.g., 'google', 'meta-llama', 'microsoft')",
                  },
                  'task': {
                    'type': 'string',
                    'description':
                        "Model task type (e.g., 'text-generation', "
                        "'image-classification', 'translation')",
                  },
                  'library': {
                    'type': 'string',
                    'description':
                        'Framework the model uses (e.g., '
                        "'transformers', 'diffusers', 'timm')",
                  },
                  'sort': {
                    'type': 'string',
                    'enum': [
                      'trendingScore',
                      'downloads',
                      'likes',
                      'createdAt',
                      'lastModified',
                    ],
                    'description':
                        'Sort order: trendingScore, downloads , likes, '
                        'createdAt, lastModified',
                  },
                  'limit': {
                    'type': 'number',
                    'minimum': 1,
                    'maximum': 100,
                    'default': 20,
                    'description': 'Maximum number of results to return',
                  },
                },
              }.toSchema(),
          onCall: (input) async => {'models': []},
        ),
        // Dataset search with array properties
        Tool(
          name: 'dataset_search',
          description:
              'Find Datasets hosted on the Hugging Face hub. '
              'Returns comprehensive information about matching datasets '
              'including downloads, likes, tags, and direct links. Include '
              'links to the datasets in your response',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'string',
                    'description':
                        'Search term. Leave blank and specify "sort" '
                        'and "limit" to get e.g. "Top 20 trending datasets", '
                        '"Top 10 most recent datasets" etc"',
                  },
                  'author': {
                    'type': 'string',
                    'description':
                        'Organization or user who created the dataset '
                        "(e.g., 'google', 'facebook', 'allenai')",
                  },
                  'tags': {
                    'type': 'array',
                    'items': {'type': 'string'},
                    'description':
                        'Tags to filter datasets (e.g., '
                        "['language:en', 'size_categories:1M<n<10M', "
                        "'task_categories:text-classification'])",
                  },
                  'sort': {
                    'type': 'string',
                    'enum': [
                      'trendingScore',
                      'downloads',
                      'likes',
                      'createdAt',
                      'lastModified',
                    ],
                    'description':
                        'Sort order: trendingScore, downloads, likes, '
                        'createdAt, lastModified',
                  },
                  'limit': {
                    'type': 'number',
                    'minimum': 1,
                    'maximum': 100,
                    'default': 20,
                    'description': 'Maximum number of results to return',
                  },
                },
              }.toSchema(),
          onCall: (input) async => {'datasets': []},
        ),
        // Model details tool
        Tool(
          name: 'model_details',
          description:
              'Get detailed information about a specific model from the Hugging Face Hub.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'model_id': {
                    'type': 'string',
                    'minLength': 1,
                    'description': 'Model ID (e.g., microsoft/DialoGPT-large)',
                  },
                },
                'required': ['model_id'],
              }.toSchema(),
          onCall: (input) async => {'model_info': {}},
        ),
        // Paper search tool
        Tool(
          name: 'paper_search',
          description:
              "Find Machine Learning research papers on the Hugging Face hub. Include 'Link to paper' When presenting the results. Consider whether tabulating results matches user intent.",
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'query': {
                    'type': 'string',
                    'minLength': 3,
                    'maxLength': 200,
                    'description': 'Semantic Search query',
                  },
                  'results_limit': {
                    'type': 'number',
                    'default': 12,
                    'description': 'Number of results to return',
                  },
                  'concise_only': {
                    'type': 'boolean',
                    'default': false,
                    'description':
                        'Return a 2 sentence summary of the abstract. Use for broad search terms which may return a lot of results. Check with User if unsure.',
                  },
                },
                'required': ['query'],
              }.toSchema(),
          onCall: (input) async => {'papers': []},
        ),
        // Dataset details tool
        Tool(
          name: 'dataset_details',
          description:
              'Get detailed information about a specific dataset on Hugging Face Hub.',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'dataset_id': {
                    'type': 'string',
                    'minLength': 1,
                    'description': 'Dataset ID (e.g., squad, glue, imdb)',
                  },
                },
                'required': ['dataset_id'],
              }.toSchema(),
          onCall: (input) async => {'dataset_info': {}},
        ),
        // Image generation with numeric ranges
        Tool(
          name: 'gr1_evalstate_flux1_schnell',
          description:
              'Generate an image using the Flux 1 Schnell Image '
              'Generator. (from evalstate/flux1_schnell)',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'prompt': {'type': 'string'},
                  'seed': {
                    'type': 'number',
                    'description': 'numeric value between 0 and 2147483647',
                  },
                  'randomize_seed': {'type': 'boolean', 'default': true},
                  'width': {
                    'type': 'number',
                    'description': 'numeric value between 256 and 2048',
                    'default': 1024,
                  },
                  'height': {
                    'type': 'number',
                    'description': 'numeric value between 256 and 2048',
                    'default': 1024,
                  },
                  'num_inference_steps': {
                    'type': 'number',
                    'description': 'numeric value between 1 and 50',
                    'default': 4,
                  },
                },
              }.toSchema(),
          onCall:
              (input) async => {'image_url': 'https://example.com/image.png'},
        ),
      ];

      _testToolCollectionConversion('HuggingFace', tools);
    });

    test('converts deepwiki GitHub repository tools', () {
      final tools = [
        Tool(
          name: 'read_wiki_structure',
          description:
              'Get a list of documentation topics for a GitHub repository',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'repoName': {
                    'type': 'string',
                    'description':
                        'GitHub repository: owner/repo (e.g. "facebook/react")',
                  },
                },
                'required': ['repoName'],
              }.toSchema(),
          onCall: (input) async => {'topics': []},
        ),
        Tool(
          name: 'read_wiki_contents',
          description: 'View documentation about a GitHub repository',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'repoName': {
                    'type': 'string',
                    'description':
                        'GitHub repository: owner/repo (e.g. "facebook/react")',
                  },
                },
                'required': ['repoName'],
              }.toSchema(),
          onCall: (input) async => {'content': 'wiki content'},
        ),
        Tool(
          name: 'ask_question',
          description: 'Ask any question about a GitHub repository',
          inputSchema:
              {
                'type': 'object',
                'properties': {
                  'repoName': {
                    'type': 'string',
                    'description':
                        'GitHub repository: owner/repo (e.g. "facebook/react")',
                  },
                  'question': {
                    'type': 'string',
                    'description': 'The question to ask about the repository',
                  },
                },
                'required': ['repoName', 'question'],
              }.toSchema(),
          onCall: (input) async => {'answer': 'repository answer'},
        ),
      ];

      _testToolCollectionConversion('deepwiki GitHub', tools);
    });
  });
}

/// Helper function to verify basic tool conversion from Tool to Gemini FunctionDeclaration
void _verifyToolConversion(
  Tool originalTool,
  gemini.FunctionDeclaration geminiDecl,
) {
  expect(geminiDecl.name, equals(originalTool.name));
  expect(geminiDecl.description, equals(originalTool.description));

  if (originalTool.inputSchema != null) {
    final inputSchemaMap = originalTool.inputSchema!.toMap();
    _verifySchemaConversion(inputSchemaMap, geminiDecl.parameters!);
  } else {
    // Tool with no input schema should have empty properties
    expect(geminiDecl.parameters!.type, equals(gemini.SchemaType.object));
    expect(geminiDecl.parameters!.properties, isEmpty);
  }
}

/// Recursively verify that a JSON schema was correctly converted to Gemini schema
void _verifySchemaConversion(
  Map<String, dynamic> originalSchema,
  gemini.Schema geminiSchema,
) {
  // Verify schema type
  final originalType = originalSchema['type'] as String?;
  if (originalType != null) {
    final expectedGeminiType = _mapTypeToGeminiType(originalType);
    expect(geminiSchema.type, equals(expectedGeminiType));
  }

  // Verify description
  final originalDescription = originalSchema['description'] as String?;
  if (originalDescription != null) {
    expect(geminiSchema.description, equals(originalDescription));
  }

  // Verify properties for object types
  final originalProperties =
      originalSchema['properties'] as Map<String, dynamic>?;
  if (originalProperties != null) {
    expect(geminiSchema.properties, hasLength(originalProperties.length));

    // Verify each property recursively
    originalProperties.forEach((propName, propSchema) {
      final geminiPropSchema = geminiSchema.properties![propName];
      expect(
        geminiPropSchema,
        isNotNull,
        reason: 'Property "$propName" should exist in converted schema',
      );
      _verifySchemaConversion(
        propSchema as Map<String, dynamic>,
        geminiPropSchema!,
      );
    });
  }

  // Verify required properties
  final originalRequired = originalSchema['required'] as List<dynamic>?;
  if (originalRequired != null) {
    expect(
      geminiSchema.requiredProperties,
      equals(originalRequired.cast<String>()),
    );
  }

  // Verify array items
  final originalItems = originalSchema['items'] as Map<String, dynamic>?;
  if (originalItems != null) {
    expect(
      geminiSchema.items,
      isNotNull,
      reason: 'Array items schema should exist',
    );
    _verifySchemaConversion(originalItems, geminiSchema.items!);
  }

  // Verify enum values
  final originalEnum = originalSchema['enum'] as List<dynamic>?;
  if (originalEnum != null) {
    expect(geminiSchema.enumValues, equals(originalEnum.cast<String>()));
  }

  // Verify nullable properties based on required fields
  if (originalSchema.containsKey('required') &&
      originalSchema.containsKey('properties')) {
    final requiredProps = Set<String>.from(
      originalSchema['required'] as List<dynamic>,
    );
    final properties = originalSchema['properties'] as Map<String, dynamic>;

    properties.forEach((propName, _) {
      final geminiPropSchema = geminiSchema.properties![propName]!;
      if (requiredProps.contains(propName)) {
        expect(
          geminiPropSchema.nullable,
          equals(false),
          reason: 'Required property "$propName" should have nullable: false',
        );
      } else {
        expect(
          geminiPropSchema.nullable,
          equals(null),
          reason: 'Optional property "$propName" should have nullable: null',
        );
      }
    });
  }
}

/// Map JSON Schema types to Gemini schema types
gemini.SchemaType _mapTypeToGeminiType(String jsonType) {
  switch (jsonType) {
    case 'string':
      return gemini.SchemaType.string;
    case 'integer':
      return gemini.SchemaType.integer;
    case 'number':
      return gemini.SchemaType.number;
    case 'boolean':
      return gemini.SchemaType.boolean;
    case 'array':
      return gemini.SchemaType.array;
    case 'object':
      return gemini.SchemaType.object;
    default:
      throw Exception('Unknown JSON Schema type: $jsonType');
  }
}

/// Helper function to find a Gemini function declaration by name
gemini.FunctionDeclaration _findGeminiFunctionByName(
  List<gemini.Tool> geminiTools,
  String functionName,
) {
  for (final tool in geminiTools) {
    for (final func in tool.functionDeclarations!) {
      if (func.name == functionName) {
        return func;
      }
    }
  }
  throw Exception('Function "$functionName" not found in converted tools');
}

/// Comprehensive helper to test conversion of any tool collection
void _testToolCollectionConversion(String collectionName, List<Tool> tools) {
  final geminiTools = GeminiModel.toolsFrom(tools).toList();

  // Verify correct number of tools converted
  expect(
    geminiTools,
    hasLength(tools.length),
    reason: '$collectionName: Expected ${tools.length} converted tools',
  );

  // Verify all tools are converted correctly
  for (final originalTool in tools) {
    final geminiDecl = _findGeminiFunctionByName(
      geminiTools,
      originalTool.name,
    );
    _verifyToolConversion(originalTool, geminiDecl);
  }
}
