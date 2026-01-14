
import 'esite_flutter_player_platform_interface.dart';

class EsiteFlutterPlayer {
  Future<String?> getPlatformVersion() {
    return EsiteFlutterPlayerPlatform.instance.getPlatformVersion();
  }
}
