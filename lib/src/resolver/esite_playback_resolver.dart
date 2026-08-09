import '../api/esite_drm_type.dart';
import '../api/esite_video_detail.dart';
import '../config/esite_drm_config.dart';
import '../config/esite_stream_format.dart';
import '../errors/esite_player_error.dart';
import 'esite_resolved_source.dart';

/// Turns a video-detail response into a playable source.
///
/// Platform-agnostic and pure, so it is unit-testable without a device.
/// Callers pass the [ESiteDrmScheme] their platform supports; deciding whether
/// that platform can play the result at all is the controller's job.
abstract final class ESitePlaybackResolver {
  static ESiteResolvedSource resolve(
    ESiteVideoDetail detail, {
    ESiteDrmScheme scheme = ESiteDrmScheme.widevine,
  }) {
    if (!detail.isReady) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.videoNotReady,
          message:
              'Video ${detail.id} is not ready for playback '
              '(status: ${detail.status}).',
        ),
      );
    }

    switch (detail.drmType) {
      case ESiteDrmType.none:
      case ESiteDrmType.lite:
        return _resolveHls(detail);
      case ESiteDrmType.full:
        return _resolveFullDrm(detail, scheme);
    }
  }

  /// Plain and Lite DRM both resolve to the same thing: the token-authenticated
  /// HLS master playlist, played with no DRM session and no headers.
  ///
  /// For Lite DRM the playlist carries `#EXT-X-KEY:METHOD=AES-128` pointing at
  /// the key route; ExoPlayer and AVPlayer fetch and apply that key themselves,
  /// which is why encryption-only content needs no DRM code at all.
  static ESiteResolvedSource _resolveHls(ESiteVideoDetail detail) {
    final url = detail.playbackUrl;
    if (url == null || url.isEmpty) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.invalidSource,
          message:
              'Video ${detail.id} has no playback_url. The service returns '
              'null while no renditions exist yet or when presigning is '
              'unavailable.',
        ),
      );
    }
    return ESiteResolvedSource(
      url: url,
      streamFormat: ESiteStreamFormat.hls,
      drmType: detail.drmType,
      title: detail.name,
    );
  }

  static ESiteResolvedSource _resolveFullDrm(
    ESiteVideoDetail detail,
    ESiteDrmScheme scheme,
  ) {
    // The spec is self-contradictory here: the GET /videos/{id} description
    // calls playback_url "a presigned DASH entry point" for full-DRM videos,
    // while the videoDetail.playback_url field doc says it is null for them and
    // to use rendition URLs. Accept both, preferring playback_url.
    final url = (detail.playbackUrl?.isNotEmpty ?? false)
        ? detail.playbackUrl!
        : detail.bestRendition?.playbackUrl;

    if (url == null || url.isEmpty) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.invalidSource,
          message:
              'Full-DRM video ${detail.id} has neither a playback_url nor a '
              'rendition with a packaged URL.',
        ),
      );
    }

    final drm = _parseDrm(detail, scheme);
    if (drm == null) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.configurationError,
          message:
              'Full-DRM video ${detail.id} carries no license server URL. The '
              'backend must include license_server_url (or drm.license_url) '
              'in its playback response.',
        ),
      );
    }

    return ESiteResolvedSource(
      url: url,
      streamFormat: ESiteStreamFormat.dash,
      drmType: ESiteDrmType.full,
      drm: drm,
      title: detail.name,
    );
  }

  /// Reads the license descriptor tolerantly.
  ///
  /// The video service's own schema carries no license fields ("DRM key
  /// material is never returned"), so the client backend is expected to enrich
  /// its playback response. Both a flat v1-style shape and a nested `drm`
  /// object are accepted.
  static ESiteDrmConfig? _parseDrm(
    ESiteVideoDetail detail,
    ESiteDrmScheme scheme,
  ) {
    final raw = detail.raw;
    final nested = raw['drm'] is Map
        ? Map<String, dynamic>.from(raw['drm'] as Map)
        : const <String, dynamic>{};

    String? pick(String key) {
      final flat = raw[key];
      if (flat is String && flat.isNotEmpty) return flat;
      final inner = nested[key];
      if (inner is String && inner.isNotEmpty) return inner;
      return null;
    }

    final licenseUrl =
        pick('license_server_url') ?? pick('license_url') ?? pick('licenseUrl');
    if (licenseUrl == null) return null;

    final headers = <String, String>{};
    final rawHeaders = nested['headers'] ?? raw['license_headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        if (v != null) headers['$k'] = '$v';
      });
    }

    // A bare entitlement token needs a header name to travel under. The name is
    // configurable because it is licensing-server specific.
    final entitlement =
        pick('entitlement_message') ?? pick('entitlement') ?? pick('token');
    if (entitlement != null) {
      final headerName =
          pick('license_header_name') ?? 'X-Entitlement-Message';
      headers.putIfAbsent(headerName, () => entitlement);
    }

    return ESiteDrmConfig(
      licenseUrl: licenseUrl,
      scheme: scheme,
      licenseHeaders: headers.isEmpty ? null : headers,
      certificateUrl: pick('certificate_url') ?? pick('fairplay_certificate_url'),
    );
  }
}
