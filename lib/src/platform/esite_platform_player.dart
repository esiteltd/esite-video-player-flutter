import '../config/esite_player_config.dart';

abstract class ESitePlatformPlayer {
  Future<void> initialize(ESitePlayerConfig config);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> dispose();
}
