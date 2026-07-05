import 'bond_role.dart';

/// What a device supports, derived from its model and current [BondRole].
///
/// The UI enables actions off these flags instead of hard-coding model names.
/// Home-theater EQ (sub/surround tuning) is set on the *coordinator*, so those
/// flags describe the HT primary (e.g. a Beam), not the satellites.
class Capabilities {
  const Capabilities({
    required this.canBondSub,
    required this.canAddSurrounds,
    required this.canStereoPair,
    required this.isHomeTheater,
    required this.hasBassTreble,
    required this.hasLoudness,
    required this.hasNightMode,
    required this.hasSubTuning,
    required this.hasSurroundTuning,
    required this.hasFixedOutput,
    required this.hasTrueplay,
    required this.hasLed,
    required this.hasButtonLock,
  });

  final bool canBondSub;
  final bool canAddSurrounds;
  final bool canStereoPair;

  /// True for a home-theater primary (soundbar / Amp) — owns TV audio and the
  /// sub/surround EQ.
  final bool isHomeTheater;

  final bool hasBassTreble;
  final bool hasLoudness;
  final bool hasNightMode;

  /// Sub level/polarity tuning (set on the coordinator when a Sub is bonded).
  final bool hasSubTuning;

  /// Surround level / height / audio-delay tuning (on the coordinator).
  final bool hasSurroundTuning;

  /// Fixed line-out level (Amp / Port / Connect).
  final bool hasFixedOutput;

  /// Trueplay room calibration on/off.
  final bool hasTrueplay;

  final bool hasLed;
  final bool hasButtonLock;

  factory Capabilities.forModel(String? model, BondRole role) {
    final m = (model ?? '').toLowerCase();
    final known = m.isNotEmpty;
    const htNeedles = ['beam', 'arc', 'ray', 'playbar', 'playbase', 'amp'];
    final isHomeTheater = htNeedles.any(m.contains);
    final isSub = m.contains('sub');
    final hasFixedOutput =
        m.contains('amp') || m.contains('port') || m.contains('connect');
    final isStandardSpeaker = known && !isSub && !isHomeTheater;

    return Capabilities(
      canBondSub: isHomeTheater,
      canAddSurrounds: isHomeTheater,
      canStereoPair: isStandardSpeaker,
      isHomeTheater: isHomeTheater,
      hasBassTreble: known && !isSub,
      hasLoudness: known && !isSub,
      hasNightMode: isHomeTheater,
      hasSubTuning: isHomeTheater,
      hasSurroundTuning: isHomeTheater,
      hasFixedOutput: hasFixedOutput,
      hasTrueplay: known && !isSub,
      hasLed: true,
      hasButtonLock: true,
    );
  }
}
