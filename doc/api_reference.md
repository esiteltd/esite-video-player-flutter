# API reference

Everything below is exported from `package:esite_flutter_player/esite_flutter_player.dart`.

---

## `ESitePlayer`

Static entry point for UUID-based playback.

```dart
static void configure({
  required String baseUrl,
  String videoPath = '/videos/{id}/playback',
  ESiteTokenProvider? tokenProvider,
  ESiteVideoMapper? mapper,
  Map<String, String> headers = const {},
  Duration timeout = const Duration(seconds: 20),
})
```

| Parameter | Purpose |
|---|---|
| `baseUrl` | Your app's backend. **Not** the eSITE service. |
| `videoPath` | Path template; must contain `{id}`. |
| `tokenProvider` | Async, called per request. Return `null` to omit the `Authorization` header. |
| `mapper` | Converts a non-`videoDetail` response into an `ESiteResolvedSource`. |
| `headers` | Extra headers on every lookup. |
| `timeout` | Connect and read timeout. |

Throws `ArgumentError` for an empty `baseUrl` or a `videoPath` without `{id}`.

| Member | Description |
|---|---|
| `isConfigured` | Whether `configure()` has run. |
| `configuration` | The active configuration; throws `configurationError` if unset. |
| `reset()` | Clears configuration. For tests. |

### `ESitePlayerConfiguration`

```dart
Future<ESiteResolvedSource> resolve(
  String videoId, {
  ESiteDrmScheme scheme = ESiteDrmScheme.widevine,
})
```

Fetches and interprets playback info. Uses `mapper` when supplied, otherwise the built-in `videoDetail` parser.

---

## `ESitePlayerController`

```dart
static Future<ESitePlayerController> forVideo(
  String videoId, {
  ESitePlaybackOptions options = const ESitePlaybackOptions(),
})
```

Resolves the video, checks it is playable on this platform, and returns a ready controller. Throws `ESitePlayerException`.

```dart
ESitePlayerController(ESitePlayerConfig config)
```

Direct construction, for callers that already hold a manifest URL.

### Streams

| Getter | Type |
|---|---|
| `stateStream` | `Stream<ESitePlayerState>` |
| `drmStream` | `Stream<ESiteDrmEvent>` |
| `errorStream` | `Stream<ESitePlayerError>` |

All broadcast. `currentState` holds the latest state; `config` holds the resolved configuration.

### Methods

| Method | Notes |
|---|---|
| `launchPlayer()` / `initialize()` | Presents the native player. |
| `play()`, `pause()` | |
| `seekTo(Duration)` | Rejects negatives. |
| `seekForward(Duration)`, `seekBackward(Duration)` | Rejects negatives. |
| `setPlaybackSpeed(double)` | Clamped to 0.5–4.0. |
| `setVolume(double)` | Clamped to 0.0–1.0. |
| `setMuted(bool)`, `isMuted()`, `getVolume()` | |
| `getAvailableVideoTracks()` | `[{id, label, width, height, bitrate, frameRate}]`. On iOS, requires 15.0+; older versions return an empty list. |
| `setVideoTrack(String)` | `"auto"` restores adaptive selection. On iOS this caps the peak bitrate — AVPlayer has no direct variant override. |
| `setSubtitleEnabled(bool)`, `isSubtitleEnabled()` | |
| `hasNext()`, `hasPrevious()`, `next()`, `previous()` | Single-item playback; these are no-ops today. |
| `dispose()` | Idempotent. |

Transport methods throw a `NO_PLAYER` `PlatformException` when no player is on screen, and `StateError` after `dispose()`.

---

## Configuration types

### `ESitePlaybackOptions`

| Field | Default | Notes |
|---|---|---|
| `autoPlay` | `false` | |
| `preventScreenshots` | `false` | Android only — iOS cannot block screenshots. |
| `preventScreenRecording` | `false` | `FLAG_SECURE` on Android; capture detection on iOS. |
| `primaryColor` | `null` | Progress bar, scrubber, buffering indicator. |
| `secondaryColor` | `null` | Transport and menu buttons. |

### `ESitePlayerConfig`

| Field | Notes |
|---|---|
| `sourceUrl` | Manifest URL. |
| `drm` | `ESiteDrmConfig?` — **null** for unprotected and Lite DRM. |
| `streamFormat` | `hls`, `dash` or `auto`. |
| `headers` | Applied to manifest, segment and key requests. |
| `autoPlay`, `preventScreenshots`, `preventScreenRecording`, `primaryColor`, `secondaryColor`, `title` | |

`ESitePlayerConfig.fromResolved(source, options)` combines a resolved source with presentation options.

### `ESiteDrmConfig`

| Field | Notes |
|---|---|
| `licenseUrl` | License request / CKC endpoint. |
| `scheme` | `ESiteDrmScheme.widevine` or `.fairplay`. |
| `licenseHeaders` | Typically the entitlement token. |
| `certificateUrl` | FairPlay application certificate. Ignored for Widevine. |

---

## Resolution types

### `ESiteDrmType`

`none`, `lite`, `full`. `parseDrmType(String?)` parses case-insensitively and falls back to `none` for unknown values — the service's spec types `drm_type` as a bare string with no enum.

### `ESiteResolvedSource`

`url`, `streamFormat`, `drmType`, `drm?`, `headers?`, `title?`.

### `ESiteVideoDetail`

Mirrors `manager.videoDetail`: `id`, `name`, `status`, `drmType`, `playbackUrl`, `thumbnailUrl`, `renditions`, plus `raw` for backend-specific fields. `isReady` treats a null status as ready; `bestRendition` picks the highest-resolution rendition with a packaged URL.

### `ESitePlaybackResolver`

```dart
static ESiteResolvedSource resolve(
  ESiteVideoDetail detail, {
  ESiteDrmScheme scheme = ESiteDrmScheme.widevine,
})
```

Pure and platform-agnostic:

- not ready → `videoNotReady`
- `none` / `lite` → HLS, no DRM, no headers
- `full` → DASH + a license descriptor; falls back to the best rendition when `playback_url` is absent

---

## Events and errors

### `ESitePlayerState`

`idle`, `initializing`, `buffering`, `ready`, `playing`, `paused`, `completed`, `error`, `closed`.

`completed` means the media ended; `closed` means the player was dismissed.

### `ESiteDrmEvent`

`type` is `licenseRequested`, `licenseAcquired` or `licenseFailed`, with an optional `message`. Only emitted for full DRM — Lite DRM opens no session.

### `ESitePlayerErrorCode`

Native codes: `invalidSource`, `drmFailure`, `networkError`, `playbackError`, `unknown`.
Resolution codes: `videoNotReady`, `unauthorized`, `videoNotFound`, `unsupportedOnPlatform`, `configurationError`.

> These are wire ordinals shared with the native players. Append only.

### `ESitePlayerException`

Wraps an `ESitePlayerError`; exposes `code` and `message`. Thrown by `forVideo()` and `resolve()`.

---

## `ESitePlayerView`

A launcher widget, not a video surface — it renders a play button and calls `launchPlayer()` on tap. Video renders in the native screen.
