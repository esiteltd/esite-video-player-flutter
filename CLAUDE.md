# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flutter plugin for secure DRM-protected video playback on Android. Wraps Android Media3 ExoPlayer with Widevine DRM support (Axinom integration). Android-only currently; iOS is planned.

- **Package:** `esite_flutter_player`
- **Dart SDK:** ^3.10.4, Flutter >=3.3.0
- **Android:** compileSdk 36, minSdk 24, Kotlin 2.2.20, Java 17

## Common Commands

```bash
# Analyze Dart code (linting)
flutter analyze

# Run Dart tests
flutter test

# Run example app on connected device (physical device needed for DRM)
cd example && flutter run

# Run Android native unit tests
cd android && ./gradlew test

# Get dependencies
flutter pub get
cd example && flutter pub get
```

## Architecture

### Native Activity Approach

Playback happens in a dedicated native Android `PlayerActivity` (not a Flutter PlatformView). This is required because Widevine L1 DRM needs a `SurfaceView` directly on the native window — Flutter's texture-based PlatformView compositing breaks the secure video path, causing a black screen on physical devices.

### Dart ↔ Android Communication

```
ESitePlayerController (lib/src/controller/)
    → ESitePlatformPlayer (abstract interface, lib/src/platform/)
        → ESiteAndroidPlatformPlayer (concrete, lib/src/platform/)
            → MethodChannel: esite_flutter_player/methods
            → EventChannel:  esite_flutter_player/events/state
            → EventChannel:  esite_flutter_player/events/drm
            → EventChannel:  esite_flutter_player/events/error

EsiteFlutterPlayerPlugin.kt (Android entry point)
    → PlayerConfigHolder.kt (static config transfer to Activity)
    → PlayerActivity.kt (fullscreen ExoPlayer + DRM + Media3 controls)
    → PlayerEventBridge.kt (static singleton relaying events to Flutter sinks)
```

### Key Design Patterns

- **Strategy pattern** for platform abstraction — `ESitePlatformPlayer` is the abstract interface, `ESiteAndroidPlatformPlayer` is the Android implementation.
- **Three separate EventChannels** for state, DRM, and error streams — each exposed as broadcast streams on the controller.
- **Static event bridge** — `PlayerEventBridge` singleton holds EventChannel sinks; `PlayerActivity` posts events through it on the main thread. Required because the Activity and the Flutter plugin cannot share instance references.
- **Static config holder** — `PlayerConfigHolder` transfers config in-memory (avoids Intent Bundle serialization limits for large JWT license URLs).
- **L1→L3 DRM fallback** — `PlayerActivity.buildDrmSessionManager()` attempts Widevine L1 via `FrameworkMediaDrm.setPropertyString("securityLevel", "L1")`, catches failure and falls back to L3.

### Android Native Layer

`PlayerActivity.kt` is the core — fullscreen `AppCompatActivity` that creates ExoPlayer, configures DRM sessions, attaches to a `PlayerView` (with `surface_type="surface_view"`), and manages `FLAG_SECURE`. Media3's built-in `PlayerControlView` provides all playback controls (play/pause, seek, settings).

State codes sent via `PlayerEventBridge`: idle=0, initializing=1, buffering=2, ready=3, playing=4, paused=5, completed=6, error=7.

### Configuration Flow

`ESitePlayerConfig` holds source URL, DRM config, headers, autoplay, and security flags. `ESiteDrmConfig` holds license URL, scheme enum, and license headers. These are serialized to maps, passed over the MethodChannel, stored in `PlayerConfigHolder`, and consumed by `PlayerActivity.onCreate()`.

## Linting

Uses `package:flutter_lints/flutter.yaml` with `avoid_print: true` enabled. No public API doc requirement (`public_member_api_docs: false`).

## Testing Notes

DRM playback requires a physical Android device (emulators lack Widevine L1, but L3 fallback works for basic testing). The example app (`example/lib/main.dart`) contains 7 test scenarios covering valid auth, expired tokens, invalid license URLs, missing headers, wrong DRM schemes, and network errors.
