import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:flutter_test/flutter_test.dart';

/// A `videoDetail` payload as the video service returns it.
Map<String, dynamic> detail({
  String id = '4c2f5fdd-d88e-4d2b-b03d-039edef920a7',
  String? drmType = 'lite',
  String? status = 'ready',
  String? playbackUrl = 'https://cdn.example.com/p/master.m3u8?token=abc',
  List<Map<String, dynamic>>? renditions,
  Map<String, dynamic> extra = const {},
}) {
  return {
    'id': id,
    'name': 'Sample',
    'status': status,
    'drm_type': drmType,
    'playback_url': playbackUrl,
    'renditions': renditions ?? const [],
    ...extra,
  };
}

ESiteResolvedSource resolve(
  Map<String, dynamic> json, {
  ESiteDrmScheme scheme = ESiteDrmScheme.widevine,
}) =>
    ESitePlaybackResolver.resolve(
      ESiteVideoDetail.fromJson(json),
      scheme: scheme,
    );

void main() {
  group('parseDrmType', () {
    test('recognises lite and full spellings case-insensitively', () {
      expect(parseDrmType('lite'), ESiteDrmType.lite);
      expect(parseDrmType('LITE'), ESiteDrmType.lite);
      expect(parseDrmType('lite_drm'), ESiteDrmType.lite);
      expect(parseDrmType('full'), ESiteDrmType.full);
      expect(parseDrmType('Full-DRM'), ESiteDrmType.full);
      expect(parseDrmType('widevine'), ESiteDrmType.full);
    });

    test('falls back to none for unknown, empty and null values', () {
      expect(parseDrmType(null), ESiteDrmType.none);
      expect(parseDrmType(''), ESiteDrmType.none);
      expect(parseDrmType('plain'), ESiteDrmType.none);
      expect(parseDrmType('something-new'), ESiteDrmType.none);
    });
  });

  group('lite and plain', () {
    test('lite resolves to HLS with no DRM session and no headers', () {
      final source = resolve(detail(drmType: 'lite'));

      expect(source.streamFormat, ESiteStreamFormat.hls);
      expect(source.drmType, ESiteDrmType.lite);
      expect(source.drm, isNull);
      expect(source.headers, isNull);
      expect(source.url, 'https://cdn.example.com/p/master.m3u8?token=abc');
      expect(source.title, 'Sample');
    });

    test('plain resolves to HLS with no DRM session', () {
      final source = resolve(detail(drmType: null));

      expect(source.streamFormat, ESiteStreamFormat.hls);
      expect(source.drmType, ESiteDrmType.none);
      expect(source.drm, isNull);
    });

    test('missing playback_url is an invalidSource error', () {
      expect(
        () => resolve(detail(playbackUrl: null)),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.invalidSource,
          ),
        ),
      );
    });
  });

  group('readiness', () {
    test('a video still packaging is rejected', () {
      expect(
        () => resolve(detail(status: 'packaging')),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.videoNotReady,
          ),
        ),
      );
    });

    test('an absent status is treated as ready', () {
      expect(resolve(detail(status: null)).drmType, ESiteDrmType.lite);
    });
  });

  group('full DRM', () {
    final license = {
      'license_server_url': 'https://license.esite.example/widevine',
      'entitlement_message': 'entitlement-token',
    };

    test('resolves to DASH with a Widevine license descriptor', () {
      final source = resolve(
        detail(
          drmType: 'full',
          playbackUrl: 'https://cdn.example.com/p/manifest.mpd?token=abc',
          extra: license,
        ),
      );

      expect(source.streamFormat, ESiteStreamFormat.dash);
      expect(source.drmType, ESiteDrmType.full);
      expect(source.drm!.scheme, ESiteDrmScheme.widevine);
      expect(source.drm!.licenseUrl, 'https://license.esite.example/widevine');
      expect(
        source.drm!.licenseHeaders,
        {'X-Entitlement-Message': 'entitlement-token'},
      );
    });

    test('honours a backend-supplied license header name', () {
      final source = resolve(
        detail(
          drmType: 'full',
          extra: {...license, 'license_header_name': 'X-Custom-Token'},
        ),
      );

      expect(source.drm!.licenseHeaders, {'X-Custom-Token': 'entitlement-token'});
    });

    test('accepts a nested drm object with an explicit headers map', () {
      final source = resolve(
        detail(
          drmType: 'full',
          extra: {
            'drm': {
              'license_url': 'https://license.esite.example/wv',
              'headers': {'Authorization': 'Bearer xyz'},
            },
          },
        ),
      );

      expect(source.drm!.licenseUrl, 'https://license.esite.example/wv');
      expect(source.drm!.licenseHeaders, {'Authorization': 'Bearer xyz'});
    });

    test('falls back to the highest rendition when playback_url is null', () {
      final source = resolve(
        detail(
          drmType: 'full',
          playbackUrl: null,
          renditions: [
            {'id': 'a', 'spec_label': '480p', 'playback_url': 'https://x/480.mpd'},
            {'id': 'b', 'spec_label': '1080p', 'playback_url': 'https://x/1080.mpd'},
            {'id': 'c', 'spec_label': '720p', 'playback_url': null},
          ],
          extra: license,
        ),
      );

      expect(source.url, 'https://x/1080.mpd');
    });

    test('requests FairPlay when the caller asks for it', () {
      final source = resolve(
        detail(drmType: 'full', extra: license),
        scheme: ESiteDrmScheme.fairplay,
      );

      expect(source.drm!.scheme, ESiteDrmScheme.fairplay);
    });

    test('a missing license server is a configurationError', () {
      expect(
        () => resolve(detail(drmType: 'full')),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.configurationError,
          ),
        ),
      );
    });

    test('no usable source at all is an invalidSource error', () {
      expect(
        () => resolve(
          detail(drmType: 'full', playbackUrl: null, extra: license),
        ),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.invalidSource,
          ),
        ),
      );
    });
  });
}
