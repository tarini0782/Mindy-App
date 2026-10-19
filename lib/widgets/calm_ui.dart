import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small building blocks for the calm app shell (not used inside games).

/// A soft white card with an optional tint and a gentle border.
class CalmCard extends StatelessWidget {
  final Widget child;
  final Color? tint;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  const CalmCard({
    super.key,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: tint ?? Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: CalmColors.cardBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  final String? sub;
  const SectionLabel(this.text, {super.key, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: CalmColors.ink)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub!,
                style: const TextStyle(fontSize: 13.5, color: CalmColors.inkSoft)),
          ),
      ]),
    );
  }
}

/// A small coloured pill, e.g. "Do now" or "Looks good".
class PillBadge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  const PillBadge(this.text,
      {super.key, required this.bg, required this.fg, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
      ]),
    );
  }
}

/// Soft colour for an average feeling (1 scared .. 5 happy).
Color feelingColor(double mean) {
  const stops = [
    Color(0xFFF4A3B0), // scared
    Color(0xFF9AA3F0), // sad
    Color(0xFFF2D7A0), // okay
    Color(0xFF8FD9C4), // calm
    Color(0xFFFFC95C), // happy
  ];
  final i = (mean.round().clamp(1, 5)) - 1;
  return stops[i];
}
