import 'package:dartantic_ai/dartantic_ai.dart';
import 'package:test/test.dart';

void main() {
  group('DownloadProgress', () {
    test('all fields are accessible', () {
      const progress = DownloadProgress(
        progress: 0.5,
        downloadedBytes: 500000,
        totalBytes: 1000000,
        elapsed: Duration(seconds: 10),
        estimatedRemaining: Duration(seconds: 10),
        speedMBps: 0.048,
      );

      expect(progress.progress, 0.5);
      expect(progress.downloadedBytes, 500000);
      expect(progress.totalBytes, 1000000);
      expect(progress.elapsed, const Duration(seconds: 10));
      expect(progress.estimatedRemaining, const Duration(seconds: 10));
      expect(progress.speedMBps, 0.048);
    });

    test('handles null estimatedRemaining', () {
      const progress = DownloadProgress(
        progress: 0.1,
        downloadedBytes: 100000,
        totalBytes: 1000000,
        elapsed: Duration(seconds: 2),
        speedMBps: 0.048,
      );

      expect(progress.estimatedRemaining, isNull);
    });

    test('toString includes all metrics', () {
      const progress = DownloadProgress(
        progress: 0.75,
        downloadedBytes: 750000,
        totalBytes: 1000000,
        elapsed: Duration(seconds: 15),
        speedMBps: 0.048,
        estimatedRemaining: Duration(seconds: 5),
      );

      final str = progress.toString();
      expect(str, contains('75'));
      expect(str, contains('0.7'));
      expect(str, contains('1.0'));
      expect(str, contains('15'));
      expect(str, contains('5'));
      expect(str, contains('0.05'));
    });

    test('toString handles null estimatedRemaining', () {
      const progress = DownloadProgress(
        progress: 0.1,
        downloadedBytes: 100000,
        totalBytes: 1000000,
        elapsed: Duration(seconds: 2),
        speedMBps: 0.048,
      );

      final str = progress.toString();
      expect(str, contains('10'));
      expect(str, contains('0.1'));
      expect(str, contains('1.0'));
      expect(str, contains('0.05'));
      expect(str, contains('?'));
      // Should not throw when estimatedRemaining is null
    });
  });
}
