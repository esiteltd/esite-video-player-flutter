import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esite_flutter_player/esite_flutter_player_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelEsiteFlutterPlayer platform = MethodChannelEsiteFlutterPlayer();
  const MethodChannel channel = MethodChannel('esite_flutter_player');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
