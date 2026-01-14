import 'package:flutter/material.dart';
import 'package:esite_flutter_player/esite_flutter_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ESitePlayerController(
      ESitePlayerConfig(
        sourceUrl: 'https://example.com/stream.mpd',
        drm: ESiteDrmConfig(
          licenseUrl: 'https://license.example.com',
          scheme: ESiteDrmScheme.widevine,
        ),
      ),
      platform: throw UnimplementedError(), // wired in Phase 4
    );
  }
}
