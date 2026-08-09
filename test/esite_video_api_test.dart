import 'dart:convert';
import 'dart:io';

import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:esite_flutter_player/src/api/esite_video_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spins up a real loopback server so the HTTP path is exercised end to end
/// rather than mocked away.
class _StubBackend {
  late final HttpServer _server;
  final List<HttpHeaders> receivedHeaders = [];
  final List<String> receivedPaths = [];

  int status = 200;
  String body = '{}';
  String contentType = 'application/json';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      receivedHeaders.add(request.headers);
      receivedPaths.add(request.uri.path);
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.parse(contentType)
        ..write(body);
      await request.response.close();
    });
  }

  String get baseUrl => 'http://127.0.0.1:${_server.port}';
  Future<void> stop() => _server.close(force: true);
}

void main() {
  late _StubBackend backend;

  setUp(() async {
    backend = _StubBackend();
    await backend.start();
  });

  tearDown(() async {
    await backend.stop();
    ESitePlayer.reset();
  });

  ESiteVideoApi apiFor({String path = '/videos/{id}/playback'}) => ESiteVideoApi(
    baseUrl: backend.baseUrl,
    videoPath: path,
    tokenProvider: () async => 'app-token',
  );

  group('URL building', () {
    test('substitutes {id} and tolerates a trailing slash on baseUrl', () {
      final api = ESiteVideoApi(
        baseUrl: 'https://api.myapp.com/',
        videoPath: '/videos/{id}/playback',
      );

      expect(
        api.buildUri('abc-123').toString(),
        'https://api.myapp.com/videos/abc-123/playback',
      );
    });

    test('encodes the video id', () {
      final api = ESiteVideoApi(
        baseUrl: 'https://api.myapp.com',
        videoPath: '/v/{id}',
      );

      expect(api.buildUri('a/b').toString(), 'https://api.myapp.com/v/a%2Fb');
    });
  });

  group('fetchVideo', () {
    test('sends the bearer token and returns the decoded body', () async {
      backend.body = jsonEncode({'id': 'v1', 'drm_type': 'lite'});

      final json = await apiFor().fetchVideo('v1');

      expect(json['drm_type'], 'lite');
      expect(backend.receivedPaths.single, '/videos/v1/playback');
      expect(
        backend.receivedHeaders.single.value(HttpHeaders.authorizationHeader),
        'Bearer app-token',
      );
    });

    test('401 maps to unauthorized and surfaces the problem detail', () async {
      backend
        ..status = 401
        ..body = jsonEncode({'detail': 'token expired'});

      await expectLater(
        apiFor().fetchVideo('v1'),
        throwsA(
          isA<ESitePlayerException>()
              .having((e) => e.code, 'code', ESitePlayerErrorCode.unauthorized)
              .having((e) => e.message, 'message', contains('token expired')),
        ),
      );
    });

    test('404 maps to videoNotFound', () async {
      backend
        ..status = 404
        ..body = jsonEncode({'detail': 'no such video'});

      await expectLater(
        apiFor().fetchVideo('nope'),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.videoNotFound,
          ),
        ),
      );
    });

    test('500 maps to networkError', () async {
      backend
        ..status = 500
        ..body = 'boom';

      await expectLater(
        apiFor().fetchVideo('v1'),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.networkError,
          ),
        ),
      );
    });

    test('a non-JSON body maps to configurationError', () async {
      backend.body = 'not json at all';

      await expectLater(
        apiFor().fetchVideo('v1'),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.configurationError,
          ),
        ),
      );
    });

    test('an unreachable backend maps to networkError', () async {
      final api = ESiteVideoApi(
        baseUrl: 'http://127.0.0.1:1',
        videoPath: '/videos/{id}',
        timeout: const Duration(seconds: 2),
      );

      await expectLater(
        api.fetchVideo('v1'),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.networkError,
          ),
        ),
      );
    });
  });

  group('ESitePlayer.configure', () {
    test('rejects an empty baseUrl and a path without {id}', () {
      expect(
        () => ESitePlayer.configure(baseUrl: ''),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ESitePlayer.configure(
          baseUrl: 'https://api.myapp.com',
          videoPath: '/videos/playback',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws configurationError when used before configure', () {
      expect(
        () => ESitePlayer.configuration,
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.configurationError,
          ),
        ),
      );
    });

    test('resolves a lite video end to end through the stub backend', () async {
      backend.body = jsonEncode({
        'id': '4c2f5fdd-d88e-4d2b-b03d-039edef920a7',
        'name': 'Lite sample',
        'status': 'ready',
        'drm_type': 'lite',
        'playback_url': 'https://cdn.example.com/master.m3u8?token=t',
        'renditions': [],
      });

      ESitePlayer.configure(
        baseUrl: backend.baseUrl,
        tokenProvider: () async => 'app-token',
      );

      final source = await ESitePlayer.configuration.resolve(
        '4c2f5fdd-d88e-4d2b-b03d-039edef920a7',
      );

      expect(source.drmType, ESiteDrmType.lite);
      expect(source.streamFormat, ESiteStreamFormat.hls);
      expect(source.drm, isNull);
    });

    test('a custom mapper takes precedence over the built-in parser', () async {
      backend.body = jsonEncode({'stream': 'https://cdn/x.m3u8'});

      ESitePlayer.configure(
        baseUrl: backend.baseUrl,
        mapper: (json) => ESiteResolvedSource(
          url: json['stream'] as String,
          streamFormat: ESiteStreamFormat.hls,
          drmType: ESiteDrmType.lite,
        ),
      );

      final source = await ESitePlayer.configuration.resolve('v1');

      expect(source.url, 'https://cdn/x.m3u8');
    });

    test('a throwing mapper surfaces as configurationError', () async {
      backend.body = jsonEncode({'unexpected': true});

      ESitePlayer.configure(
        baseUrl: backend.baseUrl,
        mapper: (json) => throw StateError('missing field'),
      );

      await expectLater(
        ESitePlayer.configuration.resolve('v1'),
        throwsA(
          isA<ESitePlayerException>().having(
            (e) => e.code,
            'code',
            ESitePlayerErrorCode.configurationError,
          ),
        ),
      );
    });
  });
}
