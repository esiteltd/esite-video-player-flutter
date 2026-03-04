import 'dart:async';

import 'package:flutter/services.dart';

import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';
import 'esite_platform_player.dart';

class ESiteAndroidPlatformPlayer implements ESitePlatformPlayer {
  static const _methodChannel = MethodChannel('esite_flutter_player/methods');

  static const _stateChannel = EventChannel(
    'esite_flutter_player/events/state',
  );
  static const _drmChannel = EventChannel('esite_flutter_player/events/drm');
  static const _errorChannel = EventChannel(
    'esite_flutter_player/events/error',
  );

  Stream<ESitePlayerState>? _stateStream;
  Stream<ESiteDrmEvent>? _drmStream;
  Stream<ESitePlayerError>? _errorStream;

  @override
  Stream<ESitePlayerState> get stateStream => _stateStream ??= _stateChannel
      .receiveBroadcastStream()
      .map((e) => ESitePlayerState.values[e]);

  @override
  Stream<ESiteDrmEvent> get drmStream =>
      _drmStream ??= _drmChannel.receiveBroadcastStream().map(
        (e) => ESiteDrmEvent(
          type: ESiteDrmEventType.values[e['type']],
          message: e['message'],
        ),
      );

  @override
  Stream<ESitePlayerError> get errorStream =>
      _errorStream ??= _errorChannel.receiveBroadcastStream().map(
        (e) => ESitePlayerError(
          code: ESitePlayerErrorCode.values[e['code']],
          message: e['message'],
        ),
      );

  Map<String, dynamic> _configToMap(ESitePlayerConfig config) {
    final map = <String, dynamic>{
      'sourceUrl': config.sourceUrl,
      'headers': config.headers,
      'autoPlay': config.autoPlay,
      'preventScreenshots': config.preventScreenshots,
      'preventScreenRecording': config.preventScreenRecording,
      'drm': {
        'licenseUrl': config.drm.licenseUrl,
        'scheme': config.drm.scheme.name,
        'licenseHeaders': config.drm.licenseHeaders,
      },
    };
    if (config.primaryColor != null) {
      map['primaryColor'] = config.primaryColor!.toARGB32();
    }
    if (config.secondaryColor != null) {
      map['secondaryColor'] = config.secondaryColor!.toARGB32();
    }
    return map;
  }

  @override
  Future<void> launchPlayer(ESitePlayerConfig config) {
    return _methodChannel.invokeMethod('launchPlayer', _configToMap(config));
  }

  @override
  Future<void> initialize(ESitePlayerConfig config) {
    return _methodChannel.invokeMethod('initialize', _configToMap(config));
  }

  @override
  Future<void> play() => _methodChannel.invokeMethod('play');

  @override
  Future<void> pause() => _methodChannel.invokeMethod('pause');

  @override
  Future<void> seekTo(Duration position) => _methodChannel.invokeMethod(
    'seekTo',
    {'positionMs': position.inMilliseconds},
  );

  @override
  Future<void> setPlaybackSpeed(double speed) =>
      _methodChannel.invokeMethod('setPlaybackSpeed', {'speed': speed});

  @override
  Future<void> seekForward(Duration offset) => _methodChannel.invokeMethod(
    'seekForward',
    {'offsetMs': offset.inMilliseconds},
  );

  @override
  Future<void> seekBackward(Duration offset) => _methodChannel.invokeMethod(
    'seekBackward',
    {'offsetMs': offset.inMilliseconds},
  );

  @override
  Future<void> setVolume(double volume) =>
      _methodChannel.invokeMethod('setVolume', {'volume': volume});

  @override
  Future<void> setMuted(bool muted) =>
      _methodChannel.invokeMethod('setMuted', {'muted': muted});

  @override
  Future<bool> isMuted() async {
    final result = await _methodChannel.invokeMethod<bool>('isMuted');
    return result ?? false;
  }

  @override
  Future<double> getVolume() async {
    final result = await _methodChannel.invokeMethod<double>('getVolume');
    return result ?? 1.0;
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableVideoTracks() async {
    final result = await _methodChannel.invokeMethod<List<dynamic>>(
      'getAvailableVideoTracks',
    );
    return (result ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> setVideoTrack(String trackId) =>
      _methodChannel.invokeMethod('setVideoTrack', {'trackId': trackId});

  @override
  Future<void> setSubtitleEnabled(bool enabled) =>
      _methodChannel.invokeMethod('setSubtitleEnabled', {'enabled': enabled});

  @override
  Future<bool> isSubtitleEnabled() async {
    final result = await _methodChannel.invokeMethod<bool>('isSubtitleEnabled');
    return result ?? false;
  }

  @override
  Future<bool> hasNext() async {
    final result = await _methodChannel.invokeMethod<bool>('hasNext');
    return result ?? false;
  }

  @override
  Future<bool> hasPrevious() async {
    final result = await _methodChannel.invokeMethod<bool>('hasPrevious');
    return result ?? false;
  }

  @override
  Future<void> next() => _methodChannel.invokeMethod('next');

  @override
  Future<void> previous() => _methodChannel.invokeMethod('previous');

  @override
  Future<void> dispose() => _methodChannel.invokeMethod('dispose');
}
