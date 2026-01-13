// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Style for the file drop overlay in the chat view.
@immutable
class FileDropOverlayStyle {
  /// Creates a style for the file drop overlay.
  const FileDropOverlayStyle({
    this.iconSize = 64.0,
    this.iconColor,
    this.textStyle,
    this.backgroundColor,
  });

  /// The size of the upload icon.
  final double iconSize;

  /// The color of the upload icon.
  final Color? iconColor;

  /// The text style for the drop hint text.
  final TextStyle? textStyle;

  /// The background color of the overlay.
  final Color? backgroundColor;

  /// Creates a copy of this style with the given fields replaced by the new values.
  FileDropOverlayStyle copyWith({
    double? iconSize,
    Color? iconColor,
    TextStyle? textStyle,
    Color? backgroundColor,
  }) {
    return FileDropOverlayStyle(
      iconSize: iconSize ?? this.iconSize,
      iconColor: iconColor ?? this.iconColor,
      textStyle: textStyle ?? this.textStyle,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  /// Resolves the provided [style] with the [defaultStyle].
  static FileDropOverlayStyle resolve(
    FileDropOverlayStyle? style, {
    FileDropOverlayStyle? defaultStyle,
  }) {
    defaultStyle ??= FileDropOverlayStyle.defaultStyle();
    if (style == null) return defaultStyle;

    return FileDropOverlayStyle(
      iconSize: style.iconSize,
      iconColor: style.iconColor ?? defaultStyle.iconColor,
      textStyle: style.textStyle ?? defaultStyle.textStyle,
      backgroundColor: style.backgroundColor ?? defaultStyle.backgroundColor,
    );
  }

  /// Provides default style if none is specified.
  factory FileDropOverlayStyle.defaultStyle() => _lightStyle();

  /// Provides a default light style.
  static FileDropOverlayStyle _lightStyle() {
    return const FileDropOverlayStyle(
      iconSize: 64.0,
      textStyle: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
    );
  }
}
