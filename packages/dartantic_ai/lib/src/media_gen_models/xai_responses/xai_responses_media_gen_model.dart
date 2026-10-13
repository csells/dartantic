import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartantic_interface/dartantic_interface.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:mime/mime.dart';

import '../../chat_models/chat_utils.dart';
import 'xai_responses_media_gen_model_options.dart';

/// Media generation model built on top of xAI Images API endpoints.
class XAIResponsesMediaGenerationModel
    extends MediaGenerationModel<XAIResponsesMediaGenerationModelOptions> {
  /// Creates a new xAI media model instance.
  XAIResponsesMediaGenerationModel({
    required super.name,
    required super.defaultOptions,
    required String apiKey,
    Uri? baseUrl,
    http.Client? httpClient,
    Map<String, String>? headers,
    super.tools,
  }) : _apiKey = apiKey,
       _baseUrl = baseUrl ?? Uri.parse('https://api.x.ai/v1'),
       _ownsHttpClient = httpClient == null,
       _client = httpClient ?? http.Client(),
       _headers = headers ?? const {};

  static final Logger _logger = Logger('dartantic.media.models.xai_responses');

  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsHttpClient;
  final Map<String, String> _headers;

  @override
  Stream<MediaGenerationResult> generateMediaStream(
    String prompt, {
    required List<String> mimeTypes,
    List<ChatMessage> history = const [],
    List<Part> attachments = const [],
    XAIResponsesMediaGenerationModelOptions? options,
    Schema? outputSchema,
  }) async* {
    if (outputSchema != null) {
      throw UnsupportedError(
        'xAI media generation does not support output schemas.',
      );
    }
    final wantsImages = mimeTypes.any(_isImageMimeType);
    final wantsVideos = mimeTypes.any(_isVideoMimeType);
    final wantsOtherFiles = mimeTypes.any(
      (m) => !_isImageMimeType(m) && !_isVideoMimeType(m),
    );
    if (wantsOtherFiles || (wantsImages && wantsVideos)) {
      throw UnsupportedError(
        'xAI media generation supports image-only or video-only requests. '
        'Requested: ${mimeTypes.join(', ')}',
      );
    }
    if (wantsImages) {
      yield* _generateImageStream(
        prompt,
        mimeTypes: mimeTypes,
        history: history,
        attachments: attachments,
        options: options,
      );
      return;
    }
    if (wantsVideos) {
      yield* _generateVideoStream(
        prompt,
        mimeTypes: mimeTypes,
        history: history,
        attachments: attachments,
        options: options,
      );
      return;
    }
    throw UnsupportedError(
      'No supported MIME type requested. Requested: ${mimeTypes.join(', ')}',
    );
  }

  Stream<MediaGenerationResult> _generateImageStream(
    String prompt, {
    required List<String> mimeTypes,
    required List<ChatMessage> history,
    required List<Part> attachments,
    XAIResponsesMediaGenerationModelOptions? options,
  }) async* {
    final generationMode = attachments.any(_isImageAttachment)
        ? 'image_editing'
        : 'image_generation';

    _logger.info(
      'Starting xAI media generation with ${history.length} history '
      'messages and MIME types: ${mimeTypes.join(', ')}',
    );

    final resolved = _resolveOptions(defaultOptions, options);
    final requestPrompt = _buildPromptWithTextAttachments(prompt, attachments);
    final imageInputs = _collectImageInputs(attachments);
    final endpoint = imageInputs.isEmpty
        ? 'images/generations'
        : 'images/edits';
    final uri = appendPath(_baseUrl, endpoint);
    final body = _buildRequestBody(
      model: name,
      prompt: requestPrompt,
      imageInputs: imageInputs,
      options: resolved,
    );

    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        ..._headers,
      },
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'xAI images request failed: '
        'HTTP ${response.statusCode} ${response.body}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final (assets, links) = _extractResults(payload);
    final metadata = <String, dynamic>{
      'generation_mode': generationMode,
      'requested_mime_types': mimeTypes,
      'endpoint': endpoint,
      ...?resolved.metadata,
    };

    yield MediaGenerationResult(
      assets: assets,
      links: links,
      metadata: metadata,
      messages: const [],
      finishReason: FinishReason.stop,
      isComplete: true,
    );
  }

  Stream<MediaGenerationResult> _generateVideoStream(
    String prompt, {
    required List<String> mimeTypes,
    required List<ChatMessage> history,
    required List<Part> attachments,
    XAIResponsesMediaGenerationModelOptions? options,
  }) async* {
    final generationMode = attachments.any(_isVideoAttachment)
        ? 'video_editing'
        : 'video_generation';
    _logger.info(
      'Starting xAI video generation with MIME types: ${mimeTypes.join(', ')}',
    );

    final resolved = _resolveOptions(defaultOptions, options);
    final requestPrompt = _buildPromptWithTextAttachments(prompt, attachments);
    final videoInputs = _collectVideoInputs(attachments);
    final endpoint = videoInputs.isEmpty
        ? 'videos/generations'
        : 'videos/edits';
    final uri = appendPath(_baseUrl, endpoint);
    final body = _buildVideoRequestBody(
      model: name,
      prompt: requestPrompt,
      videoInputs: videoInputs,
      options: resolved,
    );
    final startResponse = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        ..._headers,
      },
      body: jsonEncode(body),
    );
    if (startResponse.statusCode < 200 || startResponse.statusCode >= 300) {
      throw Exception(
        'xAI videos start request failed: '
        'HTTP ${startResponse.statusCode} ${startResponse.body}',
      );
    }

    final startPayload = jsonDecode(startResponse.body) as Map<String, dynamic>;
    final requestId = startPayload['request_id'] as String?;
    if (requestId == null || requestId.isEmpty) {
      throw StateError('xAI videos API did not return request_id.');
    }

    final pollEverySeconds = resolved.pollIntervalSeconds ?? 5;
    final timeoutSeconds = resolved.pollTimeoutSeconds ?? 600;
    final pollDeadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
    final pollUri = appendPath(_baseUrl, 'videos/$requestId');
    var pollCount = 0;

    while (true) {
      final pollResponse = await _client.get(
        pollUri,
        headers: {'Authorization': 'Bearer $_apiKey', ..._headers},
      );
      if (pollResponse.statusCode < 200 || pollResponse.statusCode >= 300) {
        throw Exception(
          'xAI videos poll request failed: '
          'HTTP ${pollResponse.statusCode} ${pollResponse.body}',
        );
      }
      final pollPayload = jsonDecode(pollResponse.body) as Map<String, dynamic>;
      final status =
          (pollPayload['status'] as String?)?.toLowerCase() ?? 'pending';
      final metadata = <String, dynamic>{
        'generation_mode': generationMode,
        'requested_mime_types': mimeTypes,
        'endpoint': endpoint,
        'request_id': requestId,
        'status': status,
        'poll_count': pollCount,
        ...?resolved.metadata,
      };

      if (status == 'done') {
        final video = pollPayload['video'] as Map<String, dynamic>?;
        final urlRaw = video?['url'] as String?;
        final links = <LinkPart>[];
        if (urlRaw != null && urlRaw.isNotEmpty) {
          links.add(LinkPart(Uri.parse(urlRaw), mimeType: 'video/mp4'));
        }
        yield MediaGenerationResult(
          links: links,
          metadata: metadata,
          finishReason: FinishReason.stop,
          isComplete: true,
        );
        return;
      }
      if (status == 'expired') {
        throw StateError('xAI video generation request expired: $requestId');
      }
      if (DateTime.now().isAfter(pollDeadline)) {
        throw TimeoutException(
          'xAI video generation timed out after $timeoutSeconds seconds.',
        );
      }

      yield MediaGenerationResult(metadata: metadata, isComplete: false);
      pollCount++;
      await Future.delayed(Duration(seconds: pollEverySeconds));
    }
  }

  @override
  void dispose() {
    if (_ownsHttpClient) _client.close();
  }

  @visibleForTesting
  /// Test-only hook to map a chunk-like result without invoking the network.
  MediaGenerationResult mapChunkForTest(
    ChatResult<ChatMessage> result, {
    required String generationMode,
    required List<String> requestedMimeTypes,
    int chunkIndex = 0,
    List<ChatMessage> accumulatedMessages = const [],
  }) {
    final metadata = <String, dynamic>{
      ...result.metadata,
      'generation_mode': generationMode,
      'requested_mime_types': requestedMimeTypes,
      'chunk_index': chunkIndex,
    };
    final assets = <Part>[];
    final links = <LinkPart>[];
    for (final message in accumulatedMessages) {
      for (final part in message.parts) {
        if (part is DataPart) {
          assets.add(part);
        } else if (part is LinkPart) {
          links.add(part);
        }
      }
    }
    final isComplete = result.finishReason != FinishReason.unspecified;
    return MediaGenerationResult(
      id: result.id,
      assets: assets,
      links: links,
      messages: result.messages,
      metadata: metadata,
      usage: result.usage,
      finishReason: result.finishReason,
      isComplete: isComplete,
    );
  }

  static _ResolvedOptions _resolveOptions(
    XAIResponsesMediaGenerationModelOptions base,
    XAIResponsesMediaGenerationModelOptions? override,
  ) {
    final n = override?.n ?? base.n;
    final aspectRatio = override?.aspectRatio ?? base.aspectRatio;
    final resolution = override?.resolution ?? base.resolution;
    final responseFormat = override?.responseFormat ?? base.responseFormat;
    final durationSeconds = override?.durationSeconds ?? base.durationSeconds;
    final pollIntervalSeconds =
        override?.pollIntervalSeconds ?? base.pollIntervalSeconds;
    final pollTimeoutSeconds =
        override?.pollTimeoutSeconds ?? base.pollTimeoutSeconds;
    final metadata = {
      if (base.metadata != null) ...base.metadata!,
      if (override?.metadata != null) ...override!.metadata!,
    };
    final user = override?.user ?? base.user;

    return _ResolvedOptions(
      n: n,
      aspectRatio: aspectRatio,
      resolution: resolution,
      responseFormat: responseFormat,
      durationSeconds: durationSeconds,
      pollIntervalSeconds: pollIntervalSeconds,
      pollTimeoutSeconds: pollTimeoutSeconds,
      metadata: metadata.isEmpty ? null : metadata,
      user: user,
    );
  }

  bool _isImageMimeType(String value) =>
      value == 'image/*' ||
      value.startsWith('image/') ||
      value == 'image/png' ||
      value == 'image/jpeg' ||
      value == 'image/webp';

  bool _isVideoMimeType(String value) =>
      value == 'video/*' ||
      value.startsWith('video/') ||
      value == 'video/mp4' ||
      value == 'video/webm';

  bool _isImageAttachment(Part part) => switch (part) {
    DataPart(:final mimeType) => mimeType.startsWith('image/'),
    LinkPart(:final mimeType) => (mimeType ?? '').startsWith('image/'),
    _ => false,
  };

  bool _isVideoAttachment(Part part) => switch (part) {
    DataPart(:final mimeType) => mimeType.startsWith('video/'),
    LinkPart(:final mimeType) => (mimeType ?? '').startsWith('video/'),
    _ => false,
  };

  String _buildPromptWithTextAttachments(
    String prompt,
    List<Part> attachments,
  ) {
    final text = attachments
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');
    if (text.isEmpty) return prompt;
    return '$prompt\n\nAdditional context:\n$text';
  }

  List<Map<String, String>> _collectImageInputs(List<Part> attachments) {
    final images = <Map<String, String>>[];
    for (final part in attachments) {
      switch (part) {
        case DataPart(:final bytes, :final mimeType)
            when mimeType.startsWith('image/'):
          images.add({'type': 'image_url', 'url': _toDataUri(bytes, mimeType)});
        case LinkPart(:final url, :final mimeType)
            when (mimeType ?? '').startsWith('image/'):
          images.add({'type': 'image_url', 'url': url.toString()});
        default:
          continue;
      }
    }
    if (images.length > 3) return images.sublist(0, 3);
    return images;
  }

  static String _toDataUri(Uint8List bytes, String mimeType) =>
      'data:$mimeType;base64,${base64Encode(bytes)}';

  Map<String, Object?> _buildRequestBody({
    required String model,
    required String prompt,
    required List<Map<String, String>> imageInputs,
    required _ResolvedOptions options,
  }) {
    final body = <String, Object?>{
      'model': model,
      'prompt': prompt,
      if (options.n != null) 'n': options.n,
      if (options.aspectRatio != null) 'aspect_ratio': options.aspectRatio,
      if (options.resolution != null) 'resolution': options.resolution,
      if (options.responseFormat != null)
        'response_format': options.responseFormat,
      if (options.user != null) 'user': options.user,
    };
    if (imageInputs.length == 1) {
      body['image'] = imageInputs.first;
    } else if (imageInputs.length > 1) {
      body['images'] = imageInputs;
    }
    return body;
  }

  Map<String, Object?> _buildVideoRequestBody({
    required String model,
    required String prompt,
    required List<Map<String, String>> videoInputs,
    required _ResolvedOptions options,
  }) {
    final body = <String, Object?>{
      'model': model,
      'prompt': prompt,
      if (options.durationSeconds != null) 'duration': options.durationSeconds,
      if (options.aspectRatio != null) 'aspect_ratio': options.aspectRatio,
      if (options.resolution != null) 'resolution': options.resolution,
      if (options.user != null) 'user': options.user,
    };
    if (videoInputs.isNotEmpty) {
      body['video'] = videoInputs.first;
    }
    return body;
  }

  List<Map<String, String>> _collectVideoInputs(List<Part> attachments) {
    final videos = <Map<String, String>>[];
    for (final part in attachments) {
      switch (part) {
        case DataPart(:final bytes, :final mimeType)
            when mimeType.startsWith('video/'):
          videos.add({'url': _toDataUri(bytes, mimeType)});
        case LinkPart(:final url, :final mimeType)
            when (mimeType ?? '').startsWith('video/'):
          videos.add({'url': url.toString()});
        default:
          continue;
      }
    }
    return videos;
  }

  (List<Part> assets, List<LinkPart> links) _extractResults(
    Map<String, dynamic> payload,
  ) {
    final assets = <Part>[];
    final links = <LinkPart>[];
    final data = payload['data'];
    if (data is List) {
      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is! Map<String, dynamic>) continue;
        final b64 = item['b64_json'];
        if (b64 is String && b64.isNotEmpty) {
          final bytes = base64Decode(b64);
          final inferredMime =
              lookupMimeType('image.bin', headerBytes: bytes) ?? 'image/png';
          final extension = PartHelpers.extensionFromMimeType(inferredMime);
          final suffix = extension == null || extension.isEmpty
              ? ''
              : '.$extension';
          assets.add(
            DataPart(bytes, mimeType: inferredMime, name: 'image_$i$suffix'),
          );
        }
        final urlRaw = item['url'];
        if (urlRaw is String && urlRaw.isNotEmpty) {
          final uri = Uri.parse(urlRaw);
          final mimeType = PartHelpers.mimeType(uri.path);
          links.add(LinkPart(uri, mimeType: mimeType));
        }
      }
    }
    return (assets, links);
  }
}

class _ResolvedOptions {
  const _ResolvedOptions({
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

  final int? n;
  final String? aspectRatio;
  final String? resolution;
  final String? responseFormat;
  final int? durationSeconds;
  final int? pollIntervalSeconds;
  final int? pollTimeoutSeconds;
  final Map<String, dynamic>? metadata;
  final String? user;
}
