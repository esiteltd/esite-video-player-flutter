/// The protection applied to a video, as reported by the video service's
/// `drm_type` field.
enum ESiteDrmType {
  /// Unencrypted content. Plays as plain HLS.
  none,

  /// "Lite DRM" — encryption only, delivered as HLS with AES-128 encrypted
  /// segments. The key is fetched by the player itself from the key route
  /// embedded in the token-authenticated playlist, so no DRM session,
  /// license server or extra headers are involved.
  lite,

  /// Full DRM — DASH packaged with a license server (Widevine on Android,
  /// FairPlay on iOS once the service packages it).
  full,
}

/// Parses `drm_type` case-insensitively.
///
/// The service's OpenAPI spec types `drm_type` as a bare string without an
/// enum, so unrecognised values fall back to [ESiteDrmType.none] — the safe
/// choice, since a plain source either plays or fails loudly, whereas guessing
/// [ESiteDrmType.full] would fail every time for want of a license server.
ESiteDrmType parseDrmType(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'lite':
    case 'lite_drm':
    case 'lite-drm':
      return ESiteDrmType.lite;
    case 'full':
    case 'full_drm':
    case 'full-drm':
    case 'widevine':
    case 'drm':
      return ESiteDrmType.full;
    default:
      return ESiteDrmType.none;
  }
}
