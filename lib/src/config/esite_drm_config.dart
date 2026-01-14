enum ESiteDrmScheme {
  widevine,
  playready,
  fairplay, // future
}

class ESiteDrmConfig {
  final String licenseUrl;
  final ESiteDrmScheme scheme;
  final Map<String, String>? licenseHeaders;

  const ESiteDrmConfig({
    required this.licenseUrl,
    required this.scheme,
    this.licenseHeaders,
  });
}
