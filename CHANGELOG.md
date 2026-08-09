## 0.3.0

UUID-first playback against the eSITE Video Service, Lite DRM support, and a native iOS player.

### Breaking Changes

* **Play by video UUID.** `ESitePlayer.configure()` + `ESitePlayerController.forVideo(videoId)` replace hand-built manifest and license configuration. `ESitePlayerConfig` remains for advanced callers.
* **`ESitePlayerConfig.drm` is now nullable.** Unprotected and Lite DRM sources open no DRM session.
* **Axinom removed.** Playback resolves against the eSITE Video Service via your own backend. `ESiteDrmScheme.playready` was dropped; `fairplay` was added.
* **`ESitePlayerState.closed` (8) added.** Dismissing the player now reports `closed` instead of `completed`, so a finished video is distinguishable from an abandoned one.
* New error codes: `videoNotReady`, `unauthorized`, `videoNotFound`, `unsupportedOnPlatform`, `configurationError`. Existing codes keep their ordinals.

### New Features

* **Lite DRM** — AES-128 encrypted HLS. Needs no DRM session, license server or headers on either platform.
* **Native iOS player** — a fullscreen `UIViewController` backed by `AVPlayerLayer`, mirroring the Android Activity: play/pause, ±10s double-tap seek with the same animation, scrubber, speed/quality/audio menus, error overlay with retry, and theme colours.
* **Backend-agnostic resolution** — defaults to the eSITE `videoDetail` shape (pass-through backends need no mapping) with an optional `mapper` for other shapes.
* **Transport methods now work.** `play`, `pause`, `seekTo`, `setVolume`, track and subtitle selection were previously `notImplemented()` on the native side; they are wired on both platforms.
* **Explicit stream format** — HLS/DASH is declared rather than sniffed from the URL suffix, which token-authenticated playback URLs break.

### Fixes

* **The L1→L3 DRM fallback never worked.** `buildDrmSessionManager()` was dead code — its result was never wired into ExoPlayer, and it leaked an unreleased `FrameworkMediaDrm` per initialisation. Removed; the security level is now read and reported accurately.
* `licenseFailed` DRM events were emitted for *every* playback error, including network and decoder failures. Now only for actual DRM errors.
* `licenseAcquired` was reported at initialisation rather than on real key acquisition.

### Known Limitations

* **Full DRM does not play on iOS.** It is packaged as DASH + Widevine; FairPlay HLS packaging is pending on the backend. Such videos fail with `unsupportedOnPlatform`.
* **iOS cannot block screenshots.** `preventScreenRecording` is enforced by hiding video during capture; screenshots can only be detected, never prevented.

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

* **DRM Support**: Widevine DRM playback
* **Playback Controls**: Play, pause, seek, speed control (0.5x-4x), volume control
* **Security**: Screenshot and screen recording protection (FLAG_SECURE)
* **Track Selection**: Video quality selection and subtitle toggle
* **Event Streams**: Real-time playback state, DRM events, and error handling
* **Platform**: Full Android support with ExoPlayer Media3

### Requirements

* Flutter SDK >=3.3.0
* Android API 24+
* Physical device recommended for DRM testing
