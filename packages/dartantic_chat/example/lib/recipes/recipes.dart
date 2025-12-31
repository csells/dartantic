// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/recipe_repository.dart';
import 'data/settings.dart';
import 'pages/edit_recipe_page.dart';
import 'pages/home_page.dart';

const _apiKey = String.fromEnvironment('GEMINI_API_KEY');

void main() async {
  assert(_apiKey.isNotEmpty, 'GEMINI_API_KEY not provided via --dart-define');
  Agent.environment['GEMINI_API_KEY'] = _apiKey;
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.init();
  await RecipeRepository.init();
  runApp(App());
}

class App extends StatelessWidget {
  App({super.key});

  final _router = GoRouter(
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        builder: (BuildContext context, _) => const HomePage(),
        routes: [
          GoRoute(
            name: 'edit',
            path: 'edit/:recipe',
            builder: (context, state) {
              final recipeId = state.pathParameters['recipe']!;
              final recipe = RecipeRepository.getRecipe(recipeId);
              return EditRecipePage(recipe: recipe);
            },
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: _router);
}
