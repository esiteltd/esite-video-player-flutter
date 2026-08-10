## 0.4.1

### Fixed

* **Android controls no longer sit under the status bar or against the screen
  edge.** The plugin targets SDK 36, and Android 15+ enforces edge-to-edge:
  `setDecorFitsSystemWindows(window, true)` is ignored, so the window always
  extended under the system bars and the display cutout while the top bar had
  only a fixed 8dp padding. The back button ended up beneath the status bar on
  affected devices.

  The control bars are now padded from the real window insets — the union of
  `systemBars()` and `displayCutout()`, since a hidden bar reports a zero inset
  while the notch it was covering is still there — plus a 16dp base so nothing
  sits flush against the edge in immersive mode, plus a rounded-corner
  allowance from `WindowInsets.getRoundedCorner()` on API 31+.

  The activity also declares `windowLayoutInDisplayCutoutMode="shortEdges"`, so
  video fills the cutout area while the controls stay clear of it, and it now
  goes edge to edge on every API level rather than only on the versions that
  force it — so the layout is identical from API 24 to 36 instead of breaking
  on new releases.

  iOS was already correct: its bars are constrained to `safeAreaLayoutGuide`,
  which covers the notch, Dynamic Island and home indicator.

## 0.4.0

Fullscreen and close controls on both platforms, and a rebuilt native iOS player
scoped to the protection modes the video service actually ships.

### New Features

* **Fullscreen button.** Toggles between landscape and portrait and hides or
  restores the system bars. On Android the rotation does not recreate the
  Activity, so playback continues across the toggle; on iOS the orientation is
  pinned through `requestGeometryUpdate` (iOS 16+) and released again on close,
  so the Flutter screen underneath is never left rotated. Both platforms keep
  the icon in sync when the device is rotated by hand instead.
* **Close button.** A back arrow in the top bar dismisses the player and reports
  `closed` (8), the same as any other dismissal. Replaces the iOS `xmark`.

### iOS Player

Rewritten. Behaviour that was missing rather than merely unpolished:

* **Audio session handling** — a call or another app taking the session pauses
  playback and resumes only when the system says it should; unplugging
  headphones pauses instead of switching to the speaker.
* **Backgrounding** pauses playback, matching Android's `onStop`.
* **Live streams** are detected and show a LIVE badge instead of a dead
  scrubber pinned at zero.
* **Scrubbing** no longer fights the periodic time observer mid-drag, and the
  controls can no longer auto-hide under your finger.
* **Buffered range** is drawn behind the scrubber, matching Android's
  `DefaultTimeBar`.
* **Retry** no longer tears down the screen-capture, lifecycle and audio-session
  observers along with the media item — previously one retry silently disabled
  capture protection for the rest of the session.
* `AVPlayerItemFailedToPlayToEndTime` is now handled, gradient scrims match the
  Android drawables, and the status bar follows the fullscreen state.

### Changed

* **Full DRM is rejected explicitly on iOS.** `ESiteContentKeyManager` and its
  half-wired `AVContentKeySession` seam are removed: a config carrying a `drm`
  block now fails immediately with `unsupportedOnPlatform` and a
  `licenseFailed` DRM event, rather than building a player that could only ever
  error. Lite DRM is unaffected — AES-128 HLS needs no DRM session, so it never
  went through that path. `ESiteDrmScheme.fairplay` is kept for wire
  compatibility but is documented as unimplemented pending FairPlay packaging
  on the video service.
* Android gains an explicit `androidx.core:core` dependency for the immersive
  fullscreen APIs, rather than relying on appcompat's transitive copy.

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
