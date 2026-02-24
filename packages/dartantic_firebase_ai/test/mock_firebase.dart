import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the environment has real Firebase credentials for integration tests.
bool get hasFirebaseCredentials =>
    _envOrNull('FIREBASE_API_KEY') != null &&
    _envOrNull('FIREBASE_PROJECT_ID') != null;

/// Initializes Firebase for testing.
///
/// When `FIREBASE_API_KEY` and `FIREBASE_PROJECT_ID` environment variables are
/// set, Firebase is initialized with real credentials so integration tests
/// can make actual API calls. Otherwise a mock configuration is used for
/// unit tests.
Future<void> initializeFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _TestFirebasePlatform();

  final options = hasFirebaseCredentials
      ? FirebaseOptions(
          apiKey: _envOrNull('FIREBASE_API_KEY')!,
          appId: _envOrNull('FIREBASE_APP_ID') ?? '1:0:flutter:0',
          messagingSenderId: _envOrNull('FIREBASE_MESSAGING_SENDER_ID') ?? '0',
          projectId: _envOrNull('FIREBASE_PROJECT_ID')!,
        )
      : const FirebaseOptions(
          apiKey: 'mock-api-key',
          appId: 'mock-app-id',
          messagingSenderId: 'mock-sender-id',
          projectId: 'mock-project-id',
        );

  await Firebase.initializeApp(options: options);

  if (hasFirebaseCredentials) {
    // TestWidgetsFlutterBinding installs HttpOverrides that block all real
    // HTTP requests (returning 400). Reset to allow integration tests to
    // make actual network calls.
    HttpOverrides.global = null;
  }
}

/// Kept for backward compatibility with existing unit tests.
Future<void> initializeMockFirebase() => initializeFirebase();

String? _envOrNull(String name) {
  final value = Platform.environment[name];
  return (value != null && value.isNotEmpty) ? value : null;
}

class _TestFirebasePlatform extends FirebasePlatform {
  _TestFirebasePlatform() : super();

  FirebaseOptions? _options;
  String? _name;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    _name = name ?? defaultFirebaseAppName;
    _options = options;
    return _TestFirebaseApp(name: _name!, options: _options!);
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) =>
      _TestFirebaseApp(
        name: _name ?? name,
        options:
            _options ??
            const FirebaseOptions(
              apiKey: 'mock-api-key',
              appId: 'mock-app-id',
              messagingSenderId: 'mock-sender-id',
              projectId: 'mock-project-id',
            ),
      );
}

class _TestFirebaseApp extends FirebaseAppPlatform {
  _TestFirebaseApp({required String name, required FirebaseOptions options})
    : super(name, options);

  @override
  bool get isAutomaticDataCollectionEnabled => false;
}
