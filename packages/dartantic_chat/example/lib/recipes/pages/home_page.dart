import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:dartantic_chat/dartantic_chat.dart';
import 'package:go_router/go_router.dart';

import '../data/recipe_repository.dart';
import '../data/settings.dart';
import '../views/recipe_list_view.dart';
import '../views/recipe_response_view.dart';
import '../views/search_box.dart';
import '../views/settings_drawer.dart';
import 'split_or_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _searchText = '';

  late ChatHistoryProvider _provider = _createProvider();

  // create a new provider with the given history and the current settings
  ChatHistoryProvider _createProvider([List<ChatMessage>? history]) =>
      DartanticProvider(
        history: history,
        agent: Agent('gemini'),
        systemPrompt: '''
You are a helpful assistant that generates recipes based on the ingredients and
instructions provided as well as my food preferences, which are as follows:
${Settings.foodPreferences.isEmpty ? 'I don\'t have any food preferences' : Settings.foodPreferences}

You should keep things casual and friendly. You may generate multiple recipes in
a single response, but only if asked. Generate each response in JSON format
with the following schema, including one or more "text" and "recipe" pairs as
well as any trailing text commentary you care to provide:

{
  "recipes": [
    {
      "text": "Any commentary you care to provide about the recipe.",
      "recipe":
      {
        "title": "Recipe Title",
        "description": "Recipe Description",
        "ingredients": ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
        "instructions": ["Instruction 1", "Instruction 2", "Instruction 3"]
      }
    }
  ],
  "text": "any final commentary you care to provide",
}
''',
      );

  final _welcomeMessage =
      'Hello and welcome to the Recipes sample app!\n\nIn this app, you can '
      'generate recipes based on the ingredients and instructions provided '
      'as well as your food preferences.\n\nIt also demonstrates several '
      'real-world use cases for Dartantic Chat.\n\nEnjoy!';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Example: Recipes'),
      actions: [
        IconButton(
          onPressed: _onAdd,
          tooltip: 'Add Recipe',
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    drawer: Builder(
      builder: (context) => SettingsDrawer(onSave: _onSettingsSave),
    ),
    body: SplitOrTabs(
      tabs: const [Tab(text: 'Recipes'), Tab(text: 'Chat')],
      children: [
        Column(
          children: [
            SearchBox(onSearchChanged: _updateSearchText),
            Expanded(child: RecipeListView(searchText: _searchText)),
          ],
        ),
        AgentChatView(
          provider: _provider,
          welcomeMessage: _welcomeMessage,
          responseBuilder: (context, response) => RecipeResponseView(response),
        ),
      ],
    ),
  );

  void _updateSearchText(String text) => setState(() => _searchText = text);

  void _onAdd() => context.goNamed(
    'edit',
    pathParameters: {'recipe': RecipeRepository.newRecipeID},
  );

  void _onSettingsSave() => setState(() {
    // move the history over from the old provider to the new one
    final history = _provider.history.toList();
    _provider = _createProvider(history);
  });
}
