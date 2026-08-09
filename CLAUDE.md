# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter plugin for secure video playback backed by the **eSITE Video Service**. Callers pass a video UUID; the plugin resolves it, determines the protection mode, and plays it in a native fullscreen screen on Android (Media3 ExoPlayer) and iOS (AVPlayer).

- **Package:** `esite_flutter_player`
- **Dart SDK:** ^3.10.4, Flutter >=3.3.0
- **Android:** compileSdk 36, minSdk 24, Kotlin 2.2.20, Java 17, Media3 1.2.1
- **iOS:** deployment target 13.0, Swift 5

## Common Commands

```bash
flutter analyze                       # lint the plugin and the example
flutter test                          # plugin unit tests (resolver, API client, config)
cd example && flutter test            # example UI smoke tests
cd example && flutter build apk --debug            # compiles the Kotlin
cd example && flutter build ios --simulator --debug # compiles the Swift
cd example && flutter run             # physical device needed for full DRM
```

There is **no gradle wrapper** in `android/` or `example/android/` — build the Android side through Flutter, not `./gradlew`.

## Architecture

### Auth topology

```
Flutter app ──access token──▶ client's own backend ──X-API-Key──▶ eSITE Video Service
   (plugin)                     (server-to-server)
```

The plugin never calls the eSITE service directly. The tenant API key stays server-side; the token the plugin sends is between the app and its own backend. Do not reintroduce direct eSITE calls or embedded API keys.

### Protection modes

Driven by `drm_type` in the backend response:

- **none / lite** → HLS. `lite` is AES-128 encrypted HLS: ExoPlayer and AVPlayer fetch the key from the playlist's key route themselves, so **no DRM session, license server or headers are involved**. Supporting it required only making `drm` optional.
- **full** → DASH + Widevine on Android. **Not playable on iOS** (AVPlayer does neither DASH nor Widevine); FairPlay packaging is pending on the backend, so `forVideo()` throws `unsupportedOnPlatform`.

### Native screen, not a PlatformView

Playback runs in a dedicated Android `Activity` / iOS `UIViewController`. Widevine L1 needs a `SurfaceView` on the native window, and Flutter's texture-based compositing breaks the secure video path (black screen on physical devices). `ESitePlayerView` is a launcher widget, not a video surface.

### Layout

```
lib/src/
  api/        ESitePlayer.configure, HTTP client, videoDetail models, drm_type parsing
  resolver/   videoDetail -> ESiteResolvedSource (pure, unit-tested)
  config/     ESitePlayerConfig, ESitePlaybackOptions, ESiteDrmConfig, ESiteStreamFormat
  controller/ ESitePlayerController (+ forVideo factory)
  platform/   ESiteMethodChannelPlayer — shared by both platforms
android/src/main/kotlin/.../  EsiteFlutterPlayerPlugin, PlayerActivity, PlayerEventBridge, PlayerConfigHolder, SeekAnimationView
ios/Classes/                  EsiteFlutterPlayerPlugin, ESitePlayerViewController, PlayerEventBridge, PlayerConfigHolder, SeekAnimationView, ESiteContentKeyManager
```

Android and iOS implement **identical** channel names, method names and wire codes, so one Dart `ESiteMethodChannelPlayer` drives both.

### Wire contract

Channels: `esite_flutter_player/methods`, `.../events/state`, `.../events/drm`, `.../events/error`.

State codes: idle=0, initializing=1, buffering=2, ready=3, playing=4, paused=5, completed=6, error=7, **closed=8**.
Error codes: invalidSource=0, drmFailure=1, networkError=2, playbackError=3, unknown=4 (5–9 are Dart-side resolution errors).
DRM events: licenseRequested=0, licenseAcquired=1, licenseFailed=2.

These are **enum ordinals**. Append only — reordering silently breaks the native contract.

### Key design patterns

- **Static bridges** — `PlayerEventBridge` and `PlayerConfigHolder` are singletons on both platforms, because the presented screen and the Flutter plugin cannot share instance references. `PlayerActivity.current` / `ESitePlayerViewController.current` route transport commands to the live player.
- **Pure resolver** — `ESitePlaybackResolver` is platform-agnostic and takes the target `ESiteDrmScheme` as a parameter, so it is fully unit-testable. Platform capability checks live in the controller.
- **Tolerant parsing** — `drm_type` values are not enumerated in the service's OpenAPI spec, so parsing is case-insensitive with a fallback to `none`. The full-DRM license descriptor accepts both flat and nested shapes.

## Known gaps

- The spec contradicts itself on `playback_url` for full-DRM videos (the endpoint description calls it a presigned DASH entry point; the field doc says it is null and to use rendition URLs). The resolver accepts both.
- No live API response has ever been observed — every eSITE endpoint returns 401 without the tenant key. `drm_type` string values are inferred from spec prose.
- The plugin has no Swift Package Manager support yet (CocoaPods only); Flutter warns about this.

## Linting

`package:flutter_lints/flutter.yaml` with `avoid_print: true`. No public API doc requirement (`public_member_api_docs: false`).

## Testing Notes

The example app ships a **stub backend** (`example/lib/stub_backend.dart`) serving `videoDetail`-shaped responses, so it runs with no credentials. Full DRM needs a physical Android device. To test real Lite DRM playback, replace `_placeholderHls` in `example/lib/main.dart` with a genuine `playback_url`.
