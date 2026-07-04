/// High-level transport state of a group's coordinator.
enum TransportState {
  playing,
  paused,
  stopped,
  transitioning,
  unknown;

  static TransportState parse(String? raw) {
    switch (raw) {
      case 'PLAYING':
        return TransportState.playing;
      case 'PAUSED_PLAYBACK':
        return TransportState.paused;
      case 'STOPPED':
        return TransportState.stopped;
      case 'TRANSITIONING':
        return TransportState.transitioning;
      default:
        return TransportState.unknown;
    }
  }

  bool get isPlaying => this == TransportState.playing;
}

/// A snapshot of what a group is currently doing: transport, track metadata,
/// position and volume. Everything is nullable/defaulted so a partial poll
/// never throws.
class PlaybackState {
  const PlaybackState({
    this.transport = TransportState.unknown,
    this.title,
    this.artist,
    this.album,
    this.albumArtUri,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 0,
    this.muted = false,
  });

  final TransportState transport;
  final String? title;
  final String? artist;
  final String? album;

  /// Absolute URL to album art, already resolved against the speaker host.
  final String? albumArtUri;

  final Duration position;
  final Duration duration;

  /// Group volume, 0–100.
  final int volume;
  final bool muted;

  bool get hasTrack => (title != null && title!.isNotEmpty);

  double get progress {
    if (duration.inSeconds <= 0) return 0;
    return (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    TransportState? transport,
    String? title,
    String? artist,
    String? album,
    String? albumArtUri,
    Duration? position,
    Duration? duration,
    int? volume,
    bool? muted,
  }) {
    return PlaybackState(
      transport: transport ?? this.transport,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUri: albumArtUri ?? this.albumArtUri,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      muted: muted ?? this.muted,
    );
  }
}
