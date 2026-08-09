# esite_flutter_player

Secure video playback for Flutter, backed by the **eSITE Video Service**.

Give the plugin a video UUID. It resolves the video through your backend, works out whether it is unprotected, **Lite DRM** or **Full DRM**, and plays it in a native fullscreen player on Android and iOS.

```dart
ESitePlayer.configure(
  baseUrl: 'https://api.myapp.com',
  tokenProvider: () async => auth.accessToken,
);

final controller = await ESitePlayerController.forVideo(videoId);
await controller.launchPlayer();
```

No manifest URLs, no license servers, no DRM branching in your app.

📖 **[Full documentation](doc/index.html)** — open in a browser, or read the Markdown in [`doc/`](doc/).

---

## Contents

- [How it fits together](#how-it-fits-together)
- [Protection modes](#protection-modes)
- [Install](#install)
- [Quick start](#quick-start)
- [What your backend must return](#what-your-backend-must-return)
- [API reference](#api-reference)
- [Playback control](#playback-control)
- [Errors](#errors)
- [Security](#security)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Known limitations](#known-limitations)

---

## How it fits together

```
Flutter app ──access token──▶ your backend ──X-API-Key──▶ eSITE Video Service
  (plugin)                    (server-to-server)
```

The plugin **never talks to the eSITE service directly**. Your backend holds the tenant API key and calls `GET /api/v1/videos/{id}` on eSITE; the plugin authenticates to *your* backend with a token your app already has.

> **Why.** The eSITE tenant API key authenticates at **UPLOADER or higher** — which includes upload and, for EDITOR/ADMIN, delete. It is not a read-only playback credential, and anything shipped in an APK or IPA is extractable. Do not pass an eSITE key through `ESitePlayer.configure(headers: …)` to shortcut the integration.

## Protection modes

| `drm_type` | Delivery | What the player does | Android | iOS |
|---|---|---|---|---|
| *(none)* | HLS | Plays directly | ✅ | ✅ |
| `lite` | HLS with AES-128 encrypted segments | Player fetches the key from the playlist's key route — no DRM session | ✅ | ✅ |
| `full` | DASH + license server | Opens a Widevine session | ✅ | ❌ |

**Lite DRM is standard HLS AES-128 encryption.** Both ExoPlayer and AVPlayer handle it natively, which is why it needs no DRM configuration, no license server and no extra headers — the playback URL is token-authenticated in the URL itself.

### Full DRM on iOS

Full-DRM content is packaged as DASH + Widevine. AVPlayer plays neither. Supporting it on iOS requires the video service to *also* package CBCS fMP4 HLS and expose a FairPlay SPC/CKC endpoint plus an application certificate — **that backend work is pending**.

Until then, `forVideo()` throws `ESitePlayerErrorCode.unsupportedOnPlatform` for full-DRM videos on iOS rather than showing a black screen. The FairPlay wiring is stubbed in `ios/Classes/ESiteContentKeyManager.swift`, ready for the certificate fetch and CKC exchange.

## Install

```yaml
dependencies:
  esite_flutter_player: ^0.3.0
```

| Platform | Requirement | Extra configuration |
|---|---|---|
| Android | minSdk 24, compileSdk 36 | None — the plugin declares its own permissions and Activity |
| iOS | Deployment target 13.0 | None — CocoaPods only, no Swift Package Manager support yet |
| Dart | SDK ^3.10.4, Flutter >=3.3.0 | No third-party dependencies |

## Quick start

### 1. Configure once

```dart
void main() {
  ESitePlayer.configure(
    baseUrl: 'https://api.myapp.com',        // your backend
    videoPath: '/videos/{id}/playback',      // default; override to match your routes
    tokenProvider: () async => auth.accessToken,
  );
  runApp(const MyApp());
}
```

`tokenProvider` is called per request, so a refreshed token is picked up without reconfiguring. Return `null` to send no `Authorization` header.

### 2. Play by UUID

```dart
final controller = await ESitePlayerController.forVideo(
  '4c2f5fdd-d88e-4d2b-b03d-039edef920a7',
  options: const ESitePlaybackOptions(
    autoPlay: true,
    preventScreenRecording: true,
    primaryColor: Color(0xFF6C63FF),
    secondaryColor: Colors.white,
  ),
);

controller.stateStream.listen((state) {
  if (state == ESitePlayerState.completed) {
    // Watched to the end.
  } else if (state == ESitePlayerState.closed) {
    // Dismissed early.
  }
});

controller.errorStream.listen((e) => report(e.message));

await controller.launchPlayer();
```

Call `controller.dispose()` when you are finished. A controller is bound to one video — play another by creating a new one.

### 3. Handle resolution failures

```dart
try {
  final controller = await ESitePlayerController.forVideo(videoId);
  await controller.launchPlayer();
} on ESitePlayerException catch (e) {
  switch (e.code) {
    case ESitePlayerErrorCode.unauthorized:
      await auth.refresh();
    case ESitePlayerErrorCode.videoNotReady:
      showMessage('Still processing — try again shortly.');
    case ESitePlayerErrorCode.unsupportedOnPlatform:
      showMessage('This video cannot be played on iOS yet.');
    default:
      showMessage(e.message);
  }
}
```

## What your backend must return

By default the plugin expects the eSITE `videoDetail` shape, so a backend that **proxies the eSITE response straight through needs no mapping code**:

```json
{
  "id": "4c2f5fdd-d88e-4d2b-b03d-039edef920a7",
  "name": "Sample",
  "status": "ready",
  "drm_type": "lite",
  "playback_url": "https://…/master.m3u8?token=…",
  "renditions": []
}
```

For **full DRM**, eSITE never returns license material ("DRM key material is never returned"), so your backend must enrich the response:

```json
{
  "drm_type": "full",
  "playback_url": "https://…/manifest.mpd?token=…",
  "license_server_url": "https://…/widevine",
  "entitlement_message": "…",
  "license_header_name": "X-Entitlement-Message"
}
```

`license_header_name` is optional and defaults to `X-Entitlement-Message`. A nested form is accepted too:

```json
{ "drm": { "license_url": "…", "headers": { "Authorization": "Bearer …" } } }
```

> **Playback URLs expire.** The service issues 6-hour tokens on the HLS playback endpoint and 15-minute presigned URLs for renditions. Resolve immediately before playing; never cache or persist a resolved source — while valid it is a bearer credential for the content.

### A different response shape

```dart
ESitePlayer.configure(
  baseUrl: 'https://api.myapp.com',
  tokenProvider: () async => auth.accessToken,
  mapper: (json) => ESiteResolvedSource(
    url: json['stream_url'] as String,
    streamFormat: ESiteStreamFormat.hls,
    drmType: ESiteDrmType.lite,
    title: json['title'] as String?,
  ),
);
```

Throwing inside the mapper surfaces as `configurationError`.

## API reference

### `ESitePlayer.configure`

| Parameter | Default | Purpose |
|---|---|---|
| `baseUrl` | — | Your app's backend. **Not** the eSITE service |
| `videoPath` | `/videos/{id}/playback` | Path template; must contain `{id}` |
| `tokenProvider` | `null` | Async, called per request |
| `mapper` | `null` | Converts a non-`videoDetail` response |
| `headers` | `{}` | Extra headers on every lookup |
| `timeout` | 20 s | Connect and read timeout |

Throws `ArgumentError` for an empty `baseUrl` or a `videoPath` without `{id}`. `isConfigured`, `configuration` and `reset()` round out the type.

### `ESitePlayerController`

```dart
static Future<ESitePlayerController> forVideo(String videoId, {ESitePlaybackOptions options})
ESitePlayerController(ESitePlayerConfig config)   // for callers holding a manifest URL
```

Streams — all broadcast: `stateStream`, `drmStream`, `errorStream`. `currentState` holds the latest state; `config` holds the resolved configuration.

### `ESitePlaybackOptions`

| Field | Default | Notes |
|---|---|---|
| `autoPlay` | `false` | |
| `preventScreenshots` | `false` | Android only — iOS cannot block screenshots |
| `preventScreenRecording` | `false` | `FLAG_SECURE` on Android; capture detection on iOS |
| `primaryColor` | `null` | Progress bar, scrubber, buffering indicator |
| `secondaryColor` | `null` | Transport and menu buttons |

### `ESitePlayerConfig`

| Field | Notes |
|---|---|
| `sourceUrl` | Manifest URL |
| `drm` | `ESiteDrmConfig?` — **null** for unprotected and Lite DRM |
| `streamFormat` | `hls`, `dash` or `auto` |
| `headers` | Applied to manifest, segment and key requests |
| `title` | Shown in the player's top bar |

`ESitePlayerConfig.fromResolved(source, options)` combines a resolved source with presentation options.

### `ESiteDrmConfig`

| Field | Notes |
|---|---|
| `licenseUrl` | License request / CKC endpoint |
| `scheme` | `widevine` or `fairplay` |
| `licenseHeaders` | Typically the entitlement token |
| `certificateUrl` | FairPlay application certificate; ignored for Widevine |

### Resolution types

- **`ESiteDrmType`** — `none`, `lite`, `full`. `parseDrmType()` is case-insensitive and falls back to `none`, since the service's spec types `drm_type` as a bare string with no enum.
- **`ESiteResolvedSource`** — `url`, `streamFormat`, `drmType`, `drm?`, `headers?`, `title?`.
- **`ESiteVideoDetail`** — mirrors `manager.videoDetail`, plus `raw` for backend-specific fields. `isReady` treats a null status as ready; `bestRendition` picks the highest-resolution rendition with a packaged URL.
- **`ESitePlaybackResolver`** — pure and platform-agnostic, so it is fully unit-testable.

### `ESitePlayerState`

`idle`, `initializing`, `buffering`, `ready`, `playing`, `paused`, `completed`, `error`, `closed`.

`completed` means the media ended; `closed` means the player was dismissed. Earlier versions conflated the two.

### `ESiteDrmEvent`

`licenseRequested`, `licenseAcquired` or `licenseFailed`, with an optional message. Only emitted for full DRM — Lite DRM opens no session, so silence here is expected and correct.

> State, DRM and error values cross the platform channel as **enum ordinals** shared with the native players. Append new values only — reordering silently breaks the native contract.

## Playback control

The native players already provide full on-screen controls — play/pause, ±10s double-tap seek with a ripple animation, scrubber, and speed, quality and audio-track menus — so most apps never call these.

| Method | Notes |
|---|---|
| `play()`, `pause()` | |
| `seekTo(Duration)` | Rejects negatives |
| `seekForward(Duration)`, `seekBackward(Duration)` | Rejects negatives |
| `setPlaybackSpeed(double)` | Clamped to 0.5–4.0 |
| `setVolume(double)` | Clamped to 0.0–1.0 |
| `setMuted(bool)`, `isMuted()`, `getVolume()` | |
| `getAvailableVideoTracks()` | `{id, label, width, height, bitrate, frameRate}`. iOS needs 15.0+; older versions return an empty list |
| `setVideoTrack(String)` | `"auto"` restores adaptive selection. On iOS this caps the peak bitrate — AVPlayer has no direct variant override |
| `setSubtitleEnabled(bool)`, `isSubtitleEnabled()` | |
| `hasNext()`, `next()`, `hasPrevious()`, `previous()` | Single-item playback — no-ops today |
| `dispose()` | Idempotent |

With no player on screen these fail with a `NO_PLAYER` `PlatformException`; after `dispose()` they throw `StateError`.

## Errors

| Code | Raised when | Typical response |
|---|---|---|
| `unauthorized` | Backend returned 401/403 | Refresh the app token and retry |
| `videoNotFound` | Backend returned 404 | Surface "not available" |
| `videoNotReady` | Status is not `ready` | Ask the user to retry shortly |
| `invalidSource` | Ready, but nothing presigned yet | Retry; escalate if persistent |
| `unsupportedOnPlatform` | Full DRM on iOS | Hide the video or offer another rendition |
| `configurationError` | `configure()` not called, or unreadable response | Fix the integration |
| `networkError` | Backend unreachable or timed out | Retry with backoff |
| `drmFailure` | License acquisition/provisioning/policy failure | Check entitlement and license server |
| `playbackError` | Decoder or decoding failure | Try a lower quality |

Resolution errors include the backend's RFC-7807 `detail` when present. Make sure your backend does not leak internal details into that field — it reaches the client.

## Security

| Capability | Android | iOS |
|---|---|---|
| Block screenshots | ✅ `FLAG_SECURE` | ❌ **Not possible** |
| Block screen recording | ✅ `FLAG_SECURE` | ⚠️ Video hidden and paused while captured |
| Block mirroring / AirPlay capture | ✅ `FLAG_SECURE` | ⚠️ Same mechanism |

Android's `FLAG_SECURE` is enforced by the window compositor and genuinely prevents capture. iOS offers no equivalent: the plugin observes `UIScreen.isCaptured` and hides the video layer and pauses playback while capture is active. Screenshots can only be detected *after* they are taken, never prevented.

**Do not present iOS screenshot protection as equivalent to Android's.** If your content genuinely requires it, iOS cannot deliver it at any layer, and no plugin can change that.

**What Lite DRM protects.** Content in transit and at rest in storage. It is not a DRM system: the key reaches the player in the clear over TLS, with no device binding, no output protection and no revocation. Use it where the threat model is casual copying, not determined extraction.

See [`doc/security.md`](doc/security.md) for the full treatment.

## Testing

```bash
flutter analyze                  # plugin + example
flutter test                     # resolver, HTTP client, configuration
cd example && flutter test       # example UI smoke tests

cd example && flutter build apk --debug              # compiles the Kotlin
cd example && flutter build ios --simulator --debug  # compiles the Swift
```

There is **no gradle wrapper** in `android/` — build the Android side through Flutter, not `./gradlew`.

The example app ships a **stub backend** (`example/lib/stub_backend.dart`) so it runs with no credentials and no server of your own, covering lite, plain, full-DRM, not-ready, no-playback-URL, not-found and unauthorized paths. Toggle it off to point at a real backend.

To exercise genuine Lite DRM decryption, replace `_placeholderHls` in `example/lib/main.dart` with a real `playback_url` — the stub cannot mint one, since presigning happens server-side behind the tenant API key.

See [`TEST_PLAN.md`](TEST_PLAN.md) for the manual test matrix.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `configurationError` on first play | `ESitePlayer.configure()` never ran | Call it before `runApp()` |
| Playback works, then fails hours later | The 6-hour playback token expired | Resolve immediately before playing; do not cache |
| `NO_PLAYER` PlatformException | Transport method called with no player on screen | Call `launchPlayer()` first, or guard on `currentState` |
| No DRM events for an encrypted video | It is Lite DRM | Correct behaviour — AES-128 opens no DRM session |
| `unsupportedOnPlatform` on iOS only | Full DRM is DASH + Widevine | Awaiting FairPlay packaging from the backend |

## Platform notes

Playback runs in a dedicated native screen — an Android `Activity`, an iOS `UIViewController` — not a Flutter `PlatformView`. Widevine L1 needs a `SurfaceView` on the native window, and texture-based compositing breaks the secure video path (black screen on physical devices). `ESitePlayerView` is a launcher widget, not a video surface.

Android and iOS implement identical channel names, method names and wire codes, so one Dart method-channel implementation drives both.

## Known limitations

- **Full DRM does not play on iOS.** Pending FairPlay HLS packaging from the video service.
- **iOS cannot block screenshots.** No API exists at any layer.
- **No live API response has been observed.** Every eSITE endpoint returns 401 without the tenant key, so the `drm_type` string values are inferred from the OpenAPI description text. Parsing is deliberately tolerant.
- **The full-DRM license descriptor is not yet fixed.** The resolver accepts both flat and nested shapes; the backend team needs to settle on one.
- **The spec contradicts itself on `playback_url` for full-DRM videos** — the endpoint description calls it a presigned DASH entry point, the field doc says it is null and to use rendition URLs. The resolver accepts either.
- **No Swift Package Manager support yet.** CocoaPods only.
- **Playlists are single-item.** `next()` / `previous()` are no-ops.

## Documentation

- [Full HTML documentation](doc/index.html)
- [Getting started](doc/getting_started.md)
- [API reference](doc/api_reference.md)
- [Security](doc/security.md)
- [Changelog](CHANGELOG.md)

## License

See [LICENSE](LICENSE).
