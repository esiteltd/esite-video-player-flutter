import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'esite_flutter_player_method_channel.dart';

abstract class EsiteFlutterPlayerPlatform extends PlatformInterface {
  /// Constructs a EsiteFlutterPlayerPlatform.
  EsiteFlutterPlayerPlatform() : super(token: _token);

  static final Object _token = Object();

  static EsiteFlutterPlayerPlatform _instance = MethodChannelEsiteFlutterPlayer();

  /// The default instance of [EsiteFlutterPlayerPlatform] to use.
  ///
  /// Defaults to [MethodChannelEsiteFlutterPlayer].
  static EsiteFlutterPlayerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EsiteFlutterPlayerPlatform] when
  /// they register themselves.
  static set instance(EsiteFlutterPlayerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
