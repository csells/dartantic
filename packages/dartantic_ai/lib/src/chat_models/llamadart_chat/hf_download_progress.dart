/// Progress information for Hugging Face model downloads
class DownloadProgress {
  /// Creates a [DownloadProgress] with the given metrics
  const DownloadProgress({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.elapsed,
    required this.speedMBps,
    this.estimatedRemaining,
  });

  /// Progress as a fraction between 0.0 and 1.0
  final double progress;

  /// Number of bytes downloaded so far
  final int downloadedBytes;

  /// Total size of the file in bytes
  final int totalBytes;

  /// Time elapsed since download started
  final Duration elapsed;

  /// Download speed in megabytes per second
  final double speedMBps;

  /// Estimated time remaining (null until enough samples collected)
  final Duration? estimatedRemaining;

  @override
  String toString() {
    final pct = (progress * 100).toStringAsFixed(1);
    final mb = (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
    final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final elapsedSec = elapsed.inSeconds;
    final etaSec = estimatedRemaining?.inSeconds;
    final speed = speedMBps.toStringAsFixed(2);

    return 'DownloadProgress('
        'progress: $pct%, '
        'downloaded: $mb/$totalMb MB, '
        'elapsed: ${elapsedSec}s, '
        'eta: ${etaSec ?? "?"}s, '
        'speed: $speed MB/s)';
  }
}
