// ignore_for_file: avoid_dynamic_calls

import 'dart:math';

import 'package:dartantic_interface/dartantic_interface.dart';

// A weather tool that can be called multiple times with different cities
final weatherTool = Tool<Map<String, dynamic>>(
  name: 'get_weather',
  description: 'Get the current weather for a city',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'city': {'type': 'string', 'description': 'The city to get weather for'},
    },
    'required': ['city'],
  }),
  onCall: (args) async {
    final city = args['city'];
    // Mock weather data
    final weatherData = {
      'boston': {'temp': 45, 'condition': 'cloudy'},
      'new york': {'temp': 52, 'condition': 'sunny'},
      'los angeles': {'temp': 72, 'condition': 'clear'},
      'chicago': {'temp': 38, 'condition': 'windy'},
      'seattle': {'temp': 55, 'condition': 'rainy'},
    };

    final data =
        weatherData[city.toLowerCase()] ?? {'temp': 60, 'condition': 'unknown'};

    return 'Weather in $city: ${data['temp']}°F, ${data['condition']}';
  },
);

// String return tools
final stringTool = Tool<Map<String, dynamic>>(
  name: 'string_tool',
  description: 'Returns a simple string',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'input': {'type': 'string'},
    },
    'required': ['input'],
  }),

  onCall: (input) => 'String result: ${input['input']}',
);

final emptyStringTool = Tool<Map<String, dynamic>>(
  name: 'empty_string_tool',
  description: 'Returns an empty string',

  onCall: (_) => '',
);

// Numeric return tools
final intTool = Tool<Map<String, dynamic>>(
  name: 'int_tool',
  description: 'Returns an integer',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'value': {'type': 'integer'},
    },
    'required': ['value'],
  }),

  onCall: (input) {
    final value = input['value'];
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw ArgumentError('Expected int or string, got ${value.runtimeType}');
  },
);

final doubleTool = Tool<Map<String, dynamic>>(
  name: 'double_tool',
  description: 'Returns a double',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'value': {'type': 'number'},
    },
    'required': ['value'],
  }),

  onCall: (input) => input['value'] as double,
);

// Boolean return tool
final boolTool = Tool<Map<String, dynamic>>(
  name: 'bool_tool',
  description: 'Returns a boolean',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'value': {'type': 'boolean'},
    },
    'required': ['value'],
  }),

  onCall: (input) => input['value'] as bool,
);

// Null return tool
final nullTool = Tool<Map<String, dynamic>>(
  name: 'null_tool',
  description: 'Returns null',

  onCall: (_) => null,
);

// Collection return tools
final listTool = Tool<Map<String, dynamic>>(
  name: 'list_tool',
  description: 'Returns a list',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'items': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['items'],
  }),

  onCall: (input) => input['items'] as List,
);

final emptyListTool = Tool<Map<String, dynamic>>(
  name: 'empty_list_tool',
  description: 'Returns an empty list',

  onCall: (_) => [],
);

final mapTool = Tool<Map<String, dynamic>>(
  name: 'map_tool',
  description: 'Returns a map',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'key': {'type': 'string'},
      'value': {'type': 'string'},
    },
    'required': ['key', 'value'],
  }),

  onCall: (input) => {
    (input['key'] as String?).toString(): input['value'],
    'type': 'map_result',
  },
);

final nestedMapTool = Tool<Map<String, dynamic>>(
  name: 'nested_map_tool',
  description: 'Returns a nested map structure',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'level': {'type': 'integer'},
    },
    'required': ['level'],
  }),

  onCall: (input) => {
    'level': input['level'],
    'data': {
      'nested': true,
      'items': ['a', 'b', 'c'],
      'metadata': {'created': DateTime.now().toIso8601String(), 'version': 1.0},
    },
  },
);

// Edge case tools
final veryLongStringTool = Tool<Map<String, dynamic>>(
  name: 'very_long_string_tool',
  description: 'Returns a very long string',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'repeat_count': {'type': 'integer'},
    },
    'required': ['repeat_count'],
  }),

  onCall: (input) {
    final count = input['repeat_count'] as int;
    return 'Lorem ipsum dolor sit amet. ' * count;
  },
);

final unicodeTool = Tool<Map<String, dynamic>>(
  name: 'unicode_tool',
  description: 'Returns unicode and emoji characters',

  onCall: (_) => '👋 Hello 世界 🌍 नमस्ते мир',
);

final specialCharsTool = Tool<Map<String, dynamic>>(
  name: 'special_chars_tool',
  description: 'Returns special characters that need escaping',

  onCall: (_) =>
      'Line 1\nLine 2\tTabbed\r\nWindows line\n"Quoted"\n\'Single quoted\'',
);

// Error testing tools
final errorTool = Tool<Map<String, dynamic>>(
  name: 'error_tool',
  description: 'Throws an error when called',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'error_message': {'type': 'string'},
    },
    'required': ['error_message'],
  }),

  onCall: (input) => throw Exception(input['error_message']),
);

final invalidJsonTool = Tool<Map<String, dynamic>>(
  name: 'invalid_json_tool',
  description: 'Returns a value that might cause JSON encoding issues',

  onCall: (_) => double.infinity,
);

// Tools for testing optional and default parameters
final optionalParamsTool = Tool<Map<String, dynamic>>(
  name: 'optional_params_tool',
  description: 'Tool with optional parameters',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'required_param': {'type': 'string'},
      'optional_param': {
        'type': 'string',
        'description': 'This parameter is optional',
      },
    },
    'required': ['required_param'],
  }),

  onCall: (input) => {
    'required': input['required_param'],
    'optional': input['optional_param'] ?? 'default_value',
  },
);

// Tools for testing multiple tools in one call
final multiStepTool1 = Tool<Map<String, dynamic>>(
  name: 'step1',
  description: 'First step in a multi-tool process',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'input': {'type': 'string'},
    },
    'required': ['input'],
  }),

  onCall: (input) => 'Step 1 processed: ${input['input']}',
);

final multiStepTool2 = Tool<Map<String, dynamic>>(
  name: 'step2',
  description: 'Second step that depends on step1',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'step1_result': {'type': 'string'},
    },
    'required': ['step1_result'],
  }),

  onCall: (input) => 'Step 2 processed: ${input['step1_result']}',
);

// Tools for testing parameter validation
final strictTypeTool = Tool<Map<String, dynamic>>(
  name: 'strict_type_tool',
  description: 'Tool that requires specific types',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'string_param': {'type': 'string'},
      'int_param': {'type': 'integer'},
      'bool_param': {'type': 'boolean'},
      'array_param': {
        'type': 'array',
        'items': {'type': 'integer'},
      },
    },
    'required': ['string_param', 'int_param', 'bool_param', 'array_param'],
  }),

  onCall: (input) => {
    'types_received': {
      'string': input['string_param'].runtimeType.toString(),
      'int': input['int_param'].runtimeType.toString(),
      'bool': input['bool_param'].runtimeType.toString(),
      'array': input['array_param'].runtimeType.toString(),
    },
    'values': input,
  },
);

// No-parameter tool
final noParamsTool = Tool<Map<String, dynamic>>(
  name: 'no_params_tool',
  description: 'Tool that takes no parameters',

  onCall: (_) => 'Called with no parameters',
);

/// Returns all test tools for comprehensive testing
List<Tool> get allTestTools => [
  stringTool,
  emptyStringTool,
  intTool,
  doubleTool,
  boolTool,
  nullTool,
  listTool,
  emptyListTool,
  mapTool,
  nestedMapTool,
  veryLongStringTool,
  unicodeTool,
  specialCharsTool,
  errorTool,
  invalidJsonTool,
  optionalParamsTool,
  multiStepTool1,
  multiStepTool2,
  strictTypeTool,
  noParamsTool,
];

/// Returns a subset of tools for basic testing
List<Tool> get basicTestTools => [
  stringTool,
  intTool,
  boolTool,
  listTool,
  mapTool,
];

/// Returns tools that test edge cases
List<Tool> get edgeCaseTools => [
  emptyStringTool,
  nullTool,
  emptyListTool,
  veryLongStringTool,
  unicodeTool,
  specialCharsTool,
  noParamsTool,
];

/// Returns tools for error testing
List<Tool> get errorTestTools => [errorTool, invalidJsonTool];

/// Tool that returns the current date and time
final currentDateTimeTool = Tool<Map<String, dynamic>>(
  name: 'current_date_time',
  description: 'Get the current date and time',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': <String, dynamic>{}, // OpenAI requires properties field
  }),
  onCall: (_) => DateTime.now().toIso8601String(),
);

/// Tool that converts Fahrenheit to Celsius
final fahrenheitToCelsiusTool = Tool<Map<String, dynamic>>(
  name: 'fahrenheit_to_celsius',
  description: 'Convert a temperature from Fahrenheit to Celsius',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'fahrenheit': {
        'type': 'number',
        'description': 'The temperature in Fahrenheit',
      },
    },
    'required': ['fahrenheit'],
  }),

  onCall: (input) {
    final fahrenheit = input['fahrenheit'] as num;
    final celsius = (fahrenheit - 32) * 5 / 9;
    return {'fahrenheit': fahrenheit, 'celsius': celsius.toStringAsFixed(1)};
  },
);

/// Tool that gets the temperature for a location (returns just the temperature
/// string)
final temperatureTool = Tool<Map<String, dynamic>>(
  name: 'temperature',
  description: 'Get the temperature for a given location',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'location': {
        'type': 'string',
        'description': 'The location to get the temperature for',
      },
    },
    'required': ['location'],
  }),

  onCall: (input) {
    final location = input['location'] as String;
    // This is a mock implementation
    final temp = 20 + Random().nextInt(15);
    return '$temp°C in $location';
  },
);

/// Tool that converts temperature between units
final temperatureConverterTool = Tool<Map<String, dynamic>>(
  name: 'temperature_converter',
  description: 'Convert temperature between Celsius and Fahrenheit',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'value': {
        'type': 'number',
        'description': 'The temperature value to convert',
      },
      'from_unit': {
        'type': 'string',
        'description': 'The unit to convert from (C or F)',
        'enum': ['C', 'F'],
      },
      'to_unit': {
        'type': 'string',
        'description': 'The unit to convert to (C or F)',
        'enum': ['C', 'F'],
      },
    },
    'required': ['value', 'from_unit', 'to_unit'],
  }),

  onCall: (input) {
    final value = input['value'] as num;
    final fromUnit = input['from_unit'] as String;
    final toUnit = input['to_unit'] as String;

    if (fromUnit == toUnit) {
      return {'result': value, 'unit': toUnit};
    }

    final converted = fromUnit == 'C'
        ? (value * 9 / 5) +
              32 // C to F
        : (value - 32) * 5 / 9; // F to C

    return {
      'original': {'value': value, 'unit': fromUnit},
      'converted': {'value': converted.toStringAsFixed(1), 'unit': toUnit},
    };
  },
);

/// Tool that calculates the distance between two cities
final distanceCalculatorTool = Tool<Map<String, dynamic>>(
  name: 'distance_calculator',
  description: 'Calculate the distance between two cities',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'city1': {'type': 'string', 'description': 'First city'},
      'city2': {'type': 'string', 'description': 'Second city'},
    },
    'required': ['city1', 'city2'],
  }),

  onCall: (input) {
    final city1 = input['city1'] as String;
    final city2 = input['city2'] as String;
    // Mock implementation
    final distance = 100 + Random().nextInt(900);
    return {'from': city1, 'to': city2, 'distance': distance, 'unit': 'km'};
  },
);

/// Tool that gets stock price (mock)
final stockPriceTool = Tool<Map<String, dynamic>>(
  name: 'stock_price',
  description: 'Get the current stock price for a ticker symbol',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'symbol': {
        'type': 'string',
        'description': 'Stock ticker symbol (e.g., AAPL, GOOGL)',
      },
    },
    'required': ['symbol'],
  }),

  onCall: (input) {
    final symbol = input['symbol'] as String;
    // Mock implementation
    final price = 100 + Random().nextDouble() * 200;
    final change = -5 + Random().nextDouble() * 10;
    return {
      'symbol': symbol.toUpperCase(),
      'price': price.toStringAsFixed(2),
      'change': change.toStringAsFixed(2),
      'change_percent': (change / price * 100).toStringAsFixed(2),
      'currency': 'USD',
    };
  },
);

/// Recipe lookup tool for chef scenario
final recipeLookupTool = Tool<Map<String, dynamic>>(
  name: 'lookup_recipe',
  description: 'Look up a recipe by name',
  inputSchema: Schema.fromMap({
    'type': 'object',
    'properties': {
      'recipe_name': {
        'type': 'string',
        'description': 'The name of the recipe to look up',
      },
    },
    'required': ['recipe_name'],
  }),

  onCall: (input) {
    final recipeName = input['recipe_name'] as String;
    // Mock recipe database
    if (recipeName.toLowerCase().contains('mushroom') &&
        recipeName.toLowerCase().contains('omelette')) {
      return {
        'name': "Grandma's Mushroom Omelette",
        'ingredients': [
          '3 large eggs',
          '1/4 cup sliced mushrooms',
          '2 tablespoons butter',
          '1/4 cup shredded cheddar cheese',
          'Salt and pepper to taste',
          '1 tablespoon fresh chives',
        ],
        'instructions': [
          'Beat eggs in a bowl with salt and pepper',
          'Heat butter in a non-stick pan over medium heat',
          'Sauté mushrooms until golden, about 3 minutes',
          'Pour beaten eggs over mushrooms',
          'When eggs begin to set, sprinkle cheese on one half',
          'Fold omelette in half and cook until cheese melts',
          'Garnish with fresh chives and serve',
        ],
        'prep_time': '5 minutes',
        'cook_time': '10 minutes',
        'servings': 1,
      };
    }
    return {
      'error': 'Recipe not found',
      'suggestion': 'Try searching for "mushroom omelette"',
    };
  },
);

/// Returns example tools for demonstrations
List<Tool> get exampleTools => [
  currentDateTimeTool,
  weatherTool,
  fahrenheitToCelsiusTool,
  temperatureTool,
  temperatureConverterTool,
  distanceCalculatorTool,
  stockPriceTool,
  recipeLookupTool,
];
