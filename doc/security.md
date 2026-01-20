# Security Notes - eSite Flutter Player

Important security considerations when using the eSite Flutter Player.

## Screenshot and Screen Recording Protection

### How It Works

The player uses Android's `FLAG_SECURE` to prevent content leakage:

```kotlin
window.setFlags(
  WindowManager.LayoutParams.FLAG_SECURE,
  WindowManager.LayoutParams.FLAG_SECURE
)
```

### What It Protects Against

✅ **Protected:**
- Screenshots via power + volume down
- Screenshots via accessibility services
- Screen recording apps (most)
- Recent apps preview/screenshot
- Display mirroring (some scenarios)

❌ **Not Protected:**
- Physical cameras pointed at screen
- Some rooted devices with specialized tools
- Hardware-level screen capture
- External HDMI capture devices

### Behavior

The security flag is managed automatically:

- **Enabled:** When video starts playing
- **Disabled:** When video is paused
- **Disabled:** When video completes
- **Disabled:** When player is disposed

This ensures security only affects the app during active playback.

### Configuration

```dart
ESitePlayerConfig(
  preventScreenshots: true,      // Blocks screenshots
  preventScreenRecording: true,  // Blocks screen recording
  // ...
)
```

Both flags use the same `FLAG_SECURE` mechanism. Set both to `true` for maximum protection.

### Limitations

1. **Whole Activity Protection**
   - `FLAG_SECURE` protects the entire activity, not just the video
   - Your app's UI will also be blocked from screenshots during playback

2. **Android Version Differences**
   - Behavior may vary across Android versions
   - Some screen recorders bypass FLAG_SECURE on older devices

3. **Root/Custom ROMs**
   - Rooted devices may bypass security
   - Custom ROMs may not enforce FLAG_SECURE

4. **Development Impact**
   - You cannot take screenshots for debugging during playback
   - Disable in development builds if needed

### Testing

To verify screenshot protection works:

1. Start playback
2. Try taking a screenshot (Power + Volume Down)
3. Screenshot should fail or show black screen
4. Pause playback
5. Screenshot should work normally again

## DRM Security

### What We Protect

✅ **Protected:**
- DRM license keys (never exposed to Flutter)
- License server communication (encrypted)
- Decoded video frames (secure rendering path)
- DRM session lifecycle

❌ **Not Logged:**
- Raw media URLs (not printed to console)
- DRM keys or license payloads
- Sensitive license headers

### Secure Decoder Path

The player uses ExoPlayer's secure decoder path when available:

- Hardware-backed DRM (Widevine L1)
- Secure video pipeline
- Protected content buffers
- No plaintext media access

### Best Practices

1. **Never Log Sensitive Data**
   ```dart
   // ❌ DON'T DO THIS
   print('License URL: ${config.drm.licenseUrl}');
   print('DRM Token: ${config.drm.licenseHeaders}');
   
   // ✅ DO THIS
   debugPrint('Initializing DRM player');
   ```

2. **Fetch DRM Tokens Securely**
   ```dart
   // ✅ Fetch from your backend
   final token = await api.getDrmToken(videoId);
   
   // ❌ Don't hardcode
   final token = 'eyJhbGc...'; // Never do this!
   ```

3. **Token Expiration**
   - Implement token refresh logic
   - Handle license renewal for long playback sessions
   - Monitor DRM events for license failures

4. **HTTPS Only**
   - Always use HTTPS for license servers
   - Use HTTPS for media URLs
   - Never transmit DRM tokens over HTTP

## Network Security

### Required Permissions

The plugin requires these permissions (automatically included):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Network Security Config

For production apps, configure network security in `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

Reference it in your manifest:

```xml
<application
    android:networkSecurityConfig="@xml/network_security_config">
```

This ensures:
- No cleartext (HTTP) traffic
- Only system-trusted certificates
- Protection against MITM attacks

## Widevine Security Levels

### L1 (Hardware-backed)

✅ **Highest Security:**
- Crypto operations in Trusted Execution Environment (TEE)
- Secure video path
- Maximum content protection

**Requirements:**
- Physical device with Widevine L1 certification
- Hardware security support

### L3 (Software-based)

⚠️ **Lower Security:**
- Crypto operations in software
- Less secure than L1
- May not meet some content provider requirements

**Common on:**
- Emulators
- Older/budget devices
- Non-certified devices

### Checking Security Level

The player automatically uses the highest available security level. Content providers may restrict playback based on security level.

## Emulator Limitations

### Why DRM Fails on Emulators

Most Android emulators:
- Don't have Widevine L1 support
- May only support L3 or no Widevine at all
- Lack hardware security features
- Can't establish secure video path

### Development Recommendations

1. **Use Physical Devices**
   - Always test DRM on real Android devices
   - Keep test devices with Widevine L1

2. **Emulator Testing**
   - Test non-DRM functionality on emulators
   - Test UI, state management, error handling
   - Use mock data for DRM scenarios

3. **CI/CD**
   - Use device farms for automated testing
   - Firebase Test Lab, AWS Device Farm, etc.

## Production Checklist

Before releasing your app:

- [ ] DRM tokens fetched from secure backend
- [ ] No sensitive data logged
- [ ] HTTPS enforced for all endpoints
- [ ] Network security config configured
- [ ] Screenshot protection tested on multiple devices
- [ ] Error handling implemented for all DRM failures
- [ ] Token refresh logic implemented
- [ ] Tested on physical devices with Widevine L1
- [ ] ProGuard/R8 rules configured (if using obfuscation)
- [ ] Security review completed

## ProGuard/R8 Configuration

If using code obfuscation, add these rules to `android/app/proguard-rules.pro`:

```proguard
# eSite Flutter Player
-keep class com.esite.player.** { *; }

# ExoPlayer
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Widevine
-keep class com.google.android.exoplayer2.drm.** { *; }
```

## Handling Security Events

Monitor security-related events:

```dart
controller.drmStream.listen((event) {
  switch (event.type) {
    case ESiteDrmEventType.licenseFailed:
      // Log security incident
      analytics.logSecurityEvent('drm_license_failed');
      
      // Show user-friendly error
      showError('Unable to play protected content');
      
      // Don't expose technical details to users
      break;
  }
});

controller.errorStream.listen((error) {
  if (error.code == ESitePlayerErrorCode.drmFailure) {
    // Handle DRM failure
    // Don't log sensitive error messages in production
  }
});
```

## Content Provider Requirements

Different content providers have different security requirements:

### Minimum Requirements
- Widevine L3 support
- HTTPS for all connections
- No cleartext traffic

### Standard Requirements
- Widevine L1 support
- Screenshot protection enabled
- Network security config
- Certificate pinning (optional)

### Premium Requirements
- Widevine L1 required
- Hardware-backed keystore
- Device attestation
- Secure boot verification
- Additional platform-specific protections

Check your content provider's requirements and configure accordingly.

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** create a public GitHub issue
2. **DO NOT** disclose publicly until patched
3. Contact the package maintainers privately
4. Provide detailed reproduction steps
5. Allow reasonable time for fix and release

## Legal Compliance

Ensure your app complies with:

- Content provider license agreements
- DRM technology export regulations
- Local privacy laws (GDPR, CCPA, etc.)
- Platform-specific requirements (Google Play, etc.)

The player provides tools for security, but you're responsible for proper implementation and compliance.

## Additional Resources

- [Widevine Documentation](https://www.widevine.com/)
- [ExoPlayer Security Best Practices](https://exoplayer.dev/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [Axinom DRM Documentation](https://github.com/Axinom)

