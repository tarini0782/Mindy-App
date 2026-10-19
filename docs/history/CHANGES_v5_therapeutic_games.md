# Mindy v5 -- emotion-adaptive therapeutic games

**Read first:** this was written without a Flutter SDK, so it has NOT been
compiled. Run `flutter analyze` and send back the exact error text; expect a
few small fixes.

## Flow
Check-in -> `AdaptiveGameEngine.recommend()` -> adventure map opens and pushes a
friendly transition -> game (inside `GameShell`) -> session logged ->
completion screen (Play Again / Back to Games).

## Rules (rule-based, explainable)
| Emotion | Category | Difficulty | Pace |
|---|---|---|---|
| scared / skipped | calming | easy | slow |
| sad | calming | easy | slow |
| neutral / calm | standard | medium | normal |
| happy | energetic | hard | fast |

Performance nudge: at most one step, from the last game session's accuracy;
never applied for scared / sad. Calming games never run at Fast pace.
Candidates per emotion rotate deterministically (see engine file).

## New files
- lib/games/models/: game_type, game_difficulty, game_pace, game_recommendation, game_session
- lib/games/engine/: adaptive_game_engine, research_config
- lib/games/base/: game_shell, game_session_controller, game_factory, game_loop,
  phase_timeline, falling_catch, game_audio
- lib/games/widgets/: game_header, game_progress, positive_feedback, cute_painters
- lib/games/: bubble_breathing, bunny_breaths, flower_garden, bubble_fish, calm_ocean,
  cloud_painter, honey_hunt, panda_picnic, butterfly_garden, rainbow_hop,
  monster_munch (star_catcher_game.dart is rewritten)
- lib/screens/game_transition_screen.dart
- test/adaptive_game_engine_test.dart

## Modified files
- services/session_log.dart (adds gameSessions + JSON export; still feeds Progress)
- services/game_registry.dart (12 new games + the 4 original games)
- screens/checkin_screen.dart, screens/game_feed_screen.dart (additive params)
- screens/settings_screen.dart (research toggle, copy session log)
- games/star_catcher_game.dart (replaced by the new game)
- services/notification_service.dart (named-argument API, as you specified)

## Not touched
main.dart, reports, reminders, progress, parent gate, PerformanceAdaptiveEngine,
Bubble Pop, Memory Match, Quick Tap, Pattern Play. Breathing Balloon's file is
still there but no longer listed on the map.

## Notes
- Audio reuses assets/audio/pop.mp3, star.mp3, match.mp3; missing files are ignored.
- If you already have a newer notification_service.dart, keep yours.
- test/ imports use relative paths so the package name doesn't matter.
- Sessions are in memory only; use Settings -> "Copy game session log (JSON)".
