// ignore_for_file: avoid_print

import 'dart:io';

import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:dartantic_ai/src/platform/platform.dart';
import 'package:test/test.dart';

void main() {
  group('Agent.environment and getEnv', () {
    const testKey = 'DARTANTIC_AI_TEST_KEY';
    const testValue = 'test_value';
    final pathKey = Platform.isWindows ? 'Path' : 'PATH';

    tearDown(() {
      Agent.environment.remove(testKey);
      Agent.environment.remove(pathKey);
    });

    test('getEnv finds key in Agent.environment', () {
      Agent.environment[testKey] = testValue;
      expect(getEnv(testKey), testValue);
    });

    test('getEnv finds existing key in Platform.environment', () {
      final pathValue = Platform.environment[pathKey];
      if (pathValue != null) {
        expect(getEnv(pathKey), pathValue);
      } else {
        print('Skipping test: $pathKey environment variable not found.');
      }
    });

    test('Agent.environment is prioritized over Platform.environment', () {
      final platformPath = Platform.environment[pathKey];
      if (platformPath != null) {
        Agent.environment[pathKey] = testValue;
        expect(getEnv(pathKey), testValue);
        expect(getEnv(pathKey), isNot(platformPath));
      } else {
        print('Skipping test: $pathKey environment variable not found.');
      }
    });

    test('getEnv throws if key is not found', () {
      const nonExistentKey = 'THIS_KEY_SHOULD_NOT_EXIST_ANYWHERE';
      expect(
        () => getEnv(nonExistentKey),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('$nonExistentKey not found'),
          ),
        ),
      );
    });

    test('getEnv allows empty string values', () {
      Agent.environment[testKey] = '';
      expect(getEnv(testKey), '');
    });
  });
}
