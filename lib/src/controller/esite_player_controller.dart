import 'dart:async';
import 'dart:io';

import '../api/esite_drm_type.dart';
import '../api/esite_player_sdk.dart';
import '../config/esite_drm_config.dart';
import '../config/esite_playback_options.dart';
import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';
import '../platform/esite_method_channel_player.dart';
import '../platform/esite_platform_player.dart';
import '../resolver/esite_resolved_source.dart';

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

  ESitePlayerController(this.config) : _platform = _createPlatform() {
    _stateSubscription = _platform.stateStream.listen(_updateState);
    _drmSubscription = _platform.drmStream.listen(_drmController.add);
    _errorSubscription = _platform.errorStream.listen((error) {
      _updateState(ESitePlayerState.error);
      _errorController.add(error);
    });
  }

  static ESitePlatformPlayer _createPlatform() {
    if (Platform.isAndroid || Platform.isIOS) {
      return ESiteMethodChannelPlayer();
    }
    throw UnsupportedError(
      'esite_flutter_player supports Android and iOS only '
      '(current: ${Platform.operatingSystem}).',
    );
  }

  /// Builds a controller for a video UUID.
  ///
  /// Asks the configured client backend what the video is, works out whether
  /// it is unprotected, Lite DRM or full DRM, and prepares the right source —
  /// the caller never handles manifests or license servers.
  ///
  /// Requires [ESitePlayer.configure] to have been called. Throws
  /// [ESitePlayerException] when the lookup fails, the video is not ready, or
  /// its protection is unsupported on the current platform.
  static Future<ESitePlayerController> forVideo(
    String videoId, {
    ESitePlaybackOptions options = const ESitePlaybackOptions(),
  }) async {
    if (videoId.trim().isEmpty) {
      throw ESitePlayerException(
        const ESitePlayerError(
          code: ESitePlayerErrorCode.configurationError,
          message: 'videoId must not be empty.',
        ),
      );
    }

    final source = await ESitePlayer.configuration.resolve(
      videoId,
      scheme: _platformScheme(),
    );
    _assertPlayable(source, videoId);

    return ESitePlayerController(
      ESitePlayerConfig.fromResolved(source, options),
    );
  }

  static ESiteDrmScheme _platformScheme() =>
      Platform.isIOS ? ESiteDrmScheme.fairplay : ESiteDrmScheme.widevine;

  static void _assertPlayable(ESiteResolvedSource source, String videoId) {
    // Full DRM is DASH + Widevine. AVPlayer plays neither, and the service
    // does not package FairPlay HLS yet, so fail with an explanation rather
    // than a black screen. Lite DRM and plain HLS play fine on both platforms.
    if (source.drmType == ESiteDrmType.full && Platform.isIOS) {
      throw ESitePlayerException(
        ESitePlayerError(
          code: ESitePlayerErrorCode.unsupportedOnPlatform,
          message:
              'Video $videoId uses full DRM, which is not playable on iOS '
              'yet: it is packaged as DASH + Widevine, and FairPlay HLS '
              'packaging is not available from the video service.',
        ),
      );
    }
  }

  Stream<ESitePlayerState> get stateStream => _stateController.stream;
  Stream<ESiteDrmEvent> get drmStream => _drmController.stream;
  Stream<ESitePlayerError> get errorStream => _errorController.stream;

  Future<void> launchPlayer() async {
    _checkDisposed();
    _updateState(ESitePlayerState.initializing);
    await _platform.launchPlayer(config);
  }

  Future<void> initialize() async {
    _checkDisposed();
    _updateState(ESitePlayerState.initializing);
    await _platform.initialize(config);
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
    _checkDisposed();
    await _platform.setPlaybackSpeed(speed.clamp(0.5, 4.0));
  }

  Future<void> setVolume(double volume) async {
    _checkDisposed();
    await _platform.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setMuted(bool muted) async {
    _checkDisposed();
    return _platform.setMuted(muted);
  }

  Future<bool> isMuted() async {
    _checkDisposed();
    return _platform.isMuted();
  }

  Future<double> getVolume() async {
    _checkDisposed();
    return _platform.getVolume();
  }

  Future<List<Map<String, dynamic>>> getAvailableVideoTracks() async {
    _checkDisposed();
    return _platform.getAvailableVideoTracks();
  }

  Future<void> setVideoTrack(String trackId) async {
    _checkDisposed();
    return _platform.setVideoTrack(trackId);
  }

  Future<void> setSubtitleEnabled(bool enabled) async {
    _checkDisposed();
    return _platform.setSubtitleEnabled(enabled);
  }

  Future<bool> isSubtitleEnabled() async {
    _checkDisposed();
    return _platform.isSubtitleEnabled();
  }

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
