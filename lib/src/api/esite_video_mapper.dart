import '../resolver/esite_resolved_source.dart';

/// Maps a client backend's playback response onto a playable source.
///
/// Supply one to [ESitePlayer.configure] only when the backend does **not**
/// return the eSITE `videoDetail` shape. A backend that proxies the eSITE
/// response straight through needs no mapper — the built-in parser handles it.
typedef ESiteVideoMapper =
    ESiteResolvedSource Function(Map<String, dynamic> json);

/// Supplies the access token used between the app and its own backend.
///
/// Called per request rather than read once, so a refreshed token is picked up
/// without reconfiguring the plugin. Return null to send no auth header.
typedef ESiteTokenProvider = Future<String?> Function();
