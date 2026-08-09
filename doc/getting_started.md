# Getting started

## 1. Add the dependency

```yaml
dependencies:
  esite_flutter_player: ^0.3.0
```

Android needs minSdk 24; iOS needs a deployment target of 13.0. Nothing else to configure — the plugin declares its own permissions and registers its native screen.

## 2. Stand up the backend endpoint

The plugin calls **your** backend, not the eSITE service. Your backend holds the tenant API key and makes the server-to-server call:

```
GET {your-backend}/videos/{id}/playback
  Authorization: Bearer <your app's token>
        │
        └──▶ GET https://video-service.esite-lab.com/api/v1/videos/{id}
                 X-API-Key: <tenant key>
```

The simplest implementation is a pass-through: return the eSITE `videoDetail` response unchanged. The plugin parses that shape natively.

```json
{
  "id": "4c2f5fdd-d88e-4d2b-b03d-039edef920a7",
  "name": "Sample",
  "status": "ready",
  "drm_type": "lite",
  "playback_url": "https://…/master.m3u8?token=…",
  "renditions": []
}
```

> **Why not call eSITE directly from the app?** The service authenticates with a tenant API key that grants UPLOADER-or-higher access — including upload and delete. An API key shipped in an APK or IPA is extractable. Keeping it server-side is the point of this topology.

### Full DRM

eSITE never returns license material (`"DRM key material is never returned"`), so for `drm_type: "full"` your backend must add the license descriptor itself:

```json
{
  "drm_type": "full",
  "playback_url": "https://…/manifest.mpd?token=…",
  "license_server_url": "https://…/widevine",
  "entitlement_message": "…",
  "license_header_name": "X-Entitlement-Message"
}
```

`license_header_name` is optional and defaults to `X-Entitlement-Message`. A nested form is also accepted:

```json
{ "drm": { "license_url": "…", "headers": { "Authorization": "Bearer …" } } }
```

## 3. Configure the plugin

Once, at app start:

```dart
import 'package:esite_flutter_player/esite_flutter_player.dart';

void main() {
  ESitePlayer.configure(
    baseUrl: 'https://api.myapp.com',
    videoPath: '/videos/{id}/playback',   // default
    tokenProvider: () async => auth.accessToken,
  );
  runApp(const MyApp());
}
```

`tokenProvider` runs per request, so token refreshes are picked up automatically. Return `null` to send no `Authorization` header.

## 4. Play a video

```dart
Future<void> play(String videoId) async {
  try {
    final controller = await ESitePlayerController.forVideo(
      videoId,
      options: const ESitePlaybackOptions(
        autoPlay: true,
        preventScreenRecording: true,
        primaryColor: Color(0xFF6C63FF),
        secondaryColor: Colors.white,
      ),
    );

    controller.stateStream.listen((state) {
      if (state == ESitePlayerState.completed) {
        // Watched to the end.
      } else if (state == ESitePlayerState.closed) {
        // Dismissed early.
      }
    });

    controller.errorStream.listen((e) => report(e.message));

    await controller.launchPlayer();
  } on ESitePlayerException catch (e) {
    switch (e.code) {
      case ESitePlayerErrorCode.unauthorized:
        await auth.refresh();
      case ESitePlayerErrorCode.videoNotReady:
        showMessage('Still processing — try again shortly.');
      case ESitePlayerErrorCode.unsupportedOnPlatform:
        showMessage('This video cannot be played on iOS yet.');
      default:
        showMessage(e.message);
    }
  }
}
```

Dispose the controller when you are done with it. A controller is bound to one video — play another by creating a new one.

## 5. A backend with a different shape

If your response does not match `videoDetail`, map it:

```dart
ESitePlayer.configure(
  baseUrl: 'https://api.myapp.com',
  tokenProvider: () async => auth.accessToken,
  mapper: (json) => ESiteResolvedSource(
    url: json['stream_url'] as String,
    streamFormat: ESiteStreamFormat.hls,
    drmType: ESiteDrmType.lite,
    title: json['title'] as String?,
  ),
);
```

Throwing inside the mapper surfaces as `configurationError`.

## Running the example

```bash
cd example && flutter run
```

It ships a stub backend, so it runs with no credentials. Toggle "Use built-in stub backend" off to point at a real server.

To play genuinely encrypted content, replace `_placeholderHls` in `example/lib/main.dart` with a real `playback_url` obtained from `GET /api/v1/videos/{id}`.

## Next

- [API reference](api_reference.md)
- [Security](security.md)
