// Copyright 2025 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

export 'drag_and_drop_handler_stub.dart'
    if (dart.library.io) 'drag_and_drop_handler_native.dart'
    if (dart.library.js_interop) 'drag_and_drop_handler_web.dart';
