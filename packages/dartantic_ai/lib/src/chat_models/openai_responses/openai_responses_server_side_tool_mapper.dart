import 'package:logging/logging.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import 'openai_responses_chat_options.dart';
import 'openai_responses_server_side_tools.dart';

/// Maps Dartantic server-side tool configurations to OpenAI Responses API
/// payloads.
class OpenAIResponsesServerSideToolMapper {
  OpenAIResponsesServerSideToolMapper._();

  static final Logger _logger = Logger(
    'dartantic.chat.models.openai_responses.server_side_tool_mapper',
  );

  /// Converts dartantic tool preferences into OpenAI Responses tool payloads.
  static List<openai.ResponseTool> buildServerSideTools({
    required Set<OpenAIServerSideTool> serverSideTools,
    FileSearchConfig? fileSearchConfig,
    WebSearchConfig? webSearchConfig,
    CodeInterpreterConfig? codeInterpreterConfig,
    ImageGenerationConfig? imageGenerationConfig,
  }) {
    if (serverSideTools.isEmpty) return const [];

    final tools = <openai.ResponseTool>[];

    for (final tool in serverSideTools) {
      switch (tool) {
        case OpenAIServerSideTool.webSearch:
          final config = webSearchConfig;
          tools.add(
            openai.WebSearchTool(
              searchContextSize: _mapSearchContextSize(config?.contextSize),
              userLocation: _mapUserLocation(config?.location),
            ),
          );
          continue;
        case OpenAIServerSideTool.fileSearch:
          final config = fileSearchConfig;
          if (config == null) {
            _logger.warning(
              'File search tool requested but no FileSearchConfig provided; '
              'skipping.',
            );
            continue;
          }
          if (!config.hasVectorStores) {
            _logger.warning(
              'File search tool requested but no vectorStoreIds provided; '
              'skipping.',
            );
            continue;
          }

          openai.FileSearchRankingOptions? rankingOptions;
          if (config.ranker != null || config.scoreThreshold != null) {
            rankingOptions = openai.FileSearchRankingOptions(
              ranker: config.ranker,
              scoreThreshold: config.scoreThreshold?.toDouble(),
            );
          }

          openai.FileSearchFilter? parsedFilter;
          if (config.filters != null && config.filters!.isNotEmpty) {
            parsedFilter = openai.FileSearchFilter.fromJson(config.filters!);
          }

          tools.add(
            openai.FileSearchTool(
              vectorStoreIds: config.vectorStoreIds,
              maxNumResults: config.maxResults,
              rankingOptions: rankingOptions,
              filters: parsedFilter,
            ),
          );
          continue;
        case OpenAIServerSideTool.imageGeneration:
          final config = imageGenerationConfig ?? const ImageGenerationConfig();
          tools.add(
            openai.ImageGenerationTool(
              partialImages: config.partialImages > 0
                  ? config.partialImages
                  : null,
              quality: _mapImageQuality(config.quality),
              size: _mapImageSize(config.size),
            ),
          );
          continue;
        case OpenAIServerSideTool.codeInterpreter:
          final config = codeInterpreterConfig;
          tools.add(
            openai.CodeInterpreterTool(
              container: config?.shouldReuseContainer ?? false
                  ? openai.CodeInterpreterContainer.id(config!.containerId!)
                  : openai.CodeInterpreterContainer.auto(
                      fileIds: config?.fileIds,
                    ),
            ),
          );
          continue;
      }
    }

    return tools;
  }

  static String? _mapSearchContextSize(WebSearchContextSize? size) {
    switch (size) {
      case WebSearchContextSize.low:
        return 'low';
      case WebSearchContextSize.medium:
        return 'medium';
      case WebSearchContextSize.high:
        return 'high';
      case WebSearchContextSize.other:
        throw UnsupportedError(
          'WebSearchContextSize.other is not supported by the OpenAI API.',
        );
      case null:
        return null;
    }
  }

  static openai.ApproximateLocation? _mapUserLocation(
    WebSearchLocation? location,
  ) {
    if (location == null || location.isEmpty) return null;
    return openai.ApproximateLocation(
      city: location.city,
      region: location.region,
      country: location.country,
      timezone: location.timezone,
    );
  }

  static String _mapImageQuality(ImageGenerationQuality quality) =>
      switch (quality) {
        ImageGenerationQuality.low => 'low',
        ImageGenerationQuality.medium => 'medium',
        ImageGenerationQuality.high => 'high',
        ImageGenerationQuality.auto => 'auto',
      };

  static String _mapImageSize(ImageGenerationSize size) => switch (size) {
    ImageGenerationSize.auto => 'auto',
    ImageGenerationSize.square256 => '256x256',
    ImageGenerationSize.square512 => '512x512',
    ImageGenerationSize.square1024 => '1024x1024',
    ImageGenerationSize.landscape1536x1024 => '1536x1024',
    ImageGenerationSize.landscape1792x1024 => '1792x1024',
    ImageGenerationSize.portrait1024x1536 => '1024x1536',
    ImageGenerationSize.portrait1024x1792 => '1024x1792',
  };
}
