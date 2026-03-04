## 0.2.0

Major architecture overhaul: native Android Activity for DRM playback with YouTube-like UX.

### Breaking Changes

* **Native Activity playback**: Video now plays in a dedicated native Android Activity instead of an embedded PlatformView. This fixes the black screen issue on physical devices with Widevine L1 DRM.
* `ESitePlayerView` is now a launch placeholder widget (tap to open the native player).

### New Features

* **YouTube-like double-tap seek**: Double-tap left/right to seek backward/forward 10 seconds with ripple animation. Sequential taps accumulate (+20s, +30s, etc.).
* **Configurable theme colors**: `primaryColor` and `secondaryColor` on `ESitePlayerConfig` control the seek bar, scrubber, buffering ring, and button tints.
* **Buffering ring**: Circular loading indicator wraps around the play/pause button during buffering (replaces default center spinner).
* **Gradient overlays**: Semi-transparent dim + top/bottom gradients make controls visible on bright video content.
* **Material Design icons**: Speed (speedometer), quality (HD badge), and audio (music note) icons replace generic system drawables.
* **Custom controller layout**: Center play/pause/rewind/forward + bottom bar with large seek thumb, time display, and speed/quality/audio buttons.
* **DRM L1 to L3 fallback**: Automatically falls back from Widevine L1 to L3 on devices that don't support L1.
* **Comprehensive error handling**: Detailed error overlay with retry for network, DRM, source, parsing, and decoder errors.
* **Adaptive bitrate**: DefaultTrackSelector with automatic quality switching based on bandwidth.
* **ESite API integration**: Example app includes live API entitlement fetch scenario.

### Improvements

* Dropdown menus (speed, quality, audio) now appear above their anchor buttons (fixed positioning).
* Bigger seek bar thumb (20dp) with 48dp touch target for easier seeking.
* `launchPlayer()` method on controller for explicit player launch.

## 0.1.0

Initial release of eSite Flutter Player.

### Features

* **DRM Support**: Widevine DRM playback with Axinom integration
* **Playback Controls**: Play, pause, seek, speed control (0.5x-4x), volume control
* **Security**: Screenshot and screen recording protection (FLAG_SECURE)
* **Track Selection**: Video quality selection and subtitle toggle
* **Event Streams**: Real-time playback state, DRM events, and error handling
* **Platform**: Full Android support with ExoPlayer Media3

### Requirements

* Flutter SDK >=3.3.0
* Android API 24+
* Physical device recommended for DRM testing
