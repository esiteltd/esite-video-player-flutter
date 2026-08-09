# eSITE Player example

Demonstrates UUID-based playback with the `esite_flutter_player` plugin.

```bash
flutter run
```

No credentials or server are required — the app starts a **stub backend** in-process.

## What the app does

The plugin calls the client app's own backend, which in production holds the eSITE tenant API key and talks to the video service server-to-server. `lib/stub_backend.dart` stands in for that backend, serving `videoDetail`-shaped responses over loopback.

Three sections:

1. **Backend** — toggle between the stub and a real backend (base URL + access token).
2. **Play by video UUID** — prefilled with the supplied lite test video, `4c2f5fdd-d88e-4d2b-b03d-039edef920a7`.
3. **Stub scenarios** — one tap per resolution path.

Events from all three streams (state, DRM, error) are logged at the bottom.

## Scenarios

| Scenario | Exercises |
|---|---|
| Lite DRM | AES-128 encrypted HLS — resolves to HLS with **no** DRM session |
| No DRM | Unencrypted HLS |
| Full DRM | DASH + Widevine; plays on Android, fails with `unsupportedOnPlatform` on iOS |
| Not ready | `status: packaging` → `videoNotReady` |
| No playback URL | Ready but nothing presigned → `invalidSource` |
| Not found | Backend 404 → `videoNotFound` |
| Unauthorized | Backend 401 → `unauthorized` |

## Playing real encrypted content

The stub cannot mint a genuine playback URL — presigning happens server-side behind the tenant API key. The lite and plain scenarios therefore point at `_placeholderHls` in `lib/main.dart`, a public unencrypted test stream.

To exercise real Lite DRM playback, fetch a video once with the tenant key:

```bash
curl -H "X-API-Key: <tenant-key>" \
  https://video-service.esite-lab.com/api/v1/videos/4c2f5fdd-d88e-4d2b-b03d-039edef920a7
```

and paste the returned `playback_url` into `_placeholderHls`. The token is valid for 6 hours.

## Pointing at a real backend

Turn off "Use built-in stub backend", enter your base URL and access token. The plugin will `GET {baseUrl}/videos/{id}/playback` with `Authorization: Bearer <token>`.

## Tests

```bash
flutter test
```

Smoke tests covering the UI sections and the stub/real backend toggle. The plugin's own unit tests live in `../test/`.
