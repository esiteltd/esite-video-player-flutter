# Getting Started with eSite Flutter Player

This guide will help you set up and use the eSite Flutter Player for DRM-protected video playback.

## Prerequisites

- Flutter SDK 3.3.0 or higher
- Android device (physical device recommended for DRM testing)
- Widevine DRM-protected content URL
- DRM license server URL and credentials

## Installation

Add `esite_flutter_player` to your `pubspec.yaml`:

```yaml
dependencies:
  esite_flutter_player: ^0.1.0
```

Run:

```bash
flutter pub get
```

## Android Setup

### 1. Permissions

The plugin automatically includes necessary permissions, but ensure your app's `AndroidManifest.xml` has:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 2. Minimum SDK

Ensure your `android/app/build.gradle` has:

```gradle
android {
    defaultConfig {
        minSdkVersion 24  // Required for Widevine L1
    }
}
```

## Basic Usage

### 1. Import the Package

```dart
import 'package:esite_flutter_player/esite_flutter_player.dart';
```

### 2. Create Player Configuration

```dart
final config = ESitePlayerConfig(
  sourceUrl: 'https://your-cdn.com/video.mpd',
  drm: ESiteDrmConfig(
    licenseUrl: 'https://license.server.com/widevine',
    scheme: ESiteDrmScheme.widevine,
    licenseHeaders: {
      'X-AxDRM-Message': 'your-drm-token',
    },
  ),
  autoPlay: false,
  preventScreenshots: true,
  preventScreenRecording: true,
);
```

### 3. Initialize Controller

```dart
class MyPlayerPage extends StatefulWidget {
  @override
  State<MyPlayerPage> createState() => _MyPlayerPageState();
}

class _MyPlayerPageState extends State<MyPlayerPage> {
  late ESitePlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = ESitePlayerController(config);
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ESitePlayerView(controller: controller);
  }
}
```

## DRM Setup

### Axinom DRM Configuration

For Axinom DRM, use the following configuration pattern:

```dart
ESiteDrmConfig(
  licenseUrl: 'https://drm-widevine-licensing.axtest.net/AcquireLicense',
  scheme: ESiteDrmScheme.widevine,
  licenseHeaders: {
    'X-AxDRM-Message': 'your-jwt-token',
  },
)
```

### Testing with Axinom Test Content

You can use Axinom's public test vectors for development:

```dart
final config = ESitePlayerConfig(
  sourceUrl: 'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
  drm: ESiteDrmConfig(
    licenseUrl: 'https://drm-widevine-licensing.axtest.net/AcquireLicense',
    scheme: ESiteDrmScheme.widevine,
    licenseHeaders: {
      'X-AxDRM-Message': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
    },
  ),
);
```

## Security Configuration

### Screenshot and Screen Recording Protection

Enable content protection to prevent screenshots and screen recording:

```dart
ESitePlayerConfig(
  preventScreenshots: true,
  preventScreenRecording: true,
  // ... other config
)
```

**Important Notes:**
- Security is automatically enabled when playback starts
- Security is disabled when playback pauses or stops
- This prevents the entire app screen from being captured during playback
- Only works on Android (iOS support planned)

### How FLAG_SECURE Works

When enabled, the player sets `WindowManager.LayoutParams.FLAG_SECURE` which:
- Blocks screenshots
- Blocks screen recording
- Hides content in recent apps overview
- Prevents display mirroring in some scenarios

## Event Handling

### Listen to Playback States

```dart
controller.stateStream.listen((state) {
  switch (state) {
    case ESitePlayerState.idle:
      print('Player idle');
      break;
    case ESitePlayerState.initializing:
      print('Initializing...');
      break;
    case ESitePlayerState.buffering:
      print('Buffering...');
      break;
    case ESitePlayerState.ready:
      print('Ready to play');
      break;
    case ESitePlayerState.playing:
      print('Playing');
      break;
    case ESitePlayerState.paused:
      print('Paused');
      break;
    case ESitePlayerState.completed:
      print('Playback completed');
      break;
    case ESitePlayerState.error:
      print('Error occurred');
      break;
  }
});
```

### Listen to DRM Events

```dart
controller.drmStream.listen((event) {
  switch (event.type) {
    case ESiteDrmEventType.licenseRequested:
      print('License requested: ${event.message}');
      break;
    case ESiteDrmEventType.licenseAcquired:
      print('License acquired: ${event.message}');
      break;
    case ESiteDrmEventType.licenseFailed:
      print('License failed: ${event.message}');
      break;
  }
});
```

### Handle Errors

```dart
controller.errorStream.listen((error) {
  switch (error.code) {
    case ESitePlayerErrorCode.invalidSource:
      showError('Invalid video source');
      break;
    case ESitePlayerErrorCode.drmFailure:
      showError('DRM error: ${error.message}');
      break;
    case ESitePlayerErrorCode.networkError:
      showError('Network error: ${error.message}');
      break;
    case ESitePlayerErrorCode.playbackError:
      showError('Playback error: ${error.message}');
      break;
    case ESitePlayerErrorCode.unknown:
      showError('Unknown error: ${error.message}');
      break;
  }
});
```

## Advanced Features

### Custom HTTP Headers

Add custom headers for authenticated streams:

```dart
ESitePlayerConfig(
  sourceUrl: 'https://your-cdn.com/video.mpd',
  headers: {
    'Authorization': 'Bearer your-token',
    'Custom-Header': 'value',
  },
  // ... other config
)
```

### Playback Speed Control

```dart
await controller.setPlaybackSpeed(1.5); // 0.5x to 4.0x
```

### Volume Control

```dart
await controller.setVolume(0.8); // 0.0 to 1.0
await controller.setMuted(true);
```

### Video Track Selection

```dart
final tracks = await controller.getAvailableVideoTracks();
for (var track in tracks) {
  print('${track['label']}: ${track['width']}x${track['height']}');
}
await controller.setVideoTrack(tracks[0]['id']);
```

### Subtitle Control

```dart
await controller.setSubtitleEnabled(true);
final isEnabled = await controller.isSubtitleEnabled();
```

### Playlist Navigation

```dart
if (await controller.hasNext()) {
  await controller.next();
}

if (await controller.hasPrevious()) {
  await controller.previous();
}
```

## Troubleshooting

### DRM License Acquisition Fails

**Problem:** License acquisition fails with error.

**Solutions:**
1. Verify license URL is correct
2. Check license headers (especially X-AxDRM-Message token)
3. Ensure device has Widevine support
4. Test on physical device (emulators may not support Widevine L1)
5. Check network connectivity
6. Verify token hasn't expired

### Video Doesn't Play

**Problem:** Video doesn't start playing.

**Solutions:**
1. Check source URL is accessible
2. Verify DASH manifest is valid (.mpd file)
3. Monitor error stream for detailed errors
4. Check DRM configuration
5. Ensure INTERNET permission is granted

### Black Screen

**Problem:** Player shows black screen.

**Solutions:**
1. Wait for `ready` state before calling play()
2. Check if DRM license was acquired successfully
3. Verify video format is supported
4. Check if hardware acceleration is enabled

### Screenshot Protection Not Working

**Problem:** Can still take screenshots.

**Solutions:**
1. Ensure `preventScreenshots: true` is set
2. Verify playback is actually active (not paused)
3. Test on different Android versions
4. Some screen recorders may bypass FLAG_SECURE

### Emulator Issues

**Problem:** DRM content won't play on emulator.

**Reason:** Most Android emulators don't support Widevine L1 security level.

**Solution:** Always test DRM content on physical Android devices.

## Best Practices

1. **Always Dispose Controllers**
   ```dart
   @override
   void dispose() {
     controller.dispose();
     super.dispose();
   }
   ```

2. **Handle Errors Gracefully**
   ```dart
   controller.errorStream.listen((error) {
     // Show user-friendly error messages
     // Log errors for debugging
   });
   ```

3. **Monitor Playback State**
   ```dart
   controller.stateStream.listen((state) {
     // Update UI based on state
     // Show loading indicators during buffering
   });
   ```

4. **Test on Physical Devices**
   - DRM requires hardware-backed security
   - Emulators may not provide full DRM support

5. **Secure Your DRM Tokens**
   - Never hardcode DRM tokens in production
   - Fetch tokens from your backend
   - Implement token refresh logic

## Next Steps

- See [README.md](../README.md) for complete API reference
- Check [example app](../example/lib/main.dart) for full implementation
- Review security notes for production deployment

## Support

For issues and questions:
- GitHub Issues: [Report bugs and feature requests]
- Documentation: [API Reference](../README.md)

