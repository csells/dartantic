import 'package:dartantic_interface/dartantic_interface.dart';

const _defaultMimeTypes = <String>['image/jpeg'];

/// Options for configuring xAI Responses media generation runs.
class XAIResponsesMediaGenerationModelOptions
    extends MediaGenerationModelOptions {
  /// Creates a new set of media generation options.
  const XAIResponsesMediaGenerationModelOptions({
    this.mimeTypes = _defaultMimeTypes,
    this.n,
    this.aspectRatio,
    this.resolution,
    this.responseFormat,
    this.durationSeconds,
    this.pollIntervalSeconds,
    this.pollTimeoutSeconds,
    this.metadata,
    this.user,
  });

  /// Number of images to generate in a single request.
  final int? n;

  /// Output aspect ratio, for example `1:1` or `16:9`.
  final String? aspectRatio;

  /// Output resolution, for example `1k` or `2k`.
  final String? resolution;

  /// Response format such as `url` or `b64_json`.
  final String? responseFormat;

  /// Requested video duration in seconds (xAI supports 1-15 for generation).
  final int? durationSeconds;

  /// Polling interval in seconds for asynchronous video generation.
  final int? pollIntervalSeconds;

  /// Polling timeout in seconds for asynchronous video generation.
  final int? pollTimeoutSeconds;

  /// Additional metadata for consumers of media generation results.
  final Map<String, dynamic>? metadata;

  /// End-user identifier forwarded to xAI for abuse monitoring.
  final String? user;

  /// List of MIME types to generate.
  final List<String>? mimeTypes;
}
