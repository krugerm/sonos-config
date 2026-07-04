/// A playable entry from a browse result — a Sonos favorite or a queue track.
///
/// [uri] is what gets handed to `SetAVTransportURI`; [metadata] is the raw
/// DIDL-Lite the speaker needs alongside it to render the item correctly.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.uri,
    this.metadata,
    this.albumArtUri,
  });

  final String id;
  final String title;

  /// Secondary line — artist/album for a track, or the favorite's description.
  final String? subtitle;

  /// The `res` value used to start playback (absent for containers).
  final String? uri;

  /// DIDL-Lite metadata that must accompany [uri] in `SetAVTransportURI`.
  final String? metadata;

  /// Absolute album-art URL (already resolved against a speaker host).
  final String? albumArtUri;

  bool get isPlayable => uri != null && uri!.isNotEmpty;
}
