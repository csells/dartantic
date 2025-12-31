// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A library for integrating AI-powered chat functionality into Flutter
/// applications.
///
/// This library provides a set of tools and widgets to easily incorporate AI
/// language models into your Flutter app, enabling interactive chat experiences
/// with various AI providers.
///
/// Key components:
/// - Chat history providers: Interfaces and implementations for different AI
///   services.
/// - Chat UI: Ready-to-use widgets for displaying chat interfaces.
library;

export 'package:dartantic_interface/dartantic_interface.dart'
    show ChatMessage, ChatMessageRole, Part, DataPart, LinkPart, TextPart;

export 'src/llm_exception.dart';
export 'src/providers/providers.dart';
export 'src/styles/styles.dart';
export 'src/views/agent_chat_view/agent_chat_view.dart';
