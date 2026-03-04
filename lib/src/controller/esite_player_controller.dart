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
  bool _isDisposed = false;

  StreamSubscription<ESitePlayerState>? _stateSubscription;
  StreamSubscription<ESiteDrmEvent>? _drmSubscription;
  StreamSubscription<ESitePlayerError>? _errorSubscription;

  ESitePlayerController(this.config)
    : _platform = Platform.isAndroid
          ? ESiteAndroidPlatformPlayer()
          : throw UnsupportedError('Platform not supported') {
    _stateSubscription = _platform.stateStream.listen(_updateState);
    _drmSubscription = _platform.drmStream.listen(_drmController.add);
    _errorSubscription = _platform.errorStream.listen((error) {
      _updateState(ESitePlayerState.error);
      _errorController.add(error);
    });
  }

  Stream<ESitePlayerState> get stateStream => _stateController.stream;
  Stream<ESiteDrmEvent> get drmStream => _drmController.stream;
  Stream<ESitePlayerError> get errorStream => _errorController.stream;

  Future<void> launchPlayer() async {
    if (_isDisposed) {
      throw StateError('Controller has been disposed');
    }
    _updateState(ESitePlayerState.initializing);
    await _platform.launchPlayer(config);
  }

  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Controller has been disposed');
    }
    _updateState(ESitePlayerState.initializing);
    await _platform.launchPlayer(config);
  }

  Future<void> play() async {
    _checkDisposed();
    return _platform.play();
  }

  Future<void> pause() async {
    _checkDisposed();
    return _platform.pause();
  }

  Future<void> seekTo(Duration position) async {
    _checkDisposed();
    if (position.isNegative) {
      throw ArgumentError('Position cannot be negative');
    }
    return _platform.seekTo(position);
  }

  Future<void> seekForward(Duration offset) async {
    _checkDisposed();
    if (offset.isNegative) {
      throw ArgumentError('Offset cannot be negative');
    }
    return _platform.seekForward(offset);
  }

  Future<void> seekBackward(Duration offset) async {
    _checkDisposed();
    if (offset.isNegative) {
      throw ArgumentError('Offset cannot be negative');
    }
    return _platform.seekBackward(offset);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final clampedSpeed = speed.clamp(0.5, 4.0);
    await _platform.setPlaybackSpeed(clampedSpeed);
  }

  Future<void> setVolume(double volume) async {
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

  Future<bool> hasNext() async {
    _checkDisposed();
    return _platform.hasNext();
  }

  Future<bool> hasPrevious() async {
    _checkDisposed();
    return _platform.hasPrevious();
  }

  Future<void> next() async {
    _checkDisposed();
    return _platform.next();
  }

  Future<void> previous() async {
    _checkDisposed();
    return _platform.previous();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    await _stateSubscription?.cancel();
    await _drmSubscription?.cancel();
    await _errorSubscription?.cancel();

    await _platform.dispose();

    await _stateController.close();
    await _drmController.close();
    await _errorController.close();
  }

  void _checkDisposed() {
    if (_isDisposed) {
      throw StateError('Controller has been disposed');
    }
  }

  void _updateState(ESitePlayerState state) {
    if (_isDisposed) return;
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
