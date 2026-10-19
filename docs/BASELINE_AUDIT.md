# Baseline audit (what I could and could not check)

**Source audited:** your uploaded `mindy_app_v9.zip` and `mindy_ml.zip`, compared file-by-file with the
v9/ML zips I delivered earlier (identical). I did not have `C:\mindy_app`, Git history, a Flutter SDK or
an Android emulator, so `flutter --version`, `pub get`, `analyze`, `test` and the emulator checks
were **not run**. Nothing below was compiled. Backing up: please copy `C:\mindy_app` to a dated folder
before you merge anything (this ZIP is separate and does not touch your folder).

## v9 architecture (verified by reading source)
Flutter/Material 3; `shared_preferences` JSON persistence (`session_repository.dart`); pure-Dart adaptive
engine (`adaptive_game_engine.dart`, two layers, DecisionTrace); `GameSessionController` (stats, pause-aware
timers, event log capped at 600) and `GameShell` (header, pause, completion card, feeling-after);
`JourneyController` (6-activity adventure, pending decision); researcher screen (Data tab, CSV/JSON export);
screening report screen that only displays a pasted JSON (never computes).

## Why only ~5 games appeared (answer)
v9 registered **10** games in `GameType`. The child's "Adventure" tab shows only the 6-stop journey the
engine chose, so a child never saw a list of all games; there was **no library screen at all**. That is
the "only five games" experience. Not a scroll bug: the list did not exist.

## Status in v9
| Area | Status |
|---|---|
| In-app check-in connected to navigation | Yes: `PlayFlow` -> `CheckinScreen` -> `JourneyScreen` (code path read, not run) |
| Pre/post feeling stored | Yes (`emotionBefore/After`, source, duration) |
| Sessions persisted | Yes, JSON in shared_preferences; interrupted sessions saved from `dispose()` |
| Hint/support system | **Absent** in v9 |
| Practice vs research separation | **Absent** in v9 |
| Event types | success, mistake, touch, response only |
| Library of all games | **Absent** |
| ML integrated into Flutter | No. Python is offline; the app only *displays* a pasted report JSON |
| Tests | 6 Dart test files exist; never executed by me |
