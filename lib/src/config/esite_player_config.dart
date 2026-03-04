import 'dart:ui' show Color;

import 'esite_drm_config.dart';

class ESitePlayerConfig {
  final String sourceUrl;
  final ESiteDrmConfig drm;
  final Map<String, String>? headers;
  final bool autoPlay;
  final bool preventScreenshots;
  final bool preventScreenRecording;
  final Color? primaryColor;
  final Color? secondaryColor;

  const ESitePlayerConfig({
    required this.sourceUrl,
    required this.drm,
    this.headers,
    this.autoPlay = false,
    this.preventScreenshots = false,
    this.preventScreenRecording = false,
    this.primaryColor,
    this.secondaryColor,
  });
}
