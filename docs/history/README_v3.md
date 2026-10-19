# Mindy App — v3 (6 real games + Settings)

Replaces your whole `lib/` folder again. Adds, on top of v2:

- **3 new, genuinely different games**: Memory Match (card pairs),
  Quick Tap (fast single-target reflex game), Pattern Play
  (Simon-says style sequence recall) — so the feed now has **6 real
  playable games** (plus 1 "Coming soon": Calm Maze)
- Every game's Easy/Medium/Hard actually changes real gameplay
  parameters (pair count, target size/lifetime, sequence length/speed)
  — not just a label
- A **Settings screen** (gear icon, top-left of the game feed):
  independent Music / Sound Effects toggles, Reset progress, About
- **Progress screen** now also shows a reaction-time trend and a
  difficulty-progression row (Easy → Medium → Hard), normalized across
  all 6 games, alongside the existing mood trend and accuracy

Same rule as always: I can't compile/run this myself. Send me the exact
red error text and I'll fix the file.

## Setup (same drill as before)

1. Stop the running app: click the black window, press `q`, Enter.
2. Unzip this download.
3. Delete the `lib` folder inside `C:\mindy_app`, copy this one in.
4. Copy the `assets` folder in too (same as v2 — skip if you already
   did this step last time).
5. No new packages needed this round (audioplayers/image_picker/
   flutter_local_notifications from before are enough).

## Run it

```
cd C:\mindy_app
flutter run
```

Flow: check-in → swipe feed (now 6+1 cards) → tap Play on any game →
play → completion dialog → back to feed. Gear icon (top-left, over the
feed) opens Settings. Bottom nav's **Progress** tab shows trends after
a few sessions.

## What's still honestly mocked/deferred

- "Calm Maze" is still a Coming Soon placeholder
- KARA integration is still a stub (not connected yet)
- Report explanation is still mocked
- Reminders are still device-local, not server-scheduled
- Real music/sound files aren't included (copyright) — see
  `assets/audio/README.txt`

Say this plainly in your demo, same as before — it's a legitimate,
defensible scope, not something to hide.

## Design note for your defense

Every game's difficulty tiers are interpreted independently per game
(see each game's own `_xxxDifficulty.fromConfig()`), but all of them
read from the SAME underlying decision
(`PerformanceAdaptiveEngine.decide()` — emotion first, with a bounded
one-step nudge from the previous session's accuracy/reaction time).
That's the actual research contribution: one centralized, explainable,
rule-based decision, expressed differently by each game's own
mechanics — not six independent adaptation systems.
