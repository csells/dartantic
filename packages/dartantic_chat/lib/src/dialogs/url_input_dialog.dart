// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Result of URL input dialog containing the URL and display name.
class UrlInputResult {
  /// Creates a [UrlInputResult] with the given [url] and [name].
  const UrlInputResult({required this.url, required this.name});

  /// The URL entered by the user.
  final Uri url;

  /// The display name derived from the URL.
  final String name;
}

/// Shows a dialog to input a URL and returns a [UrlInputResult].
///
/// The dialog is platform-aware and will show either a Material or Cupertino
/// style dialog based on the current platform. The dialog includes:
/// - A text field for entering a URL
/// - Input validation to ensure a valid URL is entered
/// - Proper error messages for invalid input
///
/// Returns:
/// - A [UrlInputResult] if a valid URL is entered and submitted
/// - `null` if the dialog is dismissed or cancelled
///
/// Example:
/// ```dart
/// final result = await showUrlInputDialog(context);
/// if (result != null) {
///   // Handle the URL with result.url and result.name
/// }
/// ```
Future<UrlInputResult?> showUrlInputDialog(BuildContext context) async {
  final controller = TextEditingController();
  String? errorText;

  final result = await showDialog<UrlInputResult?>(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Theme.of(context).platform == TargetPlatform.iOS
              ? CupertinoAlertDialog(
                  title: const Text('Attach URL'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: controller,
                        placeholder: 'https://flutter.dev',
                        keyboardType: TextInputType.url,
                        autofocus: true,
                        onChanged: (value) {
                          if (errorText != null) {
                            setState(() => errorText = null);
                          }
                        },
                      ),
                      if (errorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: CupertinoColors.systemRed,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () {
                        final attachment = _validateAndCreateResult(
                          controller.text,
                        );
                        if (attachment != null) {
                          Navigator.of(context).pop(attachment);
                        } else {
                          setState(
                            () => errorText = 'Please enter a valid URL',
                          );
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                )
              : AlertDialog(
                  title: const Text('Attach URL'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: 'https://flutter.dev',
                          errorText: errorText,
                        ),
                        keyboardType: TextInputType.url,
                        autofocus: true,
                        onChanged: (value) {
                          if (errorText != null) {
                            setState(() => errorText = null);
                          }
                        },
                        onSubmitted: (value) {
                          final attachment = _validateAndCreateResult(value);
                          if (attachment != null) {
                            Navigator.of(context).pop(attachment);
                          } else {
                            setState(
                              () => errorText = 'Please enter a valid URL',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        final attachment = _validateAndCreateResult(
                          controller.text,
                        );
                        if (attachment != null) {
                          Navigator.of(context).pop(attachment);
                        } else {
                          setState(
                            () => errorText = 'Please enter a valid URL',
                          );
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                );
        },
      );
    },
  );

  return result;
}

UrlInputResult? _validateAndCreateResult(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  try {
    final uri = Uri.parse(trimmed);
    if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return UrlInputResult(
      name: uri.host.isNotEmpty ? uri.host : trimmed,
      url: uri,
    );
  } catch (e) {
    return null;
  }
}
