import 'package:flutter_test/flutter_test.dart';
import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:esite_flutter_player/esite_flutter_player_platform_interface.dart';
import 'package:esite_flutter_player/esite_flutter_player_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEsiteFlutterPlayerPlatform
    with MockPlatformInterfaceMixin
    implements EsiteFlutterPlayerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final EsiteFlutterPlayerPlatform initialPlatform = EsiteFlutterPlayerPlatform.instance;

  test('$MethodChannelEsiteFlutterPlayer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEsiteFlutterPlayer>());
  });

  test('getPlatformVersion', () async {
    EsiteFlutterPlayer esiteFlutterPlayerPlugin = EsiteFlutterPlayer();
    MockEsiteFlutterPlayerPlatform fakePlatform = MockEsiteFlutterPlayerPlatform();
    EsiteFlutterPlayerPlatform.instance = fakePlatform;

    expect(await esiteFlutterPlayerPlugin.getPlatformVersion(), '42');
  });
}
