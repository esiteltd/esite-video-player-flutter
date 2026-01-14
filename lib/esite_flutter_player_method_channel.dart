import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'esite_flutter_player_platform_interface.dart';

/// An implementation of [EsiteFlutterPlayerPlatform] that uses method channels.
class MethodChannelEsiteFlutterPlayer extends EsiteFlutterPlayerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('esite_flutter_player');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
