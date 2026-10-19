import 'package:flutter/material.dart';
import '../characters/avatar.dart';
import '../characters/avatar_painter.dart';
import '../characters/buddy.dart';
import '../games/base/game_audio.dart';
import '../models/emotion_state.dart';
import '../services/avatar_service.dart';

/// One emotion as a small WORLD of its own: its atmosphere, its creature,
/// its name. Large touch target. Selection is shown by shape and a check
/// mark, never by colour alone.
class EmotionTile extends StatelessWidget {
  final EmotionState emotion;
  final Animation<double> clock;
  final bool selected;
  final double width;
  final double height;
  final VoidCallback onTap;
  final bool compact;

  const EmotionTile({
    super.key,
    required this.emotion,
    required this.clock,
    required this.onTap,
    required this.width,
    required this.height,
    this.selected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = emotion.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: emotion.displayLabel,
      child: GestureDetector(
        onTap: () {
          GameAudio.tap();
          onTap();
        },
        child: AnimatedScale(
          scale: selected ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 22 : 30),
              border: Border.all(
                color: selected ? const Color(0xFF2B2350) : Colors.white,
                width: selected ? 4 : 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: pal.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 18 : 26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: clock,
                    builder: (_, __) => CustomPaint(
                      painter: EmotionBackdropPainter(emotion, clock.value),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: compact ? 2 : 8),
                          // v43: the child's OWN friend pulls each face,
                          // instead of five unrelated creatures. The
                          // backdrop still carries the atmosphere; only
                          // the figure changed.
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: AnimatedBuilder(
                              animation: AvatarService.instance,
                              builder: (_, __) => AvatarView(
                                AvatarService.instance.active.copyWith(
                                  face: AvatarOptions.faceForEmotionIndex[
                                      emotion.index.clamp(
                                          0,
                                          AvatarOptions
                                                  .faceForEmotionIndex.length -
                                              1)],
                                ),
                                size: 120,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 7),
                        color: Colors.white.withValues(alpha: 0.78),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.check_circle_rounded,
                                    size: 18, color: Color(0xFF2B2350)),
                              ),
                            Text(
                              emotion.displayLabel,
                              style: TextStyle(
                                fontSize: compact ? 12 : 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2B2350),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The five emotion creatures in a wrapping grid. Used on the check-in
/// screen (large) and on "How do you feel now?" (compact), so the child sees
/// the SAME friends both times.
class EmotionPicker extends StatefulWidget {
  final ValueChanged<EmotionState> onSelected;
  final EmotionState? selected;
  final bool compact;

  const EmotionPicker({
    super.key,
    required this.onSelected,
    this.selected,
    this.compact = false,
  });

  @override
  State<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<EmotionPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 360.0;
      final compact = widget.compact;
      final perRow = compact ? 5 : (avail >= 640 ? 5 : (avail >= 420 ? 3 : 2));
      const gap = 10.0;
      final w = ((avail - gap * (perRow - 1)) / perRow).clamp(compact ? 52.0 : 120.0, 220.0).toDouble();
      final h = compact ? w * 1.15 : w * 1.2;
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final e in EmotionState.values)
            EmotionTile(
              emotion: e,
              clock: _clock,
              width: w,
              height: h,
              compact: compact,
              selected: widget.selected == e,
              onTap: () => widget.onSelected(e),
            ),
        ],
      );
    });
  }
}
