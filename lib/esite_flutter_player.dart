/// Secure video playback for Flutter, backed by the eSITE Video Service.
///
/// Configure once, then play by video UUID — the plugin discovers whether the
/// video is unprotected, Lite DRM (AES-128 encrypted HLS) or full DRM and
/// prepares the right source.
library;

export 'src/api/esite_drm_type.dart';
export 'src/api/esite_player_sdk.dart' show ESitePlayer, ESitePlayerConfiguration;
export 'src/api/esite_video_detail.dart';
export 'src/api/esite_video_mapper.dart';
export 'src/config/esite_drm_config.dart';
export 'src/config/esite_playback_options.dart';
export 'src/config/esite_player_config.dart';
export 'src/config/esite_stream_format.dart' show ESiteStreamFormat;
export 'src/controller/esite_player_controller.dart';
export 'src/errors/esite_player_error.dart';
export 'src/events/esite_drm_event.dart';
export 'src/events/esite_player_state.dart';
export 'src/resolver/esite_playback_resolver.dart';
export 'src/resolver/esite_resolved_source.dart';
export 'src/view/esite_player_view.dart';
