import 'dart:async';

import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';

abstract class ESitePlatformPlayer {
  Stream<ESitePlayerState> get stateStream;
  Stream<ESiteDrmEvent> get drmStream;
  Stream<ESitePlayerError> get errorStream;

  Future<void> initialize(ESitePlayerConfig config);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> seekForward(Duration offset);
  Future<void> seekBackward(Duration offset);
  Future<void> setPlaybackSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> setMuted(bool muted);
  Future<bool> isMuted();
  Future<double> getVolume();
  Future<List<Map<String, dynamic>>> getAvailableVideoTracks();
  Future<void> setVideoTrack(String trackId);
  Future<void> setSubtitleEnabled(bool enabled);
  Future<bool> isSubtitleEnabled();
  Future<bool> hasNext();
  Future<bool> hasPrevious();
  Future<void> next();
  Future<void> previous();
  Future<void> dispose();
}
