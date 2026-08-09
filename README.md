# esite_flutter_player

Secure video playback for Flutter, backed by the **eSITE Video Service**.

Give the plugin a video UUID. It asks your backend what that video is, works out whether it is unprotected, **Lite DRM** or **Full DRM**, and plays it in a native fullscreen player on Android and iOS.

```dart
ESitePlayer.configure(
  baseUrl: 'https://api.myapp.com',
  tokenProvider: () async => auth.accessToken,
);

final controller = await ESitePlayerController.forVideo(videoId);
await controller.launchPlayer();
```

No manifest URLs, no license servers, no DRM branching in your app.

---

## How it fits together

```
Flutter app ──access token──▶ your backend ──X-API-Key──▶ eSITE Video Service
  (plugin)                    (server-to-server)
```

The plugin **never talks to the eSITE service directly**. Your backend holds the tenant API key and calls `GET /api/v1/videos/{id}` on eSITE; the plugin authenticates to *your* backend with a token your app already has. The API key never ships inside the app, where it would be extractable and would grant write access to your tenant.

## Protection modes

| `drm_type` | Delivery | What the player does | Android | iOS |
|---|---|---|---|---|
| *(none)* | HLS | Plays directly | ✅ | ✅ |
| `lite` | HLS with AES-128 encrypted segments | Player fetches the key from the playlist's key route itself — no DRM session | ✅ | ✅ |
| `full` | DASH + license server | Opens a Widevine session | ✅ | ❌ *(see below)* |

**Lite DRM is standard HLS AES-128 encryption.** Both ExoPlayer and AVPlayer handle it natively, which is why it needs no DRM configuration, no license server, and no extra headers — the playback URL is token-authenticated in the URL itself.

### Full DRM on iOS

Full-DRM content is packaged as DASH + Widevine. AVPlayer plays neither. Supporting it on iOS requires the video service to *also* package CBCS fMP4 HLS and expose a FairPlay SPC/CKC endpoint plus an application certificate — **that backend work is pending**.

Until then, `forVideo()` throws `ESitePlayerErrorCode.unsupportedOnPlatform` for full-DRM videos on iOS rather than showing a black screen. The FairPlay wiring is stubbed in `ios/Classes/ESiteContentKeyManager.swift`, ready for the certificate fetch and CKC exchange when the backend ships.

---

## Install

```yaml
dependencies:
  esite_flutter_player: ^0.3.0
```

**Android:** minSdk 24. Nothing else to configure.
**iOS:** deployment target 13.0.

## Usage

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

`tokenProvider` is called per request, so a refreshed token is picked up without reconfiguring.

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

controller.stateStream.listen((state) => print('State: ${state.name}'));
controller.errorStream.listen((error) => print('Error: ${error.message}'));

await controller.launchPlayer();
```

Call `controller.dispose()` when you are finished with it.

### 3. Handle failures

`forVideo()` throws `ESitePlayerException` when resolution fails:

| Code | Meaning |
|---|---|
| `unauthorized` | Your backend rejected the token (401/403) |
| `videoNotFound` | No video with that UUID (404) |
| `videoNotReady` | Still transcoding or packaging |
| `invalidSource` | Ready, but nothing playable has been presigned yet |
| `unsupportedOnPlatform` | Full DRM on iOS |
| `configurationError` | `configure()` not called, or an unreadable response |
| `networkError` | Backend unreachable or timed out |

```dart
try {
  final controller = await ESitePlayerController.forVideo(videoId);
  await controller.launchPlayer();
} on ESitePlayerException catch (e) {
  showSnackBar('${e.code.name}: ${e.message}');
}
```

## What your backend must return

By default the plugin expects the eSITE `videoDetail` shape, so a backend that **proxies the eSITE response straight through needs no mapping code**:

```json
{
  "id": "4c2f5fdd-d88e-4d2b-b03d-039edef920a7",
  "status": "ready",
  "drm_type": "lite",
  "playback_url": "https://…/master.m3u8?token=…",
  "renditions": []
}
```

For **full DRM**, eSITE never returns license material, so your backend must enrich the response:

```json
{
  "drm_type": "full",
  "playback_url": "https://…/manifest.mpd?token=…",
  "license_server_url": "https://…/widevine",
  "entitlement_message": "…",
  "license_header_name": "X-Entitlement-Message"
}
```

A nested `"drm": { "license_url": …, "headers": {…} }` object is accepted too.

### A different response shape

Supply a mapper:

```dart
ESitePlayer.configure(
  baseUrl: 'https://api.myapp.com',
  tokenProvider: () async => auth.accessToken,
  mapper: (json) => ESiteResolvedSource(
    url: json['stream_url'] as String,
    streamFormat: ESiteStreamFormat.hls,
    drmType: ESiteDrmType.lite,
  ),
);
```

## Playback control

While the player is on screen: `play()`, `pause()`, `seekTo()`, `seekForward()`, `seekBackward()`, `setPlaybackSpeed()`, `setVolume()`, `setMuted()`, `getAvailableVideoTracks()`, `setVideoTrack()`, `setSubtitleEnabled()`. With no player on screen these fail with a `NO_PLAYER` `PlatformException`.

The native players already provide full on-screen controls — play/pause, ±10s double-tap seek with animation, scrubber, speed, quality and audio-track menus — so most apps never call these.

## Security

`ESitePlaybackOptions.preventScreenshots` / `preventScreenRecording`:

- **Android** sets `FLAG_SECURE`, which genuinely blocks both screenshots and screen recording.
- **iOS has no equivalent.** There is no API to block screenshots — they can only be detected after the fact. What the plugin *does* enforce is capture: while the screen is being recorded or mirrored (`UIScreen.isCaptured`), the video is hidden and playback pauses. Treat iOS screenshot prevention as unavailable, not merely weaker.

Playback URLs are short-lived (the service issues 6-hour tokens for lite/plain, 15-minute presigned URLs for renditions). Resolve immediately before playing rather than caching.

## Testing

```bash
flutter analyze
flutter test                     # resolver, API client and configuration
cd example && flutter test       # example UI smoke tests
```

The example app ships a **built-in stub backend** (`example/lib/stub_backend.dart`) so it runs with no credentials and no server of your own. It covers lite, plain, full-DRM, not-ready, not-found and unauthorized paths. Toggle it off to point at a real backend.

To exercise genuine Lite DRM playback, replace `_placeholderHls` in `example/lib/main.dart` with a real `playback_url` from `GET /api/v1/videos/{id}` — the stub cannot mint one, since presigning happens server-side behind the tenant API key.

## Platform notes

Playback runs in a dedicated native screen — an Android `Activity`, an iOS `UIViewController` — not a Flutter `PlatformView`. Widevine L1 needs a `SurfaceView` on the native window, and texture-based compositing breaks the secure video path (black screen on physical devices). `ESitePlayerView` is a launcher widget, not a video surface.

## Documentation

- [Getting started](doc/getting_started.md)
- [API reference](doc/api_reference.md)
- [Security](doc/security.md)

## License

See [LICENSE](LICENSE).
