/// Sonos encodes shuffle and repeat as a single transport play-mode string.
/// This models the two independent axes and maps to/from those strings.
enum SonosRepeatMode { off, all, one }

class PlayMode {
  const PlayMode({this.shuffle = false, this.repeat = SonosRepeatMode.off});

  final bool shuffle;
  final SonosRepeatMode repeat;

  /// Parses a Sonos `PlayMode` string (e.g. `SHUFFLE`, `REPEAT_ONE`).
  static PlayMode parse(String? raw) {
    switch (raw) {
      case 'SHUFFLE': // shuffle + repeat all
        return const PlayMode(shuffle: true, repeat: SonosRepeatMode.all);
      case 'SHUFFLE_NOREPEAT':
        return const PlayMode(shuffle: true, repeat: SonosRepeatMode.off);
      case 'SHUFFLE_REPEAT_ONE':
        return const PlayMode(shuffle: true, repeat: SonosRepeatMode.one);
      case 'REPEAT_ALL':
        return const PlayMode(shuffle: false, repeat: SonosRepeatMode.all);
      case 'REPEAT_ONE':
        return const PlayMode(shuffle: false, repeat: SonosRepeatMode.one);
      case 'NORMAL':
      default:
        return const PlayMode(shuffle: false, repeat: SonosRepeatMode.off);
    }
  }

  /// The Sonos `PlayMode` string for this combination.
  String toSonos() {
    if (shuffle) {
      switch (repeat) {
        case SonosRepeatMode.all:
          return 'SHUFFLE';
        case SonosRepeatMode.one:
          return 'SHUFFLE_REPEAT_ONE';
        case SonosRepeatMode.off:
          return 'SHUFFLE_NOREPEAT';
      }
    }
    switch (repeat) {
      case SonosRepeatMode.all:
        return 'REPEAT_ALL';
      case SonosRepeatMode.one:
        return 'REPEAT_ONE';
      case SonosRepeatMode.off:
        return 'NORMAL';
    }
  }

  PlayMode withShuffle(bool value) => PlayMode(shuffle: value, repeat: repeat);

  /// Cycles repeat off → all → one → off.
  PlayMode cycleRepeat() {
    final next = switch (repeat) {
      SonosRepeatMode.off => SonosRepeatMode.all,
      SonosRepeatMode.all => SonosRepeatMode.one,
      SonosRepeatMode.one => SonosRepeatMode.off,
    };
    return PlayMode(shuffle: shuffle, repeat: next);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayMode && other.shuffle == shuffle && other.repeat == repeat;

  @override
  int get hashCode => Object.hash(shuffle, repeat);
}
