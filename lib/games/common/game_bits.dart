import 'package:flutter/material.dart';
import '../support/support_engine.dart';

/// Small pieces shared by the challenge games.

/// A glowing ring used by the "visual cue" support stage. Put it around the
/// target / safe lane / correct button while [show] is true.
class CueRing extends StatelessWidget {
  final bool show;
  final double size;
  final Widget? child;
  const CueRing({super.key, required this.show, required this.size, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: show
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFC107), width: 5),
              boxShadow: const [
                BoxShadow(color: Color(0x88FFC107), blurRadius: 14)
              ],
            )
          : null,
      child: Center(child: child),
    );
  }
}

/// True from the visual-cue stage until the child succeeds again.
bool cueActive(SupportStage s) =>
    s == SupportStage.visualCue ||
    s == SupportStage.smallHint ||
    s == SupportStage.demonstration;

/// A rounded banner that states the current rule in words and icons.
class RuleChip extends StatelessWidget {
  final String text;
  final Color color;
  final List<Widget> icons;
  const RuleChip(
      {super.key, required this.text, required this.color, this.icons = const []});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ...icons,
          if (icons.isNotEmpty) const SizedBox(width: 8),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}
