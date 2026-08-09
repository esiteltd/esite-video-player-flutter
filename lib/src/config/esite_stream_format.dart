/// Container format of a playback source.
///
/// The native players build an explicit media source from this rather than
/// sniffing the URL suffix — playback URLs are token-authenticated and carry
/// query strings, so they often do not end in `.m3u8` or `.mpd`.
enum ESiteStreamFormat {
  /// HLS master playlist. Used for plain and Lite DRM (AES-128) content.
  hls,

  /// MPEG-DASH manifest. Used for full DRM content.
  dash,

  /// Let the native player infer the format from the URL. Only reliable when
  /// the URL ends in a known extension.
  auto,
}

/// Wire value sent across the method channel.
extension ESiteStreamFormatWire on ESiteStreamFormat {
  String get wireName => name;
}

/// Parses a stream format from a backend string, defaulting to [auto].
ESiteStreamFormat parseStreamFormat(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'hls':
    case 'm3u8':
    case 'application/x-mpegurl':
      return ESiteStreamFormat.hls;
    case 'dash':
    case 'mpd':
    case 'application/dash+xml':
      return ESiteStreamFormat.dash;
    default:
      return ESiteStreamFormat.auto;
  }
}
