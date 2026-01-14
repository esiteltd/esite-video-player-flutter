enum ESitePlayerErrorCode {
  invalidSource,
  drmFailure,
  networkError,
  playbackError,
  unknown,
}

class ESitePlayerError {
  final ESitePlayerErrorCode code;
  final String message;

  const ESitePlayerError({required this.code, required this.message});
}
