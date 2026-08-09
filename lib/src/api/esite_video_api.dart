import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/esite_player_error.dart';
import 'esite_video_mapper.dart';

/// Fetches playback metadata for a video UUID from the **client app's own
/// backend**.
///
/// The plugin never talks to the eSITE video service directly: the tenant API
/// key stays server-side, and the token carried here is strictly between the
/// app and its backend.
class ESiteVideoApi {
  final String baseUrl;
  final String videoPath;
  final ESiteTokenProvider? tokenProvider;
  final Map<String, String> extraHeaders;
  final Duration timeout;

  const ESiteVideoApi({
    required this.baseUrl,
    required this.videoPath,
    this.tokenProvider,
    this.extraHeaders = const {},
    this.timeout = const Duration(seconds: 20),
  });

  Uri buildUri(String videoId) {
    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = videoPath.replaceAll('{id}', Uri.encodeComponent(videoId));
    return Uri.parse('$base${path.startsWith('/') ? '' : '/'}$path');
  }

  Future<Map<String, dynamic>> fetchVideo(String videoId) async {
    final uri = buildUri(videoId);
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final token = await tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      extraHeaders.forEach(request.headers.set);

      final response = await request.close().timeout(timeout);
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw ESitePlayerException(
          ESitePlayerError(
            code: ESitePlayerErrorCode.unauthorized,
            message:
                'Backend rejected the access token '
                '(HTTP ${response.statusCode})${_detail(body)}',
          ),
        );
      }
      if (response.statusCode == 404) {
        throw ESitePlayerException(
          ESitePlayerError(
            code: ESitePlayerErrorCode.videoNotFound,
            message: 'No video with id $videoId${_detail(body)}',
          ),
        );
      }
      if (response.statusCode != 200) {
        throw ESitePlayerException(
          ESitePlayerError(
            code: ESitePlayerErrorCode.networkError,
            message:
                'Playback lookup failed with HTTP '
                '${response.statusCode}${_detail(body)}',
          ),
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw ESitePlayerException(
          const ESitePlayerError(
            code: ESitePlayerErrorCode.configurationError,
            message: 'Playback response was not a JSON object.',
          ),
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on ESitePlayerException {
      rethrow;
    } on TimeoutException {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.networkError,
          message: 'Playback lookup timed out after ${timeout.inSeconds}s.',
        ),
      );
    } on SocketException catch (e) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.networkError,
          message: 'Could not reach $uri: ${e.message}',
        ),
      );
    } on FormatException catch (e) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.configurationError,
          message: 'Playback response was not valid JSON: ${e.message}',
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Surfaces an RFC-7807 `detail` when the backend sends one, so failures
  /// carry the server's own explanation rather than a bare status code.
  static String _detail(String body) {
    if (body.isEmpty) return '';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final detail = decoded['detail'] ?? decoded['title'] ?? decoded['error'];
        if (detail != null) return ': $detail';
      }
    } on FormatException {
      // Not JSON — fall through to the truncated raw body.
    }
    return ': ${body.length > 200 ? '${body.substring(0, 200)}…' : body}';
  }
}
