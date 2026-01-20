# esite_flutter_player

A secure, production-ready Flutter plugin for DRM-protected video playback on Android using Media3 ExoPlayer with Widevine DRM support.

## Features

- ✅ **DRM Support**: Widevine DRM via Axinom integration
- ✅ **Security**: Automatic screenshot and screen recording blocking (FLAG_SECURE)
- ✅ **Playback Controls**: Play, pause, seek, speed control (0.5x-4x)
- ✅ **Track Selection**: Video quality selection
- ✅ **Subtitle Support**: Enable/disable subtitles
- ✅ **Volume Control**: Volume adjustment and mute
- ✅ **Playlist Support**: Next/previous media item navigation
- ✅ **Event Streams**: Real-time playback state, DRM events, and error handling
- ✅ **Production Ready**: Secure, no DRM data logging, proper lifecycle management

## Platform Support

- ✅ **Android**: Full support (Media3 ExoPlayer)
- ❌ **iOS**: Not yet implemented (planned for future release)

## Installation

Add `esite_flutter_player` to your `pubspec.yaml`:

```yaml
dependencies:
  esite_flutter_player: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Basic Setup

```dart
import 'package:esite_flutter_player/esite_flutter_player.dart';

// Create player configuration
final config = ESitePlayerConfig(
  sourceUrl: 'https://your-cdn.com/video.mpd',
  drm: ESiteDrmConfig(
    licenseUrl: 'https://license.axinom.com/widevine',
    scheme: ESiteDrmScheme.widevine,
    licenseHeaders: {
      'X-AxDRM-Message': 'your-license-header',
    },
  ),
  autoPlay: false,
);

// Create controller
final controller = ESitePlayerController(config);

// Initialize player
await controller.initialize();
```

### 2. Display Video Player

```dart
ESitePlayerView(controller: controller)
```

### 3. Control Playback

```dart
// Play
await controller.play();

// Pause
await controller.pause();

// Seek to position
await controller.seekTo(Duration(seconds: 30));

// Seek forward/backward
await controller.seekForward(Duration(seconds: 10));
await controller.seekBackward(Duration(seconds: 10));

// Set playback speed (0.5x to 4x)
await controller.setPlaybackSpeed(1.5);

// Volume control
await controller.setVolume(0.8);
await controller.setMuted(true);

// Track selection
final tracks = await controller.getAvailableVideoTracks();
await controller.setVideoTrack(tracks[0]['id']);

// Subtitle control
await controller.setSubtitleEnabled(true);

// Playlist navigation
if (await controller.hasNext()) {
  await controller.next();
}
```

### 4. Listen to Events

```dart
// Playback state
controller.stateStream.listen((state) {
  print('Player state: $state');
  // States: idle, initializing, buffering, ready, playing, paused, completed, error
});

// DRM events
controller.drmStream.listen((event) {
  print('DRM event: ${event.type}');
  // Types: licenseRequested, licenseAcquired, licenseFailed
});

// Errors
controller.errorStream.listen((error) {
  print('Error: ${error.code} - ${error.message}');
});
```

### 5. Cleanup

```dart
@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```

## Complete Example

See the [example app](example/lib/main.dart) for a full implementation with:
- Embedded player view
- Playback controls UI
- State monitoring
- Error handling
- Track selection
- Volume control

## Documentation

- 📘 [Getting Started Guide](doc/getting_started.md) - Step-by-step setup and usage
- 📗 [API Reference](doc/api_reference.md) - Complete API documentation
- 🔒 [Security Notes](doc/security.md) - Security best practices and DRM details

## Security Features

### Screenshot & Screen Recording Protection

The plugin automatically enables `FLAG_SECURE` when playback starts, preventing:
- Screenshots
- Screen recording
- Recent apps preview capture

Security is automatically:
- **Enabled** when playback starts
- **Disabled** when playback pauses or ends
- **Disabled** when the player is disposed

This ensures security is only active during actual playback, not affecting the rest of your app.

## DRM Configuration

### Axinom Widevine Setup

```dart
ESiteDrmConfig(
  licenseUrl: 'https://license.axinom.com/widevine',
  scheme: ESiteDrmScheme.widevine,
  licenseHeaders: {
    'X-AxDRM-Message': 'your-license-header',
    'Authorization': 'Bearer your-token',
  },
)
```

### Supported DRM Schemes

- `ESiteDrmScheme.widevine` - Widevine DRM (Axinom)

## API Reference

### ESitePlayerController

Main controller for video playback.

#### Methods

- `Future<void> initialize()` - Initialize the player with configuration
- `Future<void> play()` - Start playback
- `Future<void> pause()` - Pause playback
- `Future<void> seekTo(Duration position)` - Seek to specific position
- `Future<void> seekForward(Duration offset)` - Seek forward by offset
- `Future<void> seekBackward(Duration offset)` - Seek backward by offset
- `Future<void> setPlaybackSpeed(double speed)` - Set speed (0.5-4.0)
- `Future<void> setVolume(double volume)` - Set volume (0.0-1.0)
- `Future<void> setMuted(bool muted)` - Mute/unmute
- `Future<bool> isMuted()` - Check if muted
- `Future<double> getVolume()` - Get current volume
- `Future<List<Map<String, dynamic>>> getAvailableVideoTracks()` - Get video tracks
- `Future<void> setVideoTrack(String trackId)` - Select video track
- `Future<void> setSubtitleEnabled(bool enabled)` - Enable/disable subtitles
- `Future<bool> isSubtitleEnabled()` - Check subtitle status
- `Future<bool> hasNext()` - Check if next item available
- `Future<bool> hasPrevious()` - Check if previous item available
- `Future<void> next()` - Go to next media item
- `Future<void> previous()` - Go to previous media item
- `Future<void> dispose()` - Dispose player and cleanup

#### Properties

- `ESitePlayerState currentState` - Current playback state
- `Stream<ESitePlayerState> stateStream` - Playback state stream
- `Stream<ESiteDrmEvent> drmStream` - DRM events stream
- `Stream<ESitePlayerError> errorStream` - Error stream

### ESitePlayerConfig

Player configuration.

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

### ESiteDrmConfig

DRM configuration.

```dart
ESiteDrmConfig({
  required String licenseUrl,
  required ESiteDrmScheme scheme,
  Map<String, String>? licenseHeaders,
})
```

### ESitePlayerState

Playback state enum:
- `idle` - Initial state
- `initializing` - Player initializing
- `buffering` - Buffering content
- `ready` - Ready to play
- `playing` - Currently playing
- `paused` - Paused
- `completed` - Playback completed
- `error` - Error occurred

### ESiteDrmEvent

DRM event with type and optional message:
- `licenseRequested` - License request initiated
- `licenseAcquired` - License successfully acquired
- `licenseFailed` - License acquisition failed

### ESitePlayerError

Error with code and message:
- `invalidSource` - Invalid source URL
- `drmFailure` - DRM-related failure
- `networkError` - Network error
- `playbackError` - Playback error
- `unknown` - Unknown error

## Limitations

### Emulator Support

DRM-protected content may not work on Android emulators due to:
- Lack of Widevine L1 support
- Missing hardware security features

**Recommendation**: Test on physical Android devices.

### iOS Support

iOS support is planned for a future release. The plugin currently throws `UnsupportedError` on iOS.

## Troubleshooting

### DRM License Fails

1. Verify license URL is correct
2. Check license headers (especially Axinom headers)
3. Ensure device supports Widevine L1 or L3
4. Test on physical device (not emulator)

### Playback Doesn't Start

1. Check network connectivity
2. Verify source URL is accessible
3. Check DRM configuration
4. Monitor error stream for details

### Security Not Working

- Security (FLAG_SECURE) is only enabled during active playback
- Ensure player is in playing state
- Check that activity is properly attached

## Contributing

Contributions are welcome! Please ensure:
- Code follows Dart/Flutter style guidelines
- Tests are included for new features
- Documentation is updated

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Open an issue on GitHub
- Check the [example app](example/lib/main.dart) for usage patterns

---**Note**: This plugin is designed for production use with secure DRM content. Always test thoroughly on physical devices before deploying.
