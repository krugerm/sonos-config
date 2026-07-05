import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/ui/product_glyph.dart';

void main() {
  group('productForm', () {
    test('home-theater bars are soundbars', () {
      for (final m in [
        'Sonos Beam',
        'Sonos Arc',
        'Sonos Ray',
        'Sonos Playbar'
      ]) {
        expect(productForm(m), ProductForm.soundbar, reason: m);
      }
    });

    test('a Sub is a sub', () {
      expect(productForm('Sonos Sub'), ProductForm.sub);
      expect(productForm('Sonos Sub Mini'), ProductForm.sub);
    });

    test('portables', () {
      expect(productForm('Sonos Move'), ProductForm.portable);
      expect(productForm('Sonos Roam'), ProductForm.portable);
    });

    test('amp / connect are amp form', () {
      expect(productForm('Sonos Amp'), ProductForm.amp);
      expect(productForm('Sonos Port'), ProductForm.amp);
    });

    test('standard speakers and unknown default to bookshelf', () {
      expect(productForm('Sonos One SL'), ProductForm.bookshelf);
      expect(productForm('Sonos Era 100'), ProductForm.bookshelf);
      expect(productForm('Sonos Five'), ProductForm.bookshelf);
      expect(productForm(null), ProductForm.bookshelf);
    });
  });
}
