# API Reference - eSite Flutter Player

Complete API documentation for the eSite Flutter Player package.

## Table of Contents

- [ESitePlayerController](#esiteplayercontroller)
- [ESitePlayerView](#esiteplayerview)
- [ESitePlayerConfig](#esiteplayerconfig)
- [ESiteDrmConfig](#esitedrmconfig)
- [ESitePlayerState](#esiteplayerstate)
- [ESiteDrmEvent](#esitedrmevent)
- [ESitePlayerError](#esiteplayererror)
- [ESiteDrmScheme](#esitedrmscheme)

---

## ESitePlayerController

Main controller class for managing video playback.

### Constructor

```dart
ESitePlayerController(ESitePlayerConfig config)
```

Creates a new player controller with the specified configuration.

**Parameters:**
- `config` - Player configuration (required)

**Throws:**
- `UnsupportedError` if platform is not supported

### Properties

#### currentState

```dart
ESitePlayerState get currentState
```

Returns the current playback state.

#### stateStream

```dart
Stream<ESitePlayerState> get stateStream
```

Stream of playback state changes. Listen to this to monitor player state.

**Example:**
```dart
controller.stateStream.listen((state) {
  print('State changed to: $state');
});
```

#### drmStream

```dart
Stream<ESiteDrmEvent> get drmStream
```

Stream of DRM events. Listen to this to monitor license acquisition.

**Example:**
```dart
controller.drmStream.listen((event) {
  print('DRM event: ${event.type}');
});
```

#### errorStream

```dart
Stream<ESitePlayerError> get errorStream
```

Stream of player errors. Listen to this to handle errors.

**Example:**
```dart
controller.errorStream.listen((error) {
  print('Error: ${error.code} - ${error.message}');
});
```

### Methods

#### initialize

```dart
Future<void> initialize()
```

Initializes the player with the provided configuration. Must be called before any playback methods.

**Example:**
```dart
await controller.initialize();
```

#### play

```dart
Future<void> play()
```

Starts or resumes playback.

**Example:**
```dart
await controller.play();
```

#### pause

```dart
Future<void> pause()
```

Pauses playback.

**Example:**
```dart
await controller.pause();
```

#### seekTo

```dart
Future<void> seekTo(Duration position)
```

Seeks to a specific position in the video.

**Parameters:**
- `position` - Target position

**Example:**
```dart
await controller.seekTo(Duration(seconds: 30));
```

#### seekForward

```dart
Future<void> seekForward(Duration offset)
```

Seeks forward by the specified offset.

**Parameters:**
- `offset` - Duration to seek forward

**Example:**
```dart
await controller.seekForward(Duration(seconds: 10));
```

#### seekBackward

```dart
Future<void> seekBackward(Duration offset)
```

Seeks backward by the specified offset.

**Parameters:**
- `offset` - Duration to seek backward

**Example:**
```dart
await controller.seekBackward(Duration(seconds: 10));
```

#### setPlaybackSpeed

```dart
Future<void> setPlaybackSpeed(double speed)
```

Sets the playback speed. Value is automatically clamped to 0.5-4.0 range.

**Parameters:**
- `speed` - Playback speed multiplier (0.5 to 4.0)

**Example:**
```dart
await controller.setPlaybackSpeed(1.5); // 1.5x speed
```

#### setVolume

```dart
Future<void> setVolume(double volume)
```

Sets the playback volume. Value is automatically clamped to 0.0-1.0 range.

**Parameters:**
- `volume` - Volume level (0.0 to 1.0)

**Example:**
```dart
await controller.setVolume(0.8);
```

#### setMuted

```dart
Future<void> setMuted(bool muted)
```

Mutes or unmutes the audio.

**Parameters:**
- `muted` - True to mute, false to unmute

**Example:**
```dart
await controller.setMuted(true);
```

#### isMuted

```dart
Future<bool> isMuted()
```

Returns whether the audio is currently muted.

**Returns:** `true` if muted, `false` otherwise

**Example:**
```dart
final muted = await controller.isMuted();
```

#### getVolume

```dart
Future<double> getVolume()
```

Returns the current volume level.

**Returns:** Volume level (0.0 to 1.0)

**Example:**
```dart
final volume = await controller.getVolume();
```

#### getAvailableVideoTracks

```dart
Future<List<Map<String, dynamic>>> getAvailableVideoTracks()
```

Returns available video quality tracks.

**Returns:** List of track information maps containing:
- `id` - Track identifier
- `width` - Video width
- `height` - Video height
- `bitrate` - Bitrate in bits per second
- `label` - Human-readable label

**Example:**
```dart
final tracks = await controller.getAvailableVideoTracks();
for (var track in tracks) {
  print('${track['label']}: ${track['width']}x${track['height']}');
}
```

#### setVideoTrack

```dart
Future<void> setVideoTrack(String trackId)
```

Selects a specific video quality track.

**Parameters:**
- `trackId` - Track identifier from `getAvailableVideoTracks()`

**Example:**
```dart
final tracks = await controller.getAvailableVideoTracks();
await controller.setVideoTrack(tracks[0]['id']);
```

#### setSubtitleEnabled

```dart
Future<void> setSubtitleEnabled(bool enabled)
```

Enables or disables subtitles.

**Parameters:**
- `enabled` - True to enable, false to disable

**Example:**
```dart
await controller.setSubtitleEnabled(true);
```

#### isSubtitleEnabled

```dart
Future<bool> isSubtitleEnabled()
```

Returns whether subtitles are currently enabled.

**Returns:** `true` if enabled, `false` otherwise

**Example:**
```dart
final enabled = await controller.isSubtitleEnabled();
```

#### hasNext

```dart
Future<bool> hasNext()
```

Returns whether there is a next media item in the playlist.

**Returns:** `true` if next item exists, `false` otherwise

**Example:**
```dart
if (await controller.hasNext()) {
  await controller.next();
}
```

#### hasPrevious

```dart
Future<bool> hasPrevious()
```

Returns whether there is a previous media item in the playlist.

**Returns:** `true` if previous item exists, `false` otherwise

**Example:**
```dart
if (await controller.hasPrevious()) {
  await controller.previous();
}
```

#### next

```dart
Future<void> next()
```

Navigates to the next media item in the playlist.

**Example:**
```dart
await controller.next();
```

#### previous

```dart
Future<void> previous()
```

Navigates to the previous media item in the playlist.

**Example:**
```dart
await controller.previous();
```

#### dispose

```dart
Future<void> dispose()
```

Disposes the player and releases all resources. Must be called when done with the controller.

**Example:**
```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

---

## ESitePlayerView

Widget that displays the video player.

### Constructor

```dart
ESitePlayerView({
  Key? key,
  required ESitePlayerController controller,
})
```

**Parameters:**
- `controller` - The player controller (required)

**Example:**
```dart
ESitePlayerView(controller: controller)
```

**Platform Support:**
- Android: Full support
- iOS: Not yet supported (displays error message)

---

## ESitePlayerConfig

Configuration for the player.

### Constructor

```dart
ESitePlayerConfig({
  required String sourceUrl,
  required ESiteDrmConfig drm,
  Map<String, String>? headers,
  bool autoPlay = false,
  bool preventScreenshots = false,
  bool preventScreenRecording = false,
})
```

### Properties

- `sourceUrl` (String, required) - URL of the media source (DASH manifest)
- `drm` (ESiteDrmConfig, required) - DRM configuration
- `headers` (Map<String, String>?, optional) - Custom HTTP headers for media requests
- `autoPlay` (bool, default: false) - Whether to start playback automatically
- `preventScreenshots` (bool, default: false) - Enable screenshot protection
- `preventScreenRecording` (bool, default: false) - Enable screen recording protection

**Example:**
```dart
ESitePlayerConfig(
  sourceUrl: 'https://example.com/video.mpd',
  drm: ESiteDrmConfig(
    licenseUrl: 'https://license.example.com',
    scheme: ESiteDrmScheme.widevine,
  ),
  headers: {'Authorization': 'Bearer token'},
  autoPlay: true,
  preventScreenshots: true,
  preventScreenRecording: true,
)
```

---

## ESiteDrmConfig

DRM configuration for secure playback.

### Constructor

```dart
ESiteDrmConfig({
  required String licenseUrl,
  required ESiteDrmScheme scheme,
  Map<String, String>? licenseHeaders,
})
```

### Properties

- `licenseUrl` (String, required) - URL of the DRM license server
- `scheme` (ESiteDrmScheme, required) - DRM scheme to use
- `licenseHeaders` (Map<String, String>?, optional) - Custom headers for license requests

**Example:**
```dart
ESiteDrmConfig(
  licenseUrl: 'https://drm-widevine-licensing.axtest.net/AcquireLicense',
  scheme: ESiteDrmScheme.widevine,
  licenseHeaders: {
    'X-AxDRM-Message': 'jwt-token-here',
  },
)
```

---

## ESitePlayerState

Enumeration of player states.

### Values

- `idle` - Player is idle (initial state)
- `initializing` - Player is initializing
- `buffering` - Player is buffering content
- `ready` - Player is ready to play
- `playing` - Content is currently playing
- `paused` - Playback is paused
- `completed` - Playback has completed
- `error` - An error has occurred

**Example:**
```dart
controller.stateStream.listen((state) {
  if (state == ESitePlayerState.playing) {
    print('Video is playing');
  }
});
```

---

## ESiteDrmEvent

DRM event information.

### Constructor

```dart
ESiteDrmEvent({
  required ESiteDrmEventType type,
  String? message,
})
```

### Properties

- `type` (ESiteDrmEventType) - Type of DRM event
- `message` (String?) - Optional event message

### ESiteDrmEventType

Enumeration of DRM event types:

- `licenseRequested` - License request has been initiated
- `licenseAcquired` - License successfully acquired
- `licenseFailed` - License acquisition failed

**Example:**
```dart
controller.drmStream.listen((event) {
  switch (event.type) {
    case ESiteDrmEventType.licenseAcquired:
      print('License acquired: ${event.message}');
      break;
    case ESiteDrmEventType.licenseFailed:
      print('License failed: ${event.message}');
      break;
  }
});
```

---

## ESitePlayerError

Player error information.

### Constructor

```dart
ESitePlayerError({
  required ESitePlayerErrorCode code,
  required String message,
})
```

### Properties

- `code` (ESitePlayerErrorCode) - Error code
- `message` (String) - Error message

### ESitePlayerErrorCode

Enumeration of error codes:

- `invalidSource` - Invalid or inaccessible media source
- `drmFailure` - DRM-related failure
- `networkError` - Network connectivity error
- `playbackError` - General playback error
- `unknown` - Unknown error

**Example:**
```dart
controller.errorStream.listen((error) {
  switch (error.code) {
    case ESitePlayerErrorCode.drmFailure:
      showAlert('DRM Error: ${error.message}');
      break;
    case ESitePlayerErrorCode.networkError:
      showAlert('Network Error: ${error.message}');
      break;
  }
});
```

---

## ESiteDrmScheme

Enumeration of supported DRM schemes.

### Values

- `widevine` - Google Widevine DRM (Android)
- `playready` - Microsoft PlayReady DRM (future)
- `fairplay` - Apple FairPlay DRM (future, iOS)

**Example:**
```dart
ESiteDrmConfig(
  licenseUrl: 'https://license.server.com',
  scheme: ESiteDrmScheme.widevine,
)
```

---

## Platform Support

| Feature | Android | iOS |
|---------|---------|-----|
| Widevine DRM | ✅ | ❌ |
| PlayReady DRM | ✅ | ❌ |
| FairPlay DRM | ❌ | 🔄 Planned |
| Screenshot Protection | ✅ | 🔄 Planned |
| Basic Playback | ✅ | 🔄 Planned |

---

## Error Handling Best Practices

Always listen to the error stream and handle errors appropriately:

```dart
controller.errorStream.listen((error) {
  // Log error for debugging
  debugPrint('Player Error: ${error.code} - ${error.message}');
  
  // Show user-friendly message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Playback error occurred')),
  );
  
  // Handle specific error types
  switch (error.code) {
    case ESitePlayerErrorCode.drmFailure:
      // Retry with different license or show upgrade prompt
      break;
    case ESitePlayerErrorCode.networkError:
      // Retry or show offline message
      break;
  }
});
```

---

## Lifecycle Management

Proper lifecycle management is critical:

```dart
class PlayerPage extends StatefulWidget {
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late ESitePlayerController controller;
  
  @override
  void initState() {
    super.initState();
    controller = ESitePlayerController(config);
    controller.initialize();
  }
  
  @override
  void dispose() {
    controller.dispose(); // Always dispose!
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ESitePlayerView(controller: controller);
  }
}
```

