/// Sonos encodes shuffle and repeat as a single transport play-mode string.
/// This models the two independent axes and maps to/from those strings.
enum RepeatMode { off, all, one }

class PlayMode {
  const PlayMode({this.shuffle = false, this.repeat = RepeatMode.off});

  final bool shuffle;
  final RepeatMode repeat;

  /// Parses a Sonos `PlayMode` string (e.g. `SHUFFLE`, `REPEAT_ONE`).
  static PlayMode parse(String? raw) {
    switch (raw) {
      case 'SHUFFLE': // shuffle + repeat all
        return const PlayMode(shuffle: true, repeat: RepeatMode.all);
      case 'SHUFFLE_NOREPEAT':
        return const PlayMode(shuffle: true, repeat: RepeatMode.off);
      case 'SHUFFLE_REPEAT_ONE':
        return const PlayMode(shuffle: true, repeat: RepeatMode.one);
      case 'REPEAT_ALL':
        return const PlayMode(shuffle: false, repeat: RepeatMode.all);
      case 'REPEAT_ONE':
        return const PlayMode(shuffle: false, repeat: RepeatMode.one);
      case 'NORMAL':
      default:
        return const PlayMode(shuffle: false, repeat: RepeatMode.off);
    }
  }

  /// The Sonos `PlayMode` string for this combination.
  String toSonos() {
    if (shuffle) {
      switch (repeat) {
        case RepeatMode.all:
          return 'SHUFFLE';
        case RepeatMode.one:
          return 'SHUFFLE_REPEAT_ONE';
        case RepeatMode.off:
          return 'SHUFFLE_NOREPEAT';
      }
    }
    switch (repeat) {
      case RepeatMode.all:
        return 'REPEAT_ALL';
      case RepeatMode.one:
        return 'REPEAT_ONE';
      case RepeatMode.off:
        return 'NORMAL';
    }
  }

  PlayMode withShuffle(bool value) => PlayMode(shuffle: value, repeat: repeat);

  /// Cycles repeat off → all → one → off.
  PlayMode cycleRepeat() {
    final next = switch (repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    return PlayMode(shuffle: shuffle, repeat: next);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayMode && other.shuffle == shuffle && other.repeat == repeat;

  @override
  int get hashCode => Object.hash(shuffle, repeat);
}
