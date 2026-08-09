import 'dart:ui' show Color;

/// Presentation and security options applied to a playback session.
///
/// Separate from the source itself, so playing by UUID needs no knowledge of
/// manifests or license servers.
class ESitePlaybackOptions {
  final bool autoPlay;

  /// Blocks screenshots. Enforced on Android via `FLAG_SECURE`.
  ///
  /// iOS has no equivalent — screenshots can only be *detected* after the
  /// fact, never blocked. See the README for what iOS actually enforces.
  final bool preventScreenshots;

  /// Blanks and pauses playback while the screen is being captured or mirrored.
  /// Enforced on Android via `FLAG_SECURE`, on iOS by observing
  /// `UIScreen.isCaptured`.
  final bool preventScreenRecording;

  /// Progress bar and buffering indicator colour.
  final Color? primaryColor;

  /// Transport control (play/pause, seek, menu button) colour.
  final Color? secondaryColor;

  const ESitePlaybackOptions({
    this.autoPlay = false,
    this.preventScreenshots = false,
    this.preventScreenRecording = false,
    this.primaryColor,
    this.secondaryColor,
  });
}
