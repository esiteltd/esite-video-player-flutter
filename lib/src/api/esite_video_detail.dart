import 'esite_drm_type.dart';

/// A packaged variant of a video, mirroring the service's
/// `manager.videoRenditionDTO`.
class ESiteVideoRendition {
  final String? id;
  final String? specLabel;
  final String? playbackUrl;

  const ESiteVideoRendition({this.id, this.specLabel, this.playbackUrl});

  factory ESiteVideoRendition.fromJson(Map<String, dynamic> json) {
    return ESiteVideoRendition(
      id: json['id'] as String?,
      specLabel: json['spec_label'] as String?,
      playbackUrl: json['playback_url'] as String?,
    );
  }

  /// Vertical resolution parsed out of a `spec_label` such as `1080p` or
  /// `h264_720p`, used to pick the best rendition. Null when unparseable.
  int? get heightHint {
    final label = specLabel;
    if (label == null) return null;
    final match = RegExp(r'(\d{3,4})\s*p', caseSensitive: false).firstMatch(label);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

/// Video metadata as returned by the video service's `manager.videoDetail`.
///
/// This is the default response contract: a client backend that proxies the
/// eSITE response straight through needs no mapper. Unknown fields are ignored,
/// so a backend may add its own (for example the full-DRM license descriptor).
class ESiteVideoDetail {
  final String id;
  final String? name;
  final String? status;
  final ESiteDrmType drmType;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final List<ESiteVideoRendition> renditions;

  /// The raw decoded body, so callers (and the resolver's license parsing) can
  /// reach backend-specific fields the model does not model explicitly.
  final Map<String, dynamic> raw;

  const ESiteVideoDetail({
    required this.id,
    required this.drmType,
    required this.raw,
    this.name,
    this.status,
    this.playbackUrl,
    this.thumbnailUrl,
    this.renditions = const [],
  });

  factory ESiteVideoDetail.fromJson(Map<String, dynamic> json) {
    final rawRenditions = json['renditions'];
    return ESiteVideoDetail(
      id: (json['id'] as String?) ?? '',
      name: json['name'] as String?,
      status: json['status'] as String?,
      drmType: parseDrmType(json['drm_type'] as String?),
      playbackUrl: json['playback_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      renditions: rawRenditions is List
          ? rawRenditions
                .whereType<Map>()
                .map(
                  (e) => ESiteVideoRendition.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      raw: json,
    );
  }

  /// The service only serves playable renditions once packaging finishes.
  /// A null status is treated as ready — a proxying backend may omit it.
  bool get isReady => status == null || status!.toLowerCase() == 'ready';

  /// Highest-resolution rendition that actually has a packaged URL.
  ESiteVideoRendition? get bestRendition {
    final usable =
        renditions.where((r) => (r.playbackUrl ?? '').isNotEmpty).toList();
    if (usable.isEmpty) return null;
    usable.sort((a, b) => (b.heightHint ?? 0).compareTo(a.heightHint ?? 0));
    return usable.first;
  }
}
