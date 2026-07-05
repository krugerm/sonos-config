import 'package:flutter/material.dart';

/// Physical form factor, inferred from a Sonos model name. Used to draw a
/// schematic product silhouette.
///
/// Note: the local UPnP API does not reliably expose a speaker's *finish*
/// (black/white) — `variant` is an ambiguous hardware-revision field — so
/// glyphs are drawn as monochrome line art in the accent colour rather than a
/// colour-matched product photo.
enum ProductForm { soundbar, bookshelf, sub, portable, amp }

ProductForm productForm(String? model) {
  final m = (model ?? '').toLowerCase();
  if (m.contains('beam') ||
      m.contains('arc') ||
      m.contains('ray') ||
      m.contains('playbar') ||
      m.contains('playbase')) {
    return ProductForm.soundbar;
  }
  if (m.contains('sub')) return ProductForm.sub;
  if (m.contains('move') || m.contains('roam')) return ProductForm.portable;
  if (m.contains('amp') ||
      m.contains('port') ||
      m.contains('connect') ||
      m.contains('boost') ||
      m.contains('bridge')) {
    return ProductForm.amp;
  }
  return ProductForm.bookshelf; // One, One SL, Five, Era, Play:x, …
}

/// A small schematic line-art silhouette of a Sonos product, by form factor.
class ProductGlyph extends StatelessWidget {
  const ProductGlyph(this.model, {super.key, this.size = 26, this.color});

  final String? model;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(productForm(model), c),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.form, this.color);

  final ProductForm form;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;

    RRect box(double l, double t, double r, double b, double rad) =>
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * l, h * t, w * (r - l), h * (b - t)),
            Radius.circular(w * rad));

    switch (form) {
      case ProductForm.soundbar:
        canvas.drawRRect(box(0.05, 0.36, 0.95, 0.64, 0.09), line);
        for (final x in [0.30, 0.50, 0.70]) {
          canvas.drawLine(
              Offset(w * x, h * 0.44), Offset(w * x, h * 0.56), line);
        }
      case ProductForm.bookshelf:
        canvas.drawRRect(box(0.26, 0.10, 0.74, 0.90, 0.12), line);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.11, line);
      case ProductForm.sub:
        canvas.drawRRect(box(0.15, 0.10, 0.85, 0.90, 0.16), line);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.16, line);
      case ProductForm.portable:
        canvas.drawRRect(box(0.32, 0.10, 0.68, 0.90, 0.20), line);
        canvas.drawCircle(Offset(w * 0.5, h * 0.36), w * 0.08, line);
      case ProductForm.amp:
        canvas.drawRRect(box(0.05, 0.30, 0.95, 0.70, 0.08), line);
        canvas.drawCircle(Offset(w * 0.80, h * 0.5), w * 0.05, dot);
        canvas.drawLine(Offset(w * 0.14, h * 0.5), Offset(w * 0.5, h * 0.5),
            line..strokeWidth = w * 0.05);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.form != form || old.color != color;
}
