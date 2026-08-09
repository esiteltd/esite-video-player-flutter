import '../config/esite_drm_config.dart';
import '../errors/esite_player_error.dart';
import '../resolver/esite_playback_resolver.dart';
import '../resolver/esite_resolved_source.dart';
import 'esite_video_api.dart';
import 'esite_video_detail.dart';
import 'esite_video_mapper.dart';

/// Resolved plugin settings: where to ask for playback info, and how to read
/// the answer.
class ESitePlayerConfiguration {
  final ESiteVideoApi api;
  final ESiteVideoMapper? mapper;

  const ESitePlayerConfiguration({required this.api, this.mapper});

  /// Fetches and interprets playback info for [videoId].
  ///
  /// Uses the caller-supplied [mapper] when present, otherwise parses the
  /// eSITE `videoDetail` shape — so a backend that proxies the eSITE response
  /// through unchanged needs no mapping code.
  Future<ESiteResolvedSource> resolve(
    String videoId, {
    ESiteDrmScheme scheme = ESiteDrmScheme.widevine,
  }) async {
    final json = await api.fetchVideo(videoId);
    final customMapper = mapper;
    if (customMapper != null) {
      try {
        return customMapper(json);
      } on ESitePlayerException {
        rethrow;
      } catch (e) {
        throw ESitePlayerException(
          ESitePlayerError(
            code: ESitePlayerErrorCode.configurationError,
            message: 'The configured mapper failed for video $videoId: $e',
          ),
        );
      }
    }
    return ESitePlaybackResolver.resolve(
      ESiteVideoDetail.fromJson(json),
      scheme: scheme,
    );
  }
}

/// Entry point for UUID-based playback.
///
/// Configure once at app start, then play videos by UUID:
///
/// ```dart
/// ESitePlayer.configure(
///   baseUrl: 'https://api.myapp.com',
///   tokenProvider: () async => auth.accessToken,
/// );
///
/// final controller = await ESitePlayerController.forVideo(videoId);
/// await controller.launchPlayer();
/// ```
///
/// [baseUrl] is the **client app's own backend**, not the eSITE video service.
/// That backend holds the tenant API key and talks to eSITE server-to-server,
/// so the key never ships inside the app.
abstract final class ESitePlayer {
  static ESitePlayerConfiguration? _configuration;

  /// Default path template on the client backend. `{id}` is replaced with the
  /// video UUID.
  static const defaultVideoPath = '/videos/{id}/playback';

  static void configure({
    required String baseUrl,
    String videoPath = defaultVideoPath,
    ESiteTokenProvider? tokenProvider,
    ESiteVideoMapper? mapper,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 20),
  }) {
    if (baseUrl.trim().isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'must not be empty');
    }
    if (!videoPath.contains('{id}')) {
      throw ArgumentError.value(
        videoPath,
        'videoPath',
        'must contain the {id} placeholder',
      );
    }
    _configuration = ESitePlayerConfiguration(
      api: ESiteVideoApi(
        baseUrl: baseUrl,
        videoPath: videoPath,
        tokenProvider: tokenProvider,
        extraHeaders: headers,
        timeout: timeout,
      ),
      mapper: mapper,
    );
  }

  static bool get isConfigured => _configuration != null;

  static ESitePlayerConfiguration get configuration {
    final config = _configuration;
    if (config == null) {
      throw ESitePlayerException(
        const ESitePlayerError(
          code: ESitePlayerErrorCode.configurationError,
          message:
              'ESitePlayer.configure() must be called before playing by video '
              'id.',
        ),
      );
    }
    return config;
  }

  /// Clears configuration. Intended for tests.
  static void reset() => _configuration = null;
}
