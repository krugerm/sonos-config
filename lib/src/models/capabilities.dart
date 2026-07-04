import 'bond_role.dart';

/// What a device supports, derived from its model and current [BondRole].
///
/// The UI enables actions off these flags instead of hard-coding model names.
class Capabilities {
  const Capabilities({
    required this.canBondSub,
    required this.canAddSurrounds,
    required this.canStereoPair,
    required this.hasBassTreble,
    required this.hasLoudness,
    required this.hasNightMode,
    required this.hasLed,
    required this.hasButtonLock,
  });

  final bool canBondSub;
  final bool canAddSurrounds;
  final bool canStereoPair;
  final bool hasBassTreble;
  final bool hasLoudness;
  final bool hasNightMode;
  final bool hasLed;
  final bool hasButtonLock;

  /// Derives capabilities from a Sonos [model] string (e.g. `Sonos Beam`) and
  /// the device's [role]. [model] may be null before device enrichment, in
  /// which case only the universally-safe controls (LED, button lock) are on.
  factory Capabilities.forModel(String? model, BondRole role) {
    final m = (model ?? '').toLowerCase();
    final known = m.isNotEmpty;
    const htNeedles = ['beam', 'arc', 'ray', 'playbar', 'playbase', 'amp'];
    final isHomeTheater = htNeedles.any(m.contains);
    final isSub = m.contains('sub');
    final isStandardSpeaker = known && !isSub && !isHomeTheater;

    return Capabilities(
      canBondSub: isHomeTheater,
      canAddSurrounds: isHomeTheater,
      canStereoPair: isStandardSpeaker,
      hasBassTreble: known && !isSub,
      hasLoudness: known && !isSub,
      hasNightMode: isHomeTheater,
      hasLed: true,
      hasButtonLock: true,
    );
  }
}
