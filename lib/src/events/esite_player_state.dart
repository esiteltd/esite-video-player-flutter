/// Playback states reported by the native players.
///
/// The ordinal is the wire format sent over the state EventChannel, so
/// **never reorder or remove** these — only append.
enum ESitePlayerState {
  idle,
  initializing,
  buffering,
  ready,
  playing,
  paused,

  /// Playback reached the end of the media.
  completed,

  error,

  /// The native player was dismissed — by the user, or programmatically.
  ///
  /// Distinct from [completed], which previously doubled as "player closed"
  /// and made a finished video indistinguishable from an abandoned one.
  closed,
}
