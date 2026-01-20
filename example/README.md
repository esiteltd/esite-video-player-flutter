# eSite Flutter Player Example

This example demonstrates all features of the eSite Flutter Player plugin.

## Features Demonstrated

- DRM-protected video playback with Axinom test content
- Screenshot and screen recording protection
- Playback controls (play, pause, seek forward/backward)
- Playback speed control (0.5x to 4.0x)
- Volume control and mute
- Video quality track selection
- Real-time state monitoring
- DRM event notifications
- Error handling

## Running the Example

1. Connect a physical Android device (DRM may not work on emulators)

2. Run the app:
   ```bash
   flutter run
   ```

3. The app will load Axinom test content automatically

## Test Content

The example uses publicly available Axinom DRM test vectors:
- **Source**: 1080p DASH stream
- **DRM**: Widevine with test license
- **Security**: Screenshot protection enabled

## Notes

- Requires a physical Android device with Widevine L1 or L3 support
- Emulators typically don't support DRM playback
- Network connectivity required for streaming

## Learn More

See the main [README](../README.md) and [documentation](../doc/) for complete API reference and usage guide.
