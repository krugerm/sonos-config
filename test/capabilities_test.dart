import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/models/bond_role.dart';
import 'package:personal_sonos/src/models/capabilities.dart';

void main() {
  group('Capabilities.forModel', () {
    test('Sonos Beam is a home-theater primary', () {
      final c = Capabilities.forModel('Sonos Beam', BondRole.coordinator);
      expect(c.canBondSub, isTrue);
      expect(c.canAddSurrounds, isTrue);
      expect(c.hasNightMode, isTrue);
      expect(c.canStereoPair, isFalse);
      expect(c.hasBassTreble, isTrue);
      expect(c.hasLed, isTrue);
    });

    test('Sonos One SL is a stereo-pairable standard speaker', () {
      final c = Capabilities.forModel('Sonos One SL', BondRole.surroundLeft);
      expect(c.canStereoPair, isTrue);
      expect(c.canBondSub, isFalse);
      expect(c.hasNightMode, isFalse);
      expect(c.hasBassTreble, isTrue);
      expect(c.hasLoudness, isTrue);
    });

    test('Sonos Sub has no speaker EQ but has an LED', () {
      final c = Capabilities.forModel('Sonos Sub', BondRole.sub);
      expect(c.hasBassTreble, isFalse);
      expect(c.hasLoudness, isFalse);
      expect(c.canStereoPair, isFalse);
      expect(c.canBondSub, isFalse);
      expect(c.hasLed, isTrue);
      expect(c.hasButtonLock, isTrue);
    });

    test('unknown model is conservative but keeps LED/button controls', () {
      final c = Capabilities.forModel(null, BondRole.standalone);
      expect(c.canBondSub, isFalse);
      expect(c.canStereoPair, isFalse);
      expect(c.hasBassTreble, isFalse);
      expect(c.hasLed, isTrue);
      expect(c.hasButtonLock, isTrue);
    });
  });
}
