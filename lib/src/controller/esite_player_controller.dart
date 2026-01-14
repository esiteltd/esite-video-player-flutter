import 'dart:async';

import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';
import '../platform/esite_platform_player.dart';

class ESitePlayerController {
  final ESitePlayerConfig config;
  final ESitePlatformPlayer _platform;
  ESitePlayerState get currentState => _state;

  final _stateController = StreamController<ESitePlayerState>.broadcast();
  final _drmController = StreamController<ESiteDrmEvent>.broadcast();
  final _errorController = StreamController<ESitePlayerError>.broadcast();

  ESitePlayerState _state = ESitePlayerState.idle;

  ESitePlayerController(this.config, {required ESitePlatformPlayer platform})
    : _platform = platform;

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

  Future<void> setPlaybackSpeed(double speed) async =>
      _platform.setPlaybackSpeed(speed);

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
