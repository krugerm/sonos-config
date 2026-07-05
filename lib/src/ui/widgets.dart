import 'package:flutter/material.dart';

import '../models/bond_role.dart';
import 'theme.dart';

/// A small uppercase section label — the app's structural device.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 22, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: scheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// A short human label for a bond role, e.g. `SUB`, `SURR L`.
String roleShortLabel(BondRole role) => switch (role) {
      BondRole.coordinator => 'PRIMARY',
      BondRole.sub => 'SUB',
      BondRole.surroundLeft => 'SURR L',
      BondRole.surroundRight => 'SURR R',
      BondRole.stereoLeft => 'STEREO L',
      BondRole.stereoRight => 'STEREO R',
      BondRole.standalone => 'STANDALONE',
    };

String roleLongLabel(BondRole role) => switch (role) {
      BondRole.coordinator => 'Primary',
      BondRole.sub => 'Subwoofer',
      BondRole.surroundLeft => 'Left surround',
      BondRole.surroundRight => 'Right surround',
      BondRole.stereoLeft => 'Left (stereo)',
      BondRole.stereoRight => 'Right (stereo)',
      BondRole.standalone => 'Standalone',
    };

Color _roleColor(BondRole role, ColorScheme scheme) => switch (role) {
      BondRole.coordinator => scheme.primary,
      BondRole.sub => scheme.secondary,
      BondRole.surroundLeft ||
      BondRole.surroundRight ||
      BondRole.stereoLeft ||
      BondRole.stereoRight =>
        scheme.tertiary,
      BondRole.standalone => scheme.onSurface.withValues(alpha: 0.6),
    };

/// The signature element: a tinted pill that makes a device's place in the
/// speaker wiring legible at a glance.
class RoleChip extends StatelessWidget {
  const RoleChip(this.role, {super.key});

  final BondRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _roleColor(role, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        roleShortLabel(role),
        style: TextStyle(
          fontFamilyFallback: kMonoFallback,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

/// A key / mono-value row for the diagnostics panel.
class SpecRow extends StatelessWidget {
  const SpecRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: monoStyle(context, size: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
