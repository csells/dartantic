// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'dropped_file_converter.dart';

/// Handles drag and drop operations for Flutter Web without native extensions.
class DragAndDropHandler {
  /// Creates a drag and drop handler.
  const DragAndDropHandler({
    required this.onAttachments,
    this.onDragEnter,
    this.onDragExit,
  });

  /// Callback that receives attachments when files are dropped.
  final void Function(Iterable<Part> attachments) onAttachments;

  /// Optional callback when a drag enters the drop zone.
  final VoidCallback? onDragEnter;

  /// Optional callback when a drag exits the drop zone.
  final VoidCallback? onDragExit;

  /// Wraps [child] in a web file drop target.
  Widget buildDropRegion({
    required Widget child,
    HitTestBehavior hitTestBehavior = HitTestBehavior.deferToChild,
  }) {
    return _WebDropRegion(handler: this, child: child);
  }

  /// Web cannot resolve arbitrary file URI drops.
  @visibleForTesting
  Future<Part?> handleDroppedFile(Uri data) async => null;
}

class _WebDropRegion extends StatefulWidget {
  const _WebDropRegion({required this.handler, required this.child});

  final DragAndDropHandler handler;
  final Widget child;

  @override
  State<_WebDropRegion> createState() => _WebDropRegionState();
}

class _WebDropRegionState extends State<_WebDropRegion> {
  late final web.EventListener _dragEnterListener;
  late final web.EventListener _dragOverListener;
  late final web.EventListener _dragLeaveListener;
  late final web.EventListener _dropListener;

  bool _isDraggingInside = false;

  @override
  void initState() {
    super.initState();

    _dragEnterListener = _onDragEnter.toJS;
    _dragOverListener = _onDragOver.toJS;
    _dragLeaveListener = _onDragLeave.toJS;
    _dropListener = _onDrop.toJS;

    web.document.addEventListener('dragenter', _dragEnterListener);
    web.document.addEventListener('dragover', _dragOverListener);
    web.document.addEventListener('dragleave', _dragLeaveListener);
    web.document.addEventListener('drop', _dropListener);
  }

  @override
  void dispose() {
    web.document.removeEventListener('dragenter', _dragEnterListener);
    web.document.removeEventListener('dragover', _dragOverListener);
    web.document.removeEventListener('dragleave', _dragLeaveListener);
    web.document.removeEventListener('drop', _dropListener);
    super.dispose();
  }

  void _onDragEnter(web.Event event) {
    _handleDragMove(event);
  }

  void _onDragOver(web.Event event) {
    _handleDragMove(event);
  }

  void _handleDragMove(web.Event event) {
    final dragEvent = event as web.DragEvent;
    if (!_hasFiles(dragEvent)) return;

    if (!_isInsideRegion(dragEvent)) {
      _setDraggingInside(false);
      return;
    }

    event.preventDefault();
    dragEvent.dataTransfer?.dropEffect = 'copy';
    _setDraggingInside(true);
  }

  void _onDragLeave(web.Event event) {
    final dragEvent = event as web.DragEvent;
    if (!_hasFiles(dragEvent)) return;

    if (!_isInsideRegion(dragEvent)) _setDraggingInside(false);
  }

  void _onDrop(web.Event event) {
    final dragEvent = event as web.DragEvent;
    if (!_hasFiles(dragEvent) || !_isInsideRegion(dragEvent)) return;

    event.preventDefault();
    _setDraggingInside(false);
    unawaited(_handleDrop(dragEvent));
  }

  bool _hasFiles(web.DragEvent event) {
    final dataTransfer = event.dataTransfer;
    if (dataTransfer == null) return false;
    final types = dataTransfer.types.toDart;
    return types.any((type) => type.toDart == 'Files');
  }

  bool _isInsideRegion(web.DragEvent event) {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final x = event.clientX.toDouble();
    final y = event.clientY.toDouble();

    return x >= topLeft.dx &&
        x <= topLeft.dx + size.width &&
        y >= topLeft.dy &&
        y <= topLeft.dy + size.height;
  }

  void _setDraggingInside(bool value) {
    if (_isDraggingInside == value) return;

    _isDraggingInside = value;
    if (value) {
      widget.handler.onDragEnter?.call();
    } else {
      widget.handler.onDragExit?.call();
    }
  }

  Future<void> _handleDrop(web.DragEvent event) async {
    final files = event.dataTransfer?.files;
    if (files == null || files.length == 0) return;

    final parts = <Part>[];
    for (var i = 0; i < files.length; i++) {
      final file = files.item(i);
      if (file == null) continue;

      try {
        final buffer = await file.arrayBuffer().toDart;
        final bytes = Uint8List.view(buffer.toDart);
        parts.add(
          DroppedFileConverter.toDataPart(
            bytes: bytes,
            originalName: file.name,
            browserMimeType: file.type,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Error handling dropped web file: $error');
        debugPrint('$stackTrace');
      }
    }

    if (parts.isNotEmpty) widget.handler.onAttachments(parts);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
