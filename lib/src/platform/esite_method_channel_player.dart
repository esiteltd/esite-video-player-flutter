import 'dart:async';

import 'package:flutter/services.dart';

import '../config/esite_player_config.dart';
import '../errors/esite_player_error.dart';
import '../events/esite_drm_event.dart';
import '../events/esite_player_state.dart';
import 'esite_platform_player.dart';

/// Method-channel implementation shared by Android and iOS.
///
/// Both native players implement the same channel names, method names, state
/// codes and error codes, so one Dart implementation drives both.
class ESiteMethodChannelPlayer implements ESitePlatformPlayer {
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
  Stream<ESitePlayerState> get stateStream =>
      _stateStream ??= _stateChannel.receiveBroadcastStream().map(
        (e) => _byIndex(ESitePlayerState.values, e, ESitePlayerState.idle),
      );

  @override
  Stream<ESiteDrmEvent> get drmStream =>
      _drmStream ??= _drmChannel.receiveBroadcastStream().map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return ESiteDrmEvent(
          type: _byIndex(
            ESiteDrmEventType.values,
            map['type'],
            ESiteDrmEventType.licenseRequested,
          ),
          message: map['message'] as String?,
        );
      });

  @override
  Stream<ESitePlayerError> get errorStream =>
      _errorStream ??= _errorChannel.receiveBroadcastStream().map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return ESitePlayerError(
          code: _byIndex(
            ESitePlayerErrorCode.values,
            map['code'],
            ESitePlayerErrorCode.unknown,
          ),
          message: (map['message'] as String?) ?? 'Unknown player error',
        );
      });

  /// Guards against a native build emitting an ordinal this Dart version does
  /// not know, which would otherwise throw inside the stream and kill it.
  static T _byIndex<T>(List<T> values, Object? raw, T fallback) {
    final index = raw is int ? raw : int.tryParse('$raw');
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  Map<String, dynamic> _configToMap(ESitePlayerConfig config) {
    final map = <String, dynamic>{
      'sourceUrl': config.sourceUrl,
      'streamFormat': config.streamFormat.name,
      'headers': config.headers,
      'autoPlay': config.autoPlay,
      'preventScreenshots': config.preventScreenshots,
      'preventScreenRecording': config.preventScreenRecording,
      // Null for unprotected and Lite DRM sources; native builds the media
      // item without a DRM configuration in that case.
      'drm': config.drm?.toMap(),
    };
    if (config.title != null) {
      map['title'] = config.title;
    }
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
