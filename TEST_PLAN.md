# Test plan

## Automated

```bash
flutter analyze                  # plugin + example, expect 0 issues
flutter test                     # plugin unit tests
cd example && flutter test       # example UI smoke tests
```

**Plugin unit tests** (`test/`) run without a device:

| Area | Covered |
|---|---|
| `parseDrmType` | lite/full spellings, case-insensitivity, unknown → `none` |
| Lite / plain resolution | HLS, no DRM config, no headers |
| Readiness | `status: packaging` → `videoNotReady`; null status treated as ready |
| Missing source | no `playback_url` → `invalidSource` |
| Full DRM | flat and nested license shapes, custom header name, FairPlay scheme, rendition fallback, missing license → `configurationError` |
| HTTP client | URL building, bearer header, 401/404/500, non-JSON body, unreachable host |
| Configuration | validation, use-before-configure, custom mapper, throwing mapper |

## Compilation

```bash
cd example && flutter build apk --debug             # Kotlin
cd example && flutter build ios --simulator --debug # Swift
```

There is no gradle wrapper — build Android through Flutter.

## Manual — Android

Physical device recommended; emulators lack Widevine L1 but L3 works.

1. **Lite DRM** — run the example, tap *Lite DRM*. Expect: buffering → ready → playing, **no DRM events**, working transport controls.
2. **Controls** — play/pause, double-tap left/right (±10s with ripple animation and accumulating label), scrubber, speed menu, quality menu, audio menu.
3. **Theming** — progress bar and buffering ring take `primaryColor`; transport buttons take `secondaryColor`.
4. **Security** — with `preventScreenRecording: true`, screenshots and screen recording are blocked (`FLAG_SECURE`).
5. **Rotation** — rotate mid-playback; position and playback state survive.
6. **Lifecycle** — background the app (playback pauses), return, dismiss the player. Expect a `closed` state event, **not** `completed`.
7. **Completion** — let a video run to the end. Expect `completed`.
8. **Errors** — run the not-ready, not-found and unauthorized scenarios; each surfaces the matching error code before any player appears.
9. **Full DRM** — needs a real full-DRM video plus a backend returning a license descriptor. Expect `licenseAcquired` then playback; a bad entitlement should give `drmFailure` and *only* then a `licenseFailed` DRM event.

## Manual — iOS

Simulator is sufficient for lite and plain.

1. Repeat Android steps 1–3, 6, 7 and 8. State and error codes must match Android exactly.
2. **Full DRM** — expect `unsupportedOnPlatform` before the player is presented, with a message explaining DASH/Widevine vs FairPlay.
3. **Capture protection** — with `preventScreenRecording: true`, start a screen recording: video hides and playback pauses. Screenshots are *not* blocked; this is a documented platform limitation, not a defect.
4. **Orientation** — rotate; the player layer resizes to fill.
5. **iPad** — the speed/quality/audio action sheets anchor correctly rather than crashing.

## Real playback URLs

The stub backend cannot mint presigned URLs. To test genuine Lite DRM decryption, fetch a real `playback_url` with the tenant API key and paste it into `_placeholderHls` in `example/lib/main.dart` (valid 6 hours).

## Not yet verifiable

- No live eSITE response has been observed — every endpoint returns 401 without the tenant key. `drm_type` string values are inferred from the OpenAPI description text.
- Full DRM end-to-end, pending the backend's license descriptor contract.
- FairPlay on iOS, pending backend packaging.
