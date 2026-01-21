# ESite Flutter Player - Test Suite

A comprehensive testing application for the ESite Flutter Player plugin, demonstrating DRM-protected video playback with various authentication and error scenarios.

## Features

This example app provides:

- **7 Test Scenarios** covering different authentication states
- **Full Playback Controls** (play, pause, seek, next/previous)
- **Quality Selection** (video track switching)
- **Volume & Speed Control**
- **Event Logging** (real-time monitoring of player events)
- **Security Features** (screenshot blocking, screen recording prevention)

## Test Scenarios

### ✅ Valid Authentication
Tests normal playback flow with valid DRM license credentials. Should play successfully.

### ❌ Expired Token
Simulates an expired or invalid authentication token. Should fail with DRM error.

### ❌ Invalid License URL
Tests behavior when the license server URL is incorrect. Should fail with network error.

### ❌ Missing Authentication
Attempts playback without required authentication headers. Should fail with DRM error.

### ❌ Wrong DRM Scheme
Uses PlayReady scheme for Widevine-encrypted content. Should fail with DRM error.

### ❌ Network Error
Tests with non-existent domain to simulate network connectivity issues.

### ❌ Invalid URL
Tests with malformed content URL to validate error handling.

## Running the Example

### Prerequisites
- Flutter SDK installed and configured
- Android device or emulator with Android 7.0 (API 24) or higher
- For iOS: macOS with Xcode installed

### Steps

1. **Navigate to the example directory:**
   ```bash
   cd example
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **List available devices:**
   ```bash
   flutter devices
   ```

4. **Run on a device:**
   ```bash
   flutter run -d <device_id>
   ```

   Or simply:
   ```bash
   flutter run
   ```

## Using the Test Suite

1. **Launch the app** - you'll see the scenario selection screen
2. **Select a test scenario** - tap any scenario button to initialize the player
3. **Observe behavior** - watch the player state and check the Events tab for detailed logs
4. **Test controls** - use the Controls tab for playback operations
5. **Adjust settings** - use the Settings tab to modify volume, speed, and quality
6. **Try another scenario** - tap the ✕ button to return to scenario selection

## Testing Best Practices

### Testing DRM Functionality

**⚠️ Important: Use a Real Device**

DRM features (Widevine) work best on physical devices. Emulators have limitations:
- May not support Widevine L1 (only L3)
- Screenshot prevention may not work
- Screen recording detection may be limited

### Recommended Test Flow

1. Start with **Valid Authentication** to verify basic functionality
2. Test **Expired Token** to see DRM authentication failure
3. Test **Missing Authentication** to verify header validation
4. Test **Network Error** to see connectivity error handling
5. Test **Invalid URL** to verify input validation

### Monitoring Events

The **Events** tab shows real-time logs of:
- Player state changes
- DRM events (license requests, key loading)
- Errors with detailed messages
- User actions

Use this to debug and understand the player lifecycle.

## Customizing Test Scenarios

To add your own DRM content for testing:

1. Open `lib/main.dart`
2. Find the `_getConfigForScenario` method
3. Modify the `TestScenario.validAuth` case with your URLs:

```dart
case TestScenario.validAuth:
  return ESitePlayerConfig(
    sourceUrl: 'YOUR_MANIFEST_URL.mpd',  // or .m3u8
    drm: ESiteDrmConfig(
      licenseUrl: 'YOUR_LICENSE_SERVER_URL',
      scheme: ESiteDrmScheme.widevine,  // or playready
      licenseHeaders: {
        'Authorization': 'Bearer YOUR_TOKEN',
        // Add other required headers
      },
    ),
    autoPlay: false,
    preventScreenshots: true,
    preventScreenRecording: true,
  );
```

## Supported Formats

- **DASH**: `.mpd` manifests (requires `media3-exoplayer-dash`)
- **HLS**: `.m3u8` playlists (requires `media3-exoplayer-hls`)
- **DRM Schemes**: Widevine, PlayReady

## Troubleshooting

### "No suitable media source factory found"
- **Cause**: Missing media format dependencies in `android/build.gradle`
- **Fix**: Ensure `media3-exoplayer-dash` and/or `media3-exoplayer-hls` are included

### DRM License Acquisition Failed
- Verify license URL is correct
- Check authentication headers are valid
- Ensure token is not expired
- Confirm network connectivity

### Video Not Playing
- Check the manifest URL is accessible
- Verify DRM scheme matches content encryption
- Review Events tab for detailed error messages
- Test on a real device, not emulator

### Controls Not Responding
- Ensure player state is `ready` or `playing`
- Check Events tab for errors
- Verify content has loaded successfully

## API Reference

See the [main plugin documentation](../README.md) for detailed API reference.

## Additional Resources

- [ExoPlayer DRM Documentation](https://developer.android.com/guide/topics/media/drm)
- [Widevine DRM](https://www.widevine.com/)
- [DASH Format](https://dashif.org/)
- [HLS Format](https://developer.apple.com/streaming/)

