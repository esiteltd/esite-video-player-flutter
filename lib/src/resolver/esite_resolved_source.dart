import '../api/esite_drm_type.dart';
import '../config/esite_drm_config.dart';
import '../config/esite_stream_format.dart';

/// Everything the native player needs to play one video, derived from a
/// backend response by [ESitePlaybackResolver] or by a custom mapper.
class ESiteResolvedSource {
  /// Manifest URL — an HLS master playlist for plain/lite, a DASH manifest
  /// for full DRM.
  final String url;

  final ESiteStreamFormat streamFormat;

  /// What protection the source carries. Drives platform support checks.
  final ESiteDrmType drmType;

  /// Null for plain and Lite DRM — neither needs a DRM session.
  final ESiteDrmConfig? drm;

  /// Headers applied to manifest, segment and key requests.
  ///
  /// Normally null: lite/plain playback URLs are token-authenticated in the
  /// URL itself, so the spec states they need no headers.
  final Map<String, String>? headers;

  /// Display title, when the backend supplies one.
  final String? title;

  const ESiteResolvedSource({
    required this.url,
    required this.streamFormat,
    required this.drmType,
    this.drm,
    this.headers,
    this.title,
  });
}
