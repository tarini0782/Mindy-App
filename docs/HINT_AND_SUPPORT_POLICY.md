# Hint and support policy

Ladder: independent -> visual cue -> small hint -> demonstration -> easier -> break offer.
Engineering rules (not clinical): evidence = **consecutive errors since last success**.

| Consecutive errors | Stage |
|---|---|
| 1-2 | none |
| 3 | visual cue (ring/arrow on target) |
| 4 | small hint (character speaks game-specific text) |
| 5 | demonstration (game callback: replay sequence, dotted path) |
| 6 | easier (lowers ONE parameter; **skipped in FIXED_BASELINE**) |
| 8 | break offer ("tap pause any time") |
Also: 15 s idle -> visual cue only; light-bulb button -> hint, then demonstration; max 10 automatic offers per
session; a success resets the ladder (child continues independently). Wording is always kind; no score is
shown; failing never ends a game.

Logged: `support` event (value = stage 1..5), `difficulty` event (value = new level), and per session
`supportCount`, `maxSupportStage`, `attemptsAfterSupport`, `successesAfterSupport`, `difficultyAdjustments`.
Trigger type (errors/idle/requested) is held in the engine history but not yet exported.
**Needing help is not evidence of low ability or any health problem.** Code: `support_engine.dart` (tests in
`support_and_games_test.dart`).
