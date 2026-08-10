/// Content protection systems the player can drive.
///
/// Only relevant for full DRM. Lite DRM (HLS AES-128) needs no scheme — the
/// player fetches the key itself from the playlist's key route.
enum ESiteDrmScheme {
  /// Widevine, via ExoPlayer on Android.
  widevine,

  /// FairPlay Streaming on iOS. **Not implemented.**
  ///
  /// The value exists so full-DRM sources resolve to a scheme rather than
  /// failing to parse, but the iOS player has no `AVContentKeySession` wiring:
  /// it rejects any config carrying a `drm` block with `unsupportedOnPlatform`.
  ///
  /// Implementing it needs the service to package CBCS fMP4 HLS and expose an
  /// SPC/CKC endpoint plus an application certificate — pending on the backend.
  fairplay,
}

class ESiteDrmConfig {
  /// License server endpoint (Widevine license request / FairPlay CKC).
  final String licenseUrl;

  final ESiteDrmScheme scheme;

  /// Extra headers sent with the license request — typically an entitlement
  /// token issued by the licensing server.
  final Map<String, String>? licenseHeaders;

  /// FairPlay application certificate URL. Ignored for Widevine.
  final String? certificateUrl;

  const ESiteDrmConfig({
    required this.licenseUrl,
    required this.scheme,
    this.licenseHeaders,
    this.certificateUrl,
  });

  Map<String, dynamic> toMap() => {
    'licenseUrl': licenseUrl,
    'scheme': scheme.name,
    'licenseHeaders': licenseHeaders,
    'certificateUrl': certificateUrl,
  };
}
