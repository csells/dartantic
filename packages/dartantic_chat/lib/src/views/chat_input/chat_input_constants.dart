// Copyright 2026 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared constants for ChatInput layout calculations.
///
/// These constants are derived from the actual padding values used in
/// TextOrAudioInput and ChatTextField widgets to ensure consistent
/// alignment and prevent duplication of magic numbers.
class ChatInputConstants {
  ChatInputConstants._();

  // TextOrAudioInput padding values (from EdgeInsets.only in build method)
  /// Horizontal padding in TextOrAudioInput: 16.0 left + 16.0 right
  static const double textOrAudioInputHorizontalPadding = 32.0;

  /// Left padding in TextOrAudioInput for caret offset calculation
  static const double textOrAudioInputLeftPadding = 16.0;

  /// Base top padding in TextOrAudioInput
  static const double textOrAudioInputBaseTopPadding = 8.0;

  /// Additional top padding when in edit mode (24.0 vs 8.0)
  static const double textOrAudioInputEditModeAdditionalPadding = 16.0;

  // ChatTextField padding values (from hintPadding parameter)
  /// Horizontal padding in ChatTextField: 12.0 * 2 (from EdgeInsets.symmetric)
  static const double chatTextFieldHorizontalPadding = 24.0;

  /// Horizontal padding in ChatTextField for caret offset calculation
  static const double chatTextFieldPadding = 12.0;

  /// Vertical padding in ChatTextField (from EdgeInsets.symmetric)
  static const double chatTextFieldVerticalPadding = 8.0;
}
