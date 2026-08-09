/// Error codes reported by the player and by video resolution.
///
/// The first five values are also the wire format used by the native players
/// (the ordinal is sent over the error EventChannel), so **never reorder or
/// remove them** — only append. Values from [videoNotReady] onward are raised
/// on the Dart side during resolution and are not sent by native code.
enum ESitePlayerErrorCode {
  invalidSource,
  drmFailure,
  networkError,
  playbackError,
  unknown,

  /// The video exists but its pipeline has not produced playable renditions
  /// yet (status is not `ready`).
  videoNotReady,

  /// The backend rejected the access token (HTTP 401/403).
  unauthorized,

  /// No video with that UUID (HTTP 404).
  videoNotFound,

  /// The video's protection scheme cannot be played on this platform — most
  /// notably full DRM on iOS while FairPlay packaging is pending.
  unsupportedOnPlatform,

  /// The plugin was used before [ESitePlayer.configure], or the backend
  /// returned a response the resolver could not understand.
  configurationError,
}

class ESitePlayerError {
  final ESitePlayerErrorCode code;
  final String message;

  const ESitePlayerError({required this.code, required this.message});

  @override
  String toString() => 'ESitePlayerError(${code.name}): $message';
}

/// Thrown by video resolution so callers can `try`/`catch` around
/// [ESitePlayerController.forVideo] instead of only listening on a stream.
class ESitePlayerException implements Exception {
  final ESitePlayerError error;

  const ESitePlayerException(this.error);

  ESitePlayerErrorCode get code => error.code;
  String get message => error.message;

  @override
  String toString() => 'ESitePlayerException(${code.name}): $message';
}
