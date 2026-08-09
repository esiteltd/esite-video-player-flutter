import 'dart:ui' show Color;

import '../resolver/esite_resolved_source.dart';
import 'esite_drm_config.dart';
import 'esite_playback_options.dart';
import 'esite_stream_format.dart';

/// A fully-resolved playback session.
///
/// Most callers never build this directly — [ESitePlayerController.forVideo]
/// produces it from a video UUID. It stays public for advanced callers that
/// already hold a manifest URL and license details.
class ESitePlayerConfig {
  final String sourceUrl;

  /// Null for unprotected and Lite DRM (AES-128) sources — neither opens a
  /// DRM session.
  final ESiteDrmConfig? drm;

  /// Declares the container so the native players build an explicit media
  /// source instead of sniffing the URL suffix.
  final ESiteStreamFormat streamFormat;

  final Map<String, String>? headers;
  final bool autoPlay;
  final bool preventScreenshots;
  final bool preventScreenRecording;
  final Color? primaryColor;
  final Color? secondaryColor;
  final String? title;

  const ESitePlayerConfig({
    required this.sourceUrl,
    this.drm,
    this.streamFormat = ESiteStreamFormat.auto,
    this.headers,
    this.autoPlay = false,
    this.preventScreenshots = false,
    this.preventScreenRecording = false,
    this.primaryColor,
    this.secondaryColor,
    this.title,
  });

  /// Combines a resolved source with the caller's presentation options.
  factory ESitePlayerConfig.fromResolved(
    ESiteResolvedSource source,
    ESitePlaybackOptions options,
  ) {
    return ESitePlayerConfig(
      sourceUrl: source.url,
      drm: source.drm,
      streamFormat: source.streamFormat,
      headers: source.headers,
      title: source.title,
      autoPlay: options.autoPlay,
      preventScreenshots: options.preventScreenshots,
      preventScreenRecording: options.preventScreenRecording,
      primaryColor: options.primaryColor,
      secondaryColor: options.secondaryColor,
    );
  }
}
