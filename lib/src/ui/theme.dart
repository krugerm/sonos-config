import 'package:flutter/material.dart';

/// The app's visual identity: a dark "instrument panel" for a home-audio
/// system's wiring, carried from the app icon — deep blue-black with a
/// cyan→green accent, and technical data set in monospace.

const _cyan = Color(0xFF37D3DD);
const _green = Color(0xFF28C785);

// Dark surfaces (the default, instrument look).
const _darkBg = Color(0xFF0A1119);
const _darkSurface = Color(0xFF111A26);
const _darkCard = Color(0xFF18232F);
const _darkOutline = Color(0xFF26323F);

// Light surfaces (a clean inversion).
const _lightBg = Color(0xFFEFF2F6);
const _lightSurface = Color(0xFFF6F8FB);
const _lightOutline = Color(0xFFDCE3EC);

/// The cyan→green gradient used on signature elements (accent hairline, hub).
const kAccentGradient = LinearGradient(colors: [_cyan, _green]);

/// Monospace fallbacks — technical data reads as instrument data, not prose.
const List<String> kMonoFallback = [
  'SF Mono',
  'Menlo',
  'Roboto Mono',
  'Consolas',
  'monospace',
];

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? _darkBg : _lightBg;
  final card = dark ? _darkCard : Colors.white;
  final outline = dark ? _darkOutline : _lightOutline;

  final scheme = ColorScheme.fromSeed(
    seedColor: _cyan,
    brightness: brightness,
  ).copyWith(
    primary: dark ? _cyan : const Color(0xFF0E8E99),
    secondary: dark ? _green : const Color(0xFF0F9E68),
    surface: dark ? _darkSurface : _lightSurface,
    error: dark ? const Color(0xFFFF6E63) : const Color(0xFFC13B31),
    outline: outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: outline,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: null,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// A monospace text style for technical data (IPs, UUIDs, firmware, channels).
TextStyle monoStyle(
  BuildContext context, {
  double size = 12.5,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) {
  return TextStyle(
    fontFamilyFallback: kMonoFallback,
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: size,
    height: 1.35,
    letterSpacing: 0,
    fontWeight: weight,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}
