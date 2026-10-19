# Requirement matrix (final-product brief vs this ZIP)

Status words: **DONE** = implemented in code and covered by a unit test or a
direct code path; **PARTIAL** = works but narrower than the brief;
**MOCKED** = works against an offline stand-in only; **NOT BUILT** = absent
on purpose or for lack of time.

**Important:** nothing here has been compiled or run on a device. "DONE"
means "the code exists and was reviewed by hand and by test design", not "I
watched it run". Run `flutter analyze` and `flutter test` first.

| # | Requirement | Status | Where | Notes |
|---|---|---|---|---|
| 5/6 | Sense, Decide, Play, Learn, Adapt, Report loop | DONE | `journey_controller.dart`, `adaptive_game_engine.dart`, `session_repository.dart`, `insights_calculator.dart` | Post-activity feeling feeds the next decision |
| 7 | Sequential adventure map, no bypass | DONE | `journey_screen.dart`, `play_flow.dart` | Only the engine's pending node is playable; locked stops show "?" and do nothing; completed stops show a recap |
| 8-10 | Redesigned check-in, five emotions with unique creatures and atmospheres | DONE | `buddy.dart`, `emotion_picker.dart`, `checkin_screen.dart` | Picking a feeling turns the whole screen into that atmosphere; Happy has a huge smile, rainbow, hearts, bounce. Art is drawn in code, not professional illustration. Optional per-emotion sound cue: only a soft tap sound |
| 11 | Mindy mascot everywhere | PARTIAL | `buddy.dart` (MindyMascot) | On check-in, map, transition, completion, thinking and journey-complete screens. Inside games the world's host character speaks, not Mindy |
| 12 | Check-in data stored | DONE | `game_session.dart`, `journey_controller.dart` | emotion, source, check-in duration, previous emotion. selectedEmotion = emotionBefore |
| 13 | One pure-Dart central engine | DONE | `adaptive_game_engine.dart` | No widgets, storage or randomness; depends only on model files. Duplicate engines removed |
| 14 | AdaptiveChildState | DONE | `adaptive_state.dart` | Rebuilt from stored history every decision |
| 15 | Two-layer adaptation | DONE | engine layers 1 and 2 | |
| 16 | Activity suitability | DONE | engine `_scoreAll` | 8 components, all stored per decision; never shown to children |
| 17 | Emotion overrides performance | DONE | engine safety rules, tests | Scared/sad: only regulation (+ bubbles for sad), level 1, slow |
| 18 | Bounded performance modifier | DONE | engine `_levelFor` | Between sessions only, max one step, needs 2 same-activity or 3 overall consistent sessions, never for scared/sad, never Easy to Hard (capped). All thresholds are engineering rules |
| 19 | Post-activity emotion + mood change | DONE | `game_shell.dart`, `emotion_state.dart` | Called "self-reported emotional change" |
| 20 | Adaptive recovery | DONE | engine (poor response, recovery penalty, regulation need) | |
| 21/43/44 | DecisionTrace and "Why did Mindy choose this?" | DONE | `decision_trace.dart`, `researcher_screen.dart` | Staff/researcher only |
| 22 | Four+ distinct games, two regulation | DONE | ten games | Breathing Garden (Twinkle), Calm Maze (Pip), Bubble Valley, Feelings Memory, Pattern Power, Rainbow Puzzle |
| 22 | "Breathing Balloon" | PARTIAL | `breathing_garden_game.dart` | A flower/garden, not a balloon (your approved Garden concept) |
| 22 | Pattern Garden levels | PARTIAL | `pattern_power_game.dart` | 5 levels (AB, AAB, ABC, ABBC, longer); no "multiple attributes" level |
| 22 | Calm Maze gentle assistance | DONE | `treasure_journey_game.dart` | Trail appears after 12 s of no touch |
| 23 | Five-level progression | DONE | every game (now ten) | Verified by parameter tests |
| new | Cute arcade-style games (shooter, connect, hop, peekaboo) | DONE (unrun) | `bubble_shooter_game.dart`, `happy_connect_game.dart`, `cloud_hop_game.dart`, `peekaboo_pals_game.dart` | Original games; gentle versions (no timers or losing). Pure logic (hex grid, path rules, hop landing) is unit tested; the on-screen feel (aim, hop timing, art) is untested until you run it |
| 24 | Child never sees metrics | DONE | child screens + language test | Tests scan lines for banned words |
| 25 | Reward + "Mindy learned" | DONE | `game_shell.dart` | |
| 26-29 | Wellbeing Insights with evidence tiers | DONE | `insights_calculator.dart`, `wellbeing_insights_screen.dart` | "Mindy is still learning" under 3 sessions; no pattern language before 7 |
| 30 | Caregiver observation input | DONE | insights screen, `caregiver_observation.dart` | Always labelled; never feeds the engine |
| 31 | Validated screening module | NOT BUILT | n/a | On purpose: no instrument is approved in the proposal; a made-up score is not allowed |
| 32 | Non-diagnostic wording | DONE | insights, settings, README | |
| 33/34 | Researcher dashboard + 8 charts | DONE | `researcher_screen.dart`, `chart_data.dart` | Real data only; empty states otherwise |
| 35 | Three study conditions | DONE | `study_condition.dart`, engine | |
| 37/38 | Research data model, CSV + JSON export | DONE | `export_service.dart`, `game_session.dart` | Export is shown on screen and copied to the clipboard; no file is written (no extra file/sharing package) |
| 39 | No fake physiology | DONE | `physiological_data_source.dart` | Interface only; returns nothing |
| 40 | Response time + variability | DONE | `game_session_controller.dart` | Per game where the mechanic supports it; labelled interaction indicators |
| 46 | Accessibility | PARTIAL | | Large targets, labels, check marks beside colour, portrait and landscape. No screen-reader pass done, no contrast audit |
| 47 | Safety | DONE | | No flashing, countdowns, loss states, leaderboards; soft sounds |
| 48 | Audio on/off, persisted | DONE | `app_settings.dart` | Works with missing audio files |
| 49 | Pause/resume/exit | DONE | `game_shell.dart` | Pause freezes tickers and scheduled actions; exit logs an incomplete session |
| 50 | Persistence | DONE | `session_repository.dart`, `journey_controller.dart` | shared_preferences JSON; fine for a pilot, not for tens of thousands of sessions |
| 51 | Offline-first | DONE | all of the above | Nothing needs a network |
| 52 | KARA interface | MOCKED | `emotion_signal_client.dart` | Mock default; real HTTPS client exists but there is no backend to test against. Never reports "connected" falsely |
| 53 | Performance instrumentation | PARTIAL | | Load time (Play tap to first frame) and captured Dart errors are logged. Input latency and true crash rates are not measured |
| 54 | Tests | DONE (unrun) | `test/` | ~90 tests |
| 57 | Backend upload | MOCKED | `sync_service.dart` | Queue and retry work against the mock |
| - | Reports and Reminders (earlier features) | DONE (unchanged) | `report_screen.dart`, `reminders_screen.dart` | Report explanation is still a placeholder from v2 |

## Added in v9 (research data for machine learning)

| Requirement | Status | Where | Notes |
|---|---|---|---|
| Event-level (trial-like) logging | DONE (unrun) | `game_session_controller.dart`, `game_session.dart` | success / mistake / touch / response with active-time stamps; capped at 600 per session |
| Participant code + age | DONE | `app_settings.dart`, researcher Data tab | Anonymous code only |
| Sessions CSV + Events CSV export | DONE | `export_service.dart` | Python tests read the exact column list |
| Behavioural Screening Summary screen | DONE (display only) | `screening_report_screen.dart` | Shows only a pasted Python report; synthetic reports are flagged |
| Stimulus-level trials, hesitation, premature taps, missed targets | PARTIAL / NOT BUILT | n/a | Mindy is play, not a controlled task; most games cannot supply these. Say so in your thesis |
| On-device ML / live prediction | NOT BUILT | n/a | Deliberate: Flutter -> export -> Python -> report (option C) for the 2-week plan |
