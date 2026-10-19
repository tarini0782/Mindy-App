# Mindy v4 — Bright Visual Redesign

## Setup (same drill as before)
1. Stop the running app.
2. Unzip this download.
3. Replace the `lib` folder inside your project with this one.
4. `flutter run`. No new packages added — everything here uses plain
   Flutter (gradients, CustomPainter, AnimationController), so your
   existing `pubspec.yaml` doesn't need any changes.

## What's genuinely new (built and wired in)

- **`lib/theme/app_theme.dart`** — a real design system: bright color
  palette, world-themed gradients (sky/bubble/forest/star/rainbow),
  rounded-corner radii, soft shadows, and a themed `ThemeData` applied
  in `main.dart`. Buttons, nav bar, and cards across the whole app pick
  this up automatically via `Theme.of(context)`.
- **`lib/widgets/mindy_mascot.dart`** — an original mascot, drawn
  entirely with `CustomPainter` (no external asset, so nothing to go
  missing). Idle floating + blinking animation, plus happy/excited/
  encouraging/calm/thinking expressions and a sparkle-burst effect.
- **`lib/widgets/sky_background.dart`** — animated gradient backdrop
  with drifting clouds and (optionally) twinkling stars, used behind
  the check-in screen and the adventure map.
- **`lib/screens/checkin_screen.dart`** — fully redesigned: Mindy
  greets the child, mood choices are five colorful sky-themed cards
  (rain cloud / partly sunny / rainbow / sunshine) instead of plain
  emoji buttons. **Functionally identical** to before — same five
  `EmotionState` values, same "I'd rather not say" fail-safe-to-calm
  path, same navigation to the next screen.
- **`lib/screens/game_feed_screen.dart`** — replaced the vertical swipe
  feed with **"Mindy's Adventure"**, a winding dashed path connecting
  circular world nodes (one per game), plus a star counter and the
  existing "Meet Kara" card as the final stop. Same class name and
  constructor as before, so nothing else in the app had to change.
- **`lib/services/reward_service.dart`** — a simple, honest star tally
  (stars only ever go up, no purchases, no loss) shown in the adventure
  map's top bar and awarded on the completion screen.
- **`lib/widgets/celebration_overlay.dart`** — the "You did it!"
  completion screen: confetti, Mindy celebrating, stars earned. This
  replaces the old plain `AlertDialog` completion popup.
- **`lib/games/tap_catch_engine.dart`** (shared by **Bubble Pop** and
  **Star Catcher**) — reskinned: glossy gradient "orb" bubbles/stars,
  a colored gradient background per game, Mindy cheering during play,
  a star-pip progress row instead of "3/10 caught" text, and the new
  celebration overlay on completion. **All game logic is untouched** —
  spawn timing, tap detection, reaction-time tracking, accuracy,
  session logging all work exactly as before; only `build()` changed.
- **`main.dart`** — applies the new theme, friendlier nav labels, and a
  lightweight **parent gate** (a one-question check) in front of the
  Reports and Progress tabs, so a child doesn't casually land on raw
  accuracy/reaction-time numbers.

## What was intentionally left alone

To stay honest about scope, these were **not** rewritten this round —
restyling them is a natural next step, but redoing all of them in one
pass without being able to compile/test anything here would have meant
handing you code I couldn't verify:

- **Memory Match, Pattern Play, Breathing Balloon, Quick Tap** — still
  using their original visuals. Their difficulty tiers were already
  real (per the v3 README), just not yet reskinned to match the new
  design system.
- **Settings / Reports / Progress / Reminders screens** — functionally
  unchanged. They'll automatically pick up the new button/card colors
  from the shared theme, but haven't been redesigned screen-by-screen.
- **No mascot states wired into every single screen** yet — Mindy
  currently appears on the check-in screen, the adventure map, and
  inside Bubble Pop/Star Catcher.
- **No audio changes** — same real-but-silent-if-missing behavior as
  before (see `assets/audio/README.txt`).
- **5-level difficulty configs, Rive/Lottie, parent dashboard with
  DecisionTrace UI** — not built this round. These are larger, separate
  pieces of work (see the "further work" note below).

## Important: I could not compile or test this

There's no Flutter SDK available in the environment I used to write
this, so nothing here has been run through `flutter analyze` or
`flutter run`. I checked every file for balanced braces/parens and
consistent class contracts against how the rest of the project calls
them, but **please run `flutter analyze` first and send me the exact
red error text if anything doesn't compile** — same rule as your
existing README already states for past rounds.

## Suggested next round (if you want to keep going)

1. Reskin Memory Match / Pattern Play / Breathing Balloon with the new
   `AppColors`/`MindyMascot`/`celebration_overlay` (same pattern used
   here for Bubble Pop/Star Catcher).
2. Add a small parent-facing "Decision Trace" card to the Reports
   screen using the existing `PerformanceAdaptiveEngine` output.
3. Only then consider Rive/Lottie — that's a new dependency, so it's
   safest to add once everything else is confirmed compiling.
