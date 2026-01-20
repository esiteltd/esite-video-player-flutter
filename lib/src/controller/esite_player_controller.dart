import 'dart:async';
import 'dart:io';

import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';
import '../platform/esite_android_platform_player.dart';
import '../platform/esite_platform_player.dart';

class ESitePlayerController {
  final ESitePlayerConfig config;
  final ESitePlatformPlayer _platform;
  ESitePlayerState get currentState => _state;

  final _stateController = StreamController<ESitePlayerState>.broadcast();
  final _drmController = StreamController<ESiteDrmEvent>.broadcast();
  final _errorController = StreamController<ESitePlayerError>.broadcast();

  ESitePlayerState _state = ESitePlayerState.idle;

  ESitePlayerController(this.config)
    : _platform = Platform.isAndroid
          ? ESiteAndroidPlatformPlayer()
          : throw UnsupportedError('Platform not supported') {
    _platform.stateStream.listen(_updateState);
    _platform.drmStream.listen(_drmController.add);
    _platform.errorStream.listen((error) {
      _updateState(ESitePlayerState.error);
      _errorController.add(error);
    });
  }

  Stream<ESitePlayerState> get stateStream => _stateController.stream;
  Stream<ESiteDrmEvent> get drmStream => _drmController.stream;
  Stream<ESitePlayerError> get errorStream => _errorController.stream;

  Future<void> initialize() async {
    _updateState(ESitePlayerState.initializing);
    await _platform.initialize(config);
  }

  Future<void> play() async => _platform.play();
  Future<void> pause() async => _platform.pause();
  Future<void> seekTo(Duration position) async => _platform.seekTo(position);
  Future<void> seekForward(Duration offset) async =>
      _platform.seekForward(offset);
  Future<void> seekBackward(Duration offset) async =>
      _platform.seekBackward(offset);

  Future<void> setPlaybackSpeed(double speed) async {
    // Validate speed range: 0.5x to 4x
    final clampedSpeed = speed.clamp(0.5, 4.0);
    await _platform.setPlaybackSpeed(clampedSpeed);
  }

  Future<void> setVolume(double volume) async {
    // Validate volume range: 0.0 to 1.0
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _platform.setVolume(clampedVolume);
  }

  Future<void> setMuted(bool muted) async => _platform.setMuted(muted);
  Future<bool> isMuted() async => _platform.isMuted();
  Future<double> getVolume() async => _platform.getVolume();

  Future<List<Map<String, dynamic>>> getAvailableVideoTracks() async =>
      _platform.getAvailableVideoTracks();
  Future<void> setVideoTrack(String trackId) async =>
      _platform.setVideoTrack(trackId);

  Future<void> setSubtitleEnabled(bool enabled) async =>
      _platform.setSubtitleEnabled(enabled);
  Future<bool> isSubtitleEnabled() async => _platform.isSubtitleEnabled();

  Future<bool> hasNext() async => _platform.hasNext();
  Future<bool> hasPrevious() async => _platform.hasPrevious();
  Future<void> next() async => _platform.next();
  Future<void> previous() async => _platform.previous();

  Future<void> dispose() async {
    await _platform.dispose();
    await _stateController.close();
    await _drmController.close();
    await _errorController.close();
  }

  void _updateState(ESitePlayerState state) {
    _state = state;
    _stateController.add(state);
  }
}
