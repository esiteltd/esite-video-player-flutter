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

### Documentation

See [README.md](README.md) for installation and usage instructions.


ESITE PLAYER PDF CONTENT::

eSITE Flutter Player — DRM Video Playback Library
Project Requirements & Technical Specification
1. Project Overview
   We require a Flutter plugin/package named eSITE Flutter Player, developed as a public player to be
   published on the Flutter packages repositories.
   The package will provide secure DRM-enabled video playback for Flutter applications by wrapping a
   native Android ExoPlayer 3 (Media3) implementation with Axinom DRM compatibility.
   The initial release will support Android only, with an architecture explicitly designed to support iOS
   in future phases.
   This library will become a core component of eSITE Video Service, and all naming (package, classes,
   documentation) must reflect this branding.
2. Branding & Naming Requirements (Mandatory)
   2.1. Package Name
   pub.dev package name: esite_flutter_player
   2.2. Dart Library Namespace
   import 'package:esite_flutter_player/esite_flutter_player.dart';
   2.3. Core Classes (Mandatory Names)
   Errors ESitePlayerError
   Purpose Class Name
   Main controller ESitePlayerController
   Player widget ESitePlayerView
   Configuration model ESitePlayerConfig
   DRM configuration ESiteDrmConfig
   Playback state ESitePlayerState
   DRM events ESiteDrmEvent
   No generic names (e.g., VideoPlayerController) are allowed.
3. Functional Scope
   3.1. Core Features
   The freelancer shall implement:
1. Flutter plugin with Android native layer
   o Flutter ↔ Android communication via Platform Channels or Pigeon
   o Android native code in Kotlin
   o ExoPlayer Media3 APIs only
2. DRM Playback Support
   o Compatible with Axinom DRM
   o License acquisition
   o Key exchange
   o Secure playback session lifecycle
3. Flutter Video Rendering
   o Embedded Flutter widget using PlatformView
   o Supports resizing, orientation changes, fullscreen
4. Secure Playback Controls
   o Play
   o Pause
   o Seek (to specific time or fast forward, fast rewind)
   o Stop
   o Dispose
   o Change video quality
   o Change playback speed (0.5x, 1x, 1.5x, 2x, 4x)
   o Enable/Disable subtitles
   o Mute/Increase/Decrease sound volume
   o Next/Previous video (Playlist support)
5. Playback & DRM Events
   o Bu^ering
   o Ready
   o Playing
   o Paused
   o Completed
   o Error states (e.g. Failed to load video, Invalid URL, Invalid encryption, etc…)
   o DRM-specific failures
4. DRM & Security Protection Requirements (Critical)
   4.1. Screenshot & Screen Recording Protection (Android)
   The player MUST support content protection flags to prevent leakage.
   Mandatory Android Protections
   • Apply FLAG_SECURE on the hosting Activity / Player View
   • Block:
   o Screenshots
   o Screen recording
   o Recent apps preview capture
   Flutter Configuration Example
   ESitePlayerConfig(
   preventScreenshots: true,
   preventScreenRecording: true,
   );
   Native Android Implementation
   • Use:
   window.setFlags(
   WindowManager.LayoutParams.FLAG_SECURE,
   WindowManager.LayoutParams.FLAG_SECURE
   )
   • Must be enabled only when playback is active
   • Must be removed when the player is disposed
   4.2. DRM Leakage Mitigation
   The implementation must:
   • Use secure decoder paths where available
   • Avoid exposing:
   o Raw video URLs
   o DRM keys
   o License payloads to Flutter logs
   • Ensure:
   o No license caching beyond allowed lifecycle
   o No plaintext media access
5. API Design (Flutter)
   5.1. Configuration Objects
   class ESitePlayerConfig {
   final String sourceUrl;
   final ESiteDrmConfig drm;
   final Map<String, String>? headers;
   final bool autoPlay;
   final bool preventScreenshots;
   final bool preventScreenRecording;
   }
   class ESiteDrmConfig {
   final String licenseUrl;
   final ESiteDrmScheme scheme;
   final Map<String, String>? licenseHeaders;
   }
   enum ESiteDrmScheme {
   widevine,
   playready,
   fairplay, // future
   }
   5.2. Controller API
   final controller = ESitePlayerController(
   ESitePlayerConfig(
   sourceUrl: 'https://example.com/stream.mpd',
   drm: ESiteDrmConfig(
   licenseUrl: 'https://license.esite.com',
   scheme: ESiteDrmScheme.widevine,
   ),
   preventScreenshots: true,
   preventScreenRecording: true,
   ),
   );
   await controller.initialize();
   await controller.play();
   5.3. Widget Usage
   ESitePlayerView(
   controller: controller,
   )
6. Reference Implementations
   The freelancer is expected to study and port logic from:
   Axinom Android Libraries
   • https://github.com/Axinom/drm-sample-player-android-media3
   • https://github.com/Axinom/drm-sample-player-android
   Flutter Plugin Reference UX
   • https://www.vdocipher.com/docs/mobile/flutter/getting-started/
   (Design inspiration only, no code reuse.)
7. Documentation Requirements
   Required Documentation
1. README.md
   o Installation
   o Android permissions
   o Basic usage
2. Getting Started Guide
   o DRM setup
   o License server configuration
   o Security flags explanation
3. API Reference
   o All public classes
   o Event streams
   o Error codes
4. Security Notes
   o Screenshot blocking behavior
   o DRM limitations
   o Emulator restrictions
8. Example Application
   The package must include /example Flutter app demonstrating:
   • DRM playback with Axinom-compatible stream
   • Screenshot blocking enabled
   • Playback state logging
   • Error handling UI
9. Pub.dev Publishing Requirements
   • Proper pubspec.yaml
   • Semantic versioning
   • Example app included
   • Analyzer & lints passing
   • Platform support clearly stated (Android only)
10. Architecture for Future iOS Support
    The design must:
    • Abstract platform logic cleanly
    • Avoid Android-only Dart APIs
    • Prepare for:
    o AVPlayer DRM (FairPlay)
    o iOS screen capture protection APIs
    o Unified Flutter API surface
11. Deliverables
    Item Description
    Flutter Plugin esite_flutter_player
    Android Native Code Kotlin + Media3
    Item Description
    Example App DRM playback demo
    Documentation Full developer docs
    Source Repository Git-based
    Pub.dev Ready Publishable package
12. Acceptance Criteria
    • DRM playback works with Axinom license server
    • Screenshot & screen recording blocked during playback
    • Clean, stable Flutter API
    • Proper error propagation
    • Code ready for extension to iOS
13. Out of Scope (Explicit)
    • iOS implementation
    • Casting (Chromecast)
    • O^line DRM
    • Web support