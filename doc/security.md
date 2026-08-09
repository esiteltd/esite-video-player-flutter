# Security

## Credential topology

```
Flutter app ──access token──▶ your backend ──X-API-Key──▶ eSITE Video Service
  (plugin)                    (server-to-server)
```

The plugin never contacts the eSITE service. This is deliberate:

- The eSITE tenant API key authenticates at **UPLOADER or higher**, which includes upload and (for EDITOR/ADMIN) delete. It is not a read-only playback credential.
- Anything shipped in an APK or IPA is extractable. Binaries are not a secret store.
- The token the plugin sends is scoped to your own backend, so you control its lifetime, audience and revocation.

**Do not** add an eSITE API key to `ESitePlayer.configure(headers: …)` to "simplify" integration. That defeats the whole arrangement.

## Playback URLs are short-lived

The service issues:

- **6-hour tokens** on the HLS playback endpoint (lite and plain)
- **15-minute presigned URLs** for renditions and thumbnails

Resolve immediately before playing. Do not cache a resolved `ESiteResolvedSource` across sessions or persist it — it will expire, and while valid it is a bearer credential for the content.

`tokenProvider` is invoked per request precisely so that a rotated app token is used without reconfiguration.

## Protection modes

### Lite DRM

HLS with AES-128 encrypted segments. The key is served from a key route embedded in the token-authenticated playlist, and the player fetches it directly.

This protects content **in transit and at rest in storage**. It is not a DRM system: the key reaches the player in the clear over TLS, and there is no device binding, no output protection and no revocation. Use it where the threat model is casual copying, not determined extraction.

### Full DRM

DASH packaged with Widevine, keys issued by a license server per playback session. This gives device binding, security-level enforcement and revocation.

On Android the plugin reports the device's Widevine security level as a `licenseAcquired` DRM event for diagnostics. It does **not** force a level — a previous version attempted an L1→L3 fallback that was dead code and never affected playback; the honest position is that ExoPlayer selects the level and the license server enforces policy.

## Screenshot and recording protection

| | Android | iOS |
|---|---|---|
| Block screenshots | ✅ `FLAG_SECURE` | ❌ **Not possible** |
| Block screen recording | ✅ `FLAG_SECURE` | ⚠️ Video hidden and paused while captured |
| Block mirroring / AirPlay capture | ✅ | ⚠️ Same mechanism |

Android's `FLAG_SECURE` is enforced by the window compositor and genuinely prevents capture.

iOS offers no equivalent. The plugin observes `UIScreen.isCaptured` and, while capture is active, hides the video layer and pauses playback. Screenshots can only be detected *after* they are taken (`userDidTakeScreenshotNotification`) — never prevented.

Do not present iOS screenshot protection to stakeholders as equivalent to Android's. If your content genuinely requires it, iOS cannot deliver it at any layer, and no plugin can change that.

## Transport

All playback and license traffic must be HTTPS. Android blocks cleartext by default and surfaces `ERROR_CODE_IO_CLEARTEXT_NOT_PERMITTED` as a `networkError`; iOS App Transport Security does the same. Do not add cleartext exemptions to make a staging environment work — terminate TLS there instead.

## Error messages

Resolution errors include the backend's RFC-7807 `detail` when present, so failures are diagnosable. Make sure your backend does not leak internal details (stack traces, upstream URLs, tenant identifiers) into that field, since it reaches the client.

## Reporting a vulnerability

Contact the eSITE team directly rather than opening a public issue.
