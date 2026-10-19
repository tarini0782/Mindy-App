import 'dart:math';
import 'package:flutter/material.dart';
import '../art/sprites.dart';
import '../characters/avatar.dart';
import '../characters/avatar_painter.dart';
import '../characters/mindy_character.dart';
import '../games/engine/adaptive_game_engine.dart';
import '../games/models/game_type.dart';
import '../services/account_service.dart';
import '../services/avatar_service.dart';
import '../services/journey_controller.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import 'calm_corner_screen.dart';
import 'character_creator_screen.dart';
import 'game_library_screen.dart';

/// HOME -- the start of the child's adventure.
///
/// v39 rebuild. What this screen used to be: a rainbow-gradient dashboard
/// with the Kara mascot at the top, two bright cards, a game carousel, a
/// treasure row, and -- at the bottom -- a horizontal strip of all six
/// world characters. That last row was the clearest statement of the
/// problem: six different characters offered on the one screen that is
/// supposed to introduce the child's own friend. It has been removed.
///
/// What it is now:
///   1. The child's own friend, large, greeting them by name.
///   2. An illustrated trail with one stop per journey activity, the friend
///      standing at the stop they have actually reached, and the treasure
///      at the end.
///   3. One primary action -- continue the adventure.
///   4. The current destination and the progress towards the treasure.
///   5. A small number of secondary actions underneath.
///
/// The trail is not decoration. It has exactly
/// [AdaptiveGameEngine.journeyLength] stops, and the lit ones are
/// `JourneyController.completedCount` -- the real journey, drawn.
class HomeScreen extends StatelessWidget {
  final VoidCallback onStartAdventure;
  final VoidCallback onAllGames;
  const HomeScreen({
    super.key,
    required this.onStartAdventure,
    required this.onAllGames,
  });

  static const List<GameType> _quick = GameLibraryScreen.featured;

  static const String _makePrompt = 'Make your friend';

  /// One name per journey stop. These are labels over real progress, not
  /// extra destinations: stop N is the Nth activity of the journey the
  /// engine builds. If [AdaptiveGameEngine.journeyLength] ever changes,
  /// `AdventureTrail.stopName` falls back to a plain number rather than
  /// running off the end of this list.
  static const List<String> stopNames = [
    'Welcome Meadow',
    'Whispering Forest',
    'Puzzle Bridge',
    'Calm Cove',
    'Starry Cave',
    'Treasure Clearing',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalmColors.mist,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            AccountService.instance,
            JourneyController.instance,
            RewardService.instance,
            AvatarService.instance,
          ]),
          builder: (context, _) {
            final name = AccountService.instance.activeChild?.nickname.trim();
            final hello =
                (name == null || name.isEmpty) ? 'Hi friend!' : 'Hi $name!';
            final done = JourneyController.instance.completedCount;
            const total = AdaptiveGameEngine.journeyLength;
            final finished = done >= total;
            final r = RewardService.instance;
            final svc = AvatarService.instance;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // ---- the friend speaks -------------------------------
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _openCharacters(context, svc.hasChosen),
                      child: AvatarView(svc.active, size: 78, animate: true),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MindySpeechBubble(
                        text: finished
                            ? '$hello We found the treasure together!'
                            : '$hello Ready to carry on?',
                        fontSize: 19,
                        maxWidth: 260,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ---- the trail ---------------------------------------
                AdventureTrail(
                  done: done,
                  total: total,
                  avatar: svc.active,
                  onTap: onStartAdventure,
                ),
                const SizedBox(height: 12),

                // ---- where we are, and the one thing to do next ------
                Text(
                  finished
                      ? 'The whole trail is walked.'
                      : 'Next stop: ${AdventureTrail.stopName(done)}',
                  style: AppText.heading
                      .copyWith(fontSize: 21, color: CalmColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  finished
                      ? 'You can walk it again whenever you like.'
                      : '$done of $total stops on the way to the treasure '
                          '— each stop is one adventure activity',
                  style: AppText.body.copyWith(color: CalmColors.inkSoft),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    key: const Key('home_continue'),
                    onPressed: onStartAdventure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CalmColors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                    child: Text(
                        finished
                            ? 'Walk it again'
                            : 'Continue my adventure',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 10),

                // ---- a small number of secondary actions -------------
                Row(
                  children: [
                    Expanded(
                      child: _Secondary(
                        key: const Key('home_calm_corner'),
                        icon: Icons.spa_rounded,
                        title: 'Calm Corner',
                        subtitle: 'A quiet moment',
                        tint: CalmColors.tealSoft,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const CalmCornerScreen())),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Secondary(
                        key: const Key('home_my_friend'),
                        icon: Icons.face_retouching_natural_rounded,
                        title: svc.hasChosen ? svc.active.name : _makePrompt,
                        subtitle:
                            svc.hasChosen ? 'Change their look' : 'Pick a look',
                        tint: CalmColors.sunSoft,
                        onTap: () => _openCharacters(context, svc.hasChosen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // ---- kept from before: quick play, then treasures ----
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Just for fun',
                            style: AppText.heading.copyWith(
                                fontSize: 21, color: CalmColors.ink)),
                        // The trail counts the adventure, not every game.
                        // Free play is deliberately not stored and not part
                        // of the journey, so it must not look like it is.
                        Text('Playing here is practice — the trail stays '
                            'where it is',
                            style: AppText.body
                                .copyWith(fontSize: 13,
                                    color: CalmColors.inkSoft)),
                      ],
                    ),
                  ),
                  TextButton(onPressed: onAllGames, child: const Text('See all')),
                ]),
                SizedBox(
                  height: 176,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quick.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => _GameCard(
                      game: _quick[i],
                      onTap: () => launchPractice(context, _quick[i], 2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('My treasures',
                    style: AppText.heading
                        .copyWith(fontSize: 21, color: CalmColors.ink)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  _Treasure(sprite: 'star', count: r.stars, label: 'Stars'),
                  _Treasure(
                      sprite: 'heart',
                      count: r.flowers + r.butterflies,
                      label: 'Garden'),
                  _Treasure(
                      sprite: 'cloud',
                      count: r.rainbowPieces,
                      label: 'Rainbow'),
                  _Treasure(sprite: 'apple', count: r.gems, label: 'Gems'),
                ]),
                // The "Your friends" row of all six world characters used
                // to sit here. Removed on purpose: the child has one
                // friend, and the world characters belong inside their own
                // games, not offered as alternatives on the home screen.
              ],
            );
          },
        ),
      ),
    );
  }

  static void _openCharacters(BuildContext context, bool made) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          made ? const MyCharactersScreen() : const CharacterCreatorScreen(),
    ));
  }
}

/// The illustrated trail: landscape, winding path, one stop per journey
/// activity, the child's friend standing where they have actually got to,
/// and the treasure at the end.
class AdventureTrail extends StatelessWidget {
  final int done;
  final int total;
  final MindyAvatar avatar;
  final VoidCallback onTap;

  const AdventureTrail({
    super.key,
    required this.done,
    required this.total,
    required this.avatar,
    required this.onTap,
  });

  static const double height = 330;

  static String stopName(int index) =>
      index >= 0 && index < HomeScreen.stopNames.length
          ? HomeScreen.stopNames[index]
          : 'Stop ${index + 1}';

  /// Where each stop sits inside a box of [size]. Shared by the painter and
  /// by this widget, so the friend always stands exactly on a stop rather
  /// than near one.
  ///
  /// v41: these used to alternate hard between x=0.26 and x=0.74, which is
  /// what made the trail read as sharp switchbacks instead of a path. They
  /// now follow the approved map — a wandering line left to right, rising
  /// as it recedes — and the painter tapers the ribbon along it, which is
  /// what actually creates the sense of distance.
  static const List<Offset> _layout = [
    Offset(0.108, 0.922),
    Offset(0.286, 0.806),
    Offset(0.420, 0.871),
    Offset(0.594, 0.771),
    Offset(0.720, 0.648),
    Offset(0.839, 0.697),
  ];

  static List<Offset> stops(Size size, int total) {
    if (total <= 0) return const [];
    return [
      for (var i = 0; i < total; i++)
        () {
          // Follow the authored layout where there is one; past its end,
          // keep climbing to the right so a longer journey still works.
          final f = i < _layout.length
              ? _layout[i]
              : Offset(0.86 + 0.02 * (i - _layout.length + 1),
                  0.66 - 0.03 * (i - _layout.length + 1));
          return Offset(size.width * f.dx, size.height * f.dy);
        }(),
    ];
  }

  static Offset treasureAt(Size size) =>
      Offset(size.width * 0.935, size.height * 0.56);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue my adventure. $done of $total stops done.',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: SizedBox(
            height: height,
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, height);
              final pts = stops(size, total);
              // Where the friend stands: the next stop to walk to, or the
              // treasure once the whole trail is done.
              final at = done >= total
                  ? treasureAt(size).translate(0, 26)
                  : pts[done.clamp(0, total - 1).toInt()];
              const figure = 76.0;
              const figureH = figure * AvatarPainter.aspect;
              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _TrailPainter(done: done, total: total),
                      ),
                    ),
                  ),
                  Positioned(
                    left: at.dx - figure / 2,
                    // Lift by the figure's full height so it stands ON the
                    // stop rather than over it. The ratio comes from the
                    // painter, so changing the artwork cannot strand it.
                    top: at.dy - figureH + 8,
                    width: figure,
                    height: figureH,
                    child: IgnorePointer(
                      child: AvatarView(avatar, size: figure, animate: true),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final int done;
  final int total;
  _TrailPainter({required this.done, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final full = Offset.zero & size;
    // Everything is sized from the box height, so the scene holds together
    // on a short phone and on a tall one.
    final k = h / 300;

    // Sky, then meadow.
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE2F0), Color(0xFFDCEFEA), Color(0xFFEDF4DE)],
          stops: [0.0, 0.40, 0.62],
        ).createShader(full),
    );

    // Sun, tucked into a corner so nothing important sits on it.
    final sun = Offset(w * 0.86, h * 0.14);
    canvas.drawCircle(
      sun,
      46 * k,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xA6FFF3C9), Color(0x00FFF3C9)],
        ).createShader(Rect.fromCircle(center: sun, radius: 46 * k)),
    );
    canvas.drawCircle(sun, 17 * k, Paint()..color = const Color(0xFFFFF0BE));

    // Clouds.
    final cloud = Paint()..color = const Color(0xE0FFFFFF);
    void puff(double cx, double cy, double r) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: r * 2.2, height: r * 1.1),
          cloud);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + r * 0.5, cy - r * 0.22),
              width: r * 1.5,
              height: r * 1.25),
          cloud);
    }

    puff(w * 0.16, h * 0.14, 22 * k);
    puff(w * 0.46, h * 0.09, 17 * k);

    // Far mountains: pale, low contrast, with snow caps. These do most of
    // the work of making the scene feel deep.
    final far = Paint()..color = const Color(0xFFAFC9D6);
    final cap = Paint()..color = const Color(0xFFE7F1F5);
    void peak(double cx, double baseY, double halfW, double height) {
      canvas.drawPath(
          Path()
            ..moveTo(cx - halfW, baseY)
            ..lineTo(cx, baseY - height)
            ..lineTo(cx + halfW, baseY)
            ..close(),
          far);
      canvas.drawPath(
          Path()
            ..moveTo(cx - halfW * 0.3, baseY - height * 0.7)
            ..lineTo(cx, baseY - height)
            ..lineTo(cx + halfW * 0.3, baseY - height * 0.7)
            ..close(),
          cap);
    }

    peak(w * 0.16, h * 0.45, 56 * k, 52 * k);
    peak(w * 0.30, h * 0.45, 44 * k, 38 * k);
    peak(w * 0.74, h * 0.44, 50 * k, 46 * k);

    // Rolling hills, back to front.
    void hills(double top, double amp, Color c) {
      const steps = 5;
      final span = w / steps;
      final p = Path()
        ..moveTo(0, h)
        ..lineTo(0, top);
      for (var i = 0; i < steps; i++) {
        final x = i * span;
        p.quadraticBezierTo(
            x + span / 2, top - (i.isEven ? amp : amp * 0.6), x + span, top);
      }
      p
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(p, Paint()..color = c);
    }

    hills(h * 0.46, 22 * k, const Color(0xFF9CC6A6));
    hills(h * 0.54, 17 * k, const Color(0xFF8DBB97));

    // Meadow floor.
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.60)
        ..cubicTo(w * 0.3, h * 0.56, w * 0.6, h * 0.63, w, h * 0.58)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFFB6D9A4), Color(0xFF8FC487)],
        ).createShader(Rect.fromLTRB(0, h * 0.56, w, h)),
    );

    // A small pool: the Calm Cove.
    final pool = Rect.fromCenter(
        center: Offset(w * 0.70, h * 0.80), width: 120 * k, height: 40 * k);
    canvas.drawOval(pool, Paint()..color = const Color(0xFF7FC2D8));
    canvas.drawOval(pool.deflate(4 * k),
        Paint()..color = const Color(0xFF9AD4E6));

    // Far treeline: small and pale, so it sits behind everything.
    final rand = Random(5);
    final farTree = Paint()..color = const Color(0xFF79AC85);
    for (var i = 0; i < 11; i++) {
      final x = rand.nextDouble() * w;
      final y = h * (0.52 + rand.nextDouble() * 0.06);
      canvas.drawCircle(Offset(x, y), (5 + rand.nextDouble() * 4) * k, farTree);
    }

    final pts = AdventureTrail.stops(size, total);
    if (pts.isEmpty) return;
    final chest = AdventureTrail.treasureAt(size);

    // ---- the trail -------------------------------------------------
    // Drawn as one segment per link, each narrower than the last. The
    // taper is what reads as distance; a constant-width ribbon reads as a
    // flat zigzag, which is what this used to be.
    final route = <Path>[];
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      route.add(Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
            a.dx + (b.dx - a.dx) * 0.55,
            a.dy + (b.dy - a.dy) * 0.15,
            b.dx,
            b.dy));
    }
    route.add(Path()
      ..moveTo(pts.last.dx, pts.last.dy)
      ..quadraticBezierTo((pts.last.dx + chest.dx) / 2,
          pts.last.dy - 10 * k, chest.dx, chest.dy + 10 * k));

    double widthAt(int i) => (30 - i * 3.4) * k;
    for (var pass = 0; pass < 2; pass++) {
      final col = pass == 0
          ? const Color(0xFFCBAE78)
          : const Color(0xFFF4E3BB);
      final shrink = pass == 0 ? 0.0 : 7 * k;
      for (var i = 0; i < route.length; i++) {
        canvas.drawPath(
            route[i],
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (widthAt(i) - shrink).clamp(2.0, 60.0)
              ..strokeCap = StrokeCap.round
              ..color = col);
      }
    }

    // ---- near trees: bigger, darker, with trunks --------------------
    final trunk = Paint()..color = const Color(0xFF8A6A4A);
    final leafDark = Paint()..color = const Color(0xFF5E9C6C);
    final leafLight = Paint()..color = const Color(0xFF74B07F);
    void tree(double x, double y, double s) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(x, y + s * 0.7),
                  width: s * 0.26,
                  height: s * 0.8),
              Radius.circular(s * 0.13)),
          trunk);
      canvas.drawCircle(Offset(x, y), s * 0.62, leafDark);
      canvas.drawCircle(
          Offset(x - s * 0.24, y - s * 0.2), s * 0.44, leafLight);
    }

    tree(w * 0.055, h * 0.72, 34 * k);
    tree(w * 0.20, h * 0.66, 26 * k);
    tree(w * 0.50, h * 0.70, 30 * k);
    tree(w * 0.885, h * 0.80, 36 * k);

    // Foreground bushes: the biggest shapes on screen, which is what
    // makes everything behind them look far away.
    final bushDark = Paint()..color = const Color(0xFF6FAE76);
    final bushLight = Paint()..color = const Color(0xFF84BE87);
    void bush(double cx, double cy, double rw) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rw * 0.58),
          bushDark);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx - rw * 0.2, cy - rw * 0.1),
              width: rw * 0.62,
              height: rw * 0.42),
          bushLight);
    }

    bush(w * 0.03, h * 0.99, 90 * k);
    bush(w * 0.97, h * 0.97, 100 * k);

    // ---- stop markers ----------------------------------------------
    for (var i = 0; i < pts.length; i++) {
      final walked = i < done;
      final here = i == done;
      final c = pts[i];
      // Markers shrink along the trail, like everything else.
      final r = (17 - i * 1.4) * k;
      canvas.drawOval(
          Rect.fromCenter(
              center: c.translate(0, r * 0.75),
              width: r * 2.6,
              height: r * 0.8),
          Paint()..color = const Color(0x1F000000));
      canvas.drawCircle(
          c,
          r + 1.5 * k,
          Paint()
            ..color = walked
                ? const Color(0xFF1B5F5A)
                : const Color(0xFFD9CDB4));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..color = walked
                ? const Color(0xFF26837C)
                : (here ? Colors.white : const Color(0xFFEFE7D5)));
      if (here) {
        canvas.drawCircle(
            c,
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * k
              ..color = const Color(0xFF26837C));
        canvas.drawCircle(c, r * 0.36, Paint()..color = const Color(0xFF26837C));
      }
      if (walked) {
        // A tick, drawn rather than written, so it needs no font or glyph.
        final tick = Path()
          ..moveTo(c.dx - r * 0.42, c.dy)
          ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
          ..lineTo(c.dx + r * 0.44, c.dy - r * 0.34);
        canvas.drawPath(
            tick,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2 * k
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white);
      }
    }

    _chest(canvas, chest, done >= total, k);
  }

  /// The treasure at the end of the trail. It glows and its lid lifts once
  /// every stop is walked.
  void _chest(Canvas canvas, Offset c, bool open, double k) {
    if (open) {
      final r = 42 * k;
      canvas.drawCircle(
        c.translate(0, -2 * k),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xB3FFE9A8), Color(0x00FFE9A8)],
          ).createShader(
              Rect.fromCircle(center: c.translate(0, -2 * k), radius: r)),
      );
    }
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(0, 26 * k), width: 56 * k, height: 14 * k),
        Paint()..color = const Color(0x1A000000));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, 8 * k), width: 46 * k, height: 28 * k),
            Radius.circular(5 * k)),
        Paint()..color = const Color(0xFF8A5A36));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c.translate(0, open ? -14 * k : -9 * k),
                width: 50 * k,
                height: 17 * k),
            Radius.circular(8 * k)),
        Paint()..color = const Color(0xFFA06C44));
    canvas.drawRect(
        Rect.fromCenter(
            center: c.translate(0, 8 * k), width: 10 * k, height: 28 * k),
        Paint()..color = const Color(0xFFE8C66B));
    canvas.drawCircle(
        c.translate(0, 8 * k), 3.6 * k, Paint()..color = const Color(0xFFFFF0BE));
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.done != done || old.total != total;
}

class _Secondary extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;
  const _Secondary({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: tint,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: CalmColors.ink),
                const SizedBox(height: 6),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: CalmColors.ink)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, color: CalmColors.inkSoft)),
              ],
            ),
          ),
        ),
      );
}

class _GameCard extends StatelessWidget {
  final GameType game;
  final VoidCallback onTap;
  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play ${game.title}',
      child: GestureDetector(
        key: Key('home_${game.id}'),
        onTap: onTap,
        child: Container(
          width: 136,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [game.nodeGradient.first, game.nodeGradient.last],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: AppShadows.soft,
          ),
          child: Column(children: [
            Expanded(
                child: Sprite('host_${game.character.name}',
                    width: 84, height: 84)),
            Text(game.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)])),
          ]),
        ),
      ),
    );
  }
}

class _Treasure extends StatelessWidget {
  final String sprite;
  final int count;
  final String label;
  const _Treasure(
      {required this.sprite, required this.count, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: CalmColors.card,
            border: Border.all(color: CalmColors.cardBorder),
            borderRadius: BorderRadius.circular(AppRadii.md)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Sprite(sprite, width: 30, height: 30),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count',
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: CalmColors.ink)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: CalmColors.inkSoft)),
          ]),
        ]),
      );
}
