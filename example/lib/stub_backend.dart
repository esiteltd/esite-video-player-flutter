import 'dart:convert';
import 'dart:io';

/// A throwaway in-app backend that stands in for the client app's real server.
///
/// In production the plugin calls *your* backend, which holds the eSITE tenant
/// API key and talks to the video service server-to-server. This stub serves
/// the same `videoDetail` shape so the example runs with no credentials and no
/// server of your own.
///
/// Point [ESitePlayer.configure] at [baseUrl] to use it.
class StubBackend {
  HttpServer? _server;

  /// Responses keyed by video id. Swap entries to exercise different paths.
  final Map<String, StubResponse> responses;

  StubBackend({required this.responses});

  Future<String> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen((request) async {
      final id = _videoIdFrom(request.uri.path);
      final stub = responses[id];

      request.response.headers.contentType = ContentType.json;
      if (stub == null) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write(jsonEncode({'detail': 'no video with id $id'}));
      } else {
        request.response
          ..statusCode = stub.status
          ..write(jsonEncode(stub.body));
      }
      await request.response.close();
    });
    return baseUrl;
  }

  /// Path is `/videos/{id}/playback`.
  static String _videoIdFrom(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final index = segments.indexOf('videos');
    if (index >= 0 && index + 1 < segments.length) {
      return segments[index + 1];
    }
    return '';
  }

  String get baseUrl => 'http://127.0.0.1:${_server!.port}';

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

class StubResponse {
  final int status;
  final Map<String, dynamic> body;

  const StubResponse({this.status = 200, required this.body});
}
