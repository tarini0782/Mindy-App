## v28 (buildability, research report, evaluation harness, new look, character creator)
Full detail in **docs/HANDOVER.md** — not repeated here. Headline: the project had
**no `pubspec.yaml`**, so it could never have been built; one is now present, with the
dependency list taken from the actual `package:` imports. Added: the 14-section
`docs/RESEARCH_REPORT.md`, the evaluation harness (`test/evaluation_harness_test.dart`
plus three Python tools that have been executed), two default-off engine parameters for
a fair three-condition comparison (`pool`, `equalSafetyFloor`) with
`AdaptiveGameEngine.studyPool`, a retuned `CalmColors` palette that re-themes all 28
screens at once, and a code-drawn character creator persisted per child. Dart is
written but **still never compiled** — no SDK available.

## v27-continued (active calm game, report split, project framing)
Three separate requests, each addressed independently:
- NEW calm-pool game `lib/games/firefly_jar_game.dart` (GameType.fireflyJar, World 7 "Firefly
  Meadow"): Calm Maze (Treasure Journey) was a slow, largely passive walk -- this is an ACTIVE but
  still non-stressful alternative: tap glowing fireflies into a jar, at the child's own pace. Same
  calm-pool rules as every other regulation activity: no timer, no hazards, nothing ever expires or
  "escapes," an off-target tap is logged as a neutral touch, never a mistake. Registered in all five
  places a GameType must be: the enum + `_Meta` + `_roles` in `game_type.dart`, the exhaustive switch
  in `game_factory.dart`, the reward-currency switch in `reward_service.dart`, and all five emotion
  buckets of `AdaptiveGameEngine._compat` in `adaptive_game_engine.dart` (Calm Maze's weight in the
  `calmOnly`/`sad` buckets was REDUCED, not removed, so both stay reachable; `fixedSequence`, used by
  the FIXED_BASELINE/DIFFICULTY_ONLY study conditions, was deliberately left untouched for research
  determinism). Fixed one real bug while building it: the first fireflies were being added by calling
  a `setState`-wrapped spawn method directly inside `initState()`, which Flutter disallows because
  `initState` runs during the parent's build phase -- fixed by populating the initial list directly.
  Test: `test/firefly_jar_test.dart` (registration, calm-pool membership, level-scaling, two
  `testWidgets` play-through tests). `GameType.values.length` expectation updated 26 -> 27 in
  `test/games_and_controls_test.dart` and `test/support_and_games_test.dart`.
- Report screen rewrite ("the report part is so messy"): the old `wellbeing_insights_screen.dart` was
  one long `ListView` stacking ~8 dense, jargon-heavy cards (evidence-level badges, raw participation
  counts, adaptive-journey engine internals) in the OLD pre-v26 theme (`AppText`/`AppColors`/`Card`),
  not the calm `CalmColors`/`CalmCard` look used everywhere else. Split in two:
  - `lib/screens/wellbeing_insights_screen.dart` (same class name, same route from Parent Hub): now a
    SHORT plain-language screen -- a few sentences on what the child enjoyed/found tricky/felt/could
    try next (unchanged logic, restyled), a "Save observation" box, and one clear card: "See the full
    summary of how {name} used Mindy."
  - NEW `lib/screens/wellbeing_full_summary_screen.dart`: everything that used to be inline -- charts,
    per-window participation/behaviour detail, the adaptive journey, research indicators -- moved here,
    reached only by tapping that one card. Restyled to `CalmColors` throughout; no content was dropped
    or changed, only relocated and reworded where it was unclear.
  - Test: `test/wellbeing_report_split_test.dart` (short screen has none of the dense text; tapping the
    link opens the full screen; empty-data state still just says "Mindy is still learning").
- "Not only a gaming app" framing: Settings' existing "About Mindy" tile (a static one-line blurb) is
  now "About Mindy & this project," tappable, opening a short dialog that states Mindy is the
  emotion-adaptive CBT mini-game component of a larger final-year multi-student project (an AI-driven
  multiplatform pediatric healthcare assistance system), built alongside other components by other
  student researchers, and that this app covers only the Mindy component. Deliberately generic about
  what those other components are/do -- nothing about teammates' work was invented. No other screen in
  the app was found to over-brand Mindy as "just a games app," so no other copy was changed.
- Not run through a real Flutter SDK (none available here) -- `flutter analyze`/`flutter test` still
  need to be run by the user before the panel.

## v27 (AI-written insight paragraph over the Support plan)
- NEW `backend/insight_summary.py`: provider-agnostic (Anthropic or OpenAI) call to a pretrained LLM,
  given ONLY aggregated numbers from support_plan.dart (no raw session, no name, no identifier).
  Banned-term validator (diagnosis/disorder/clinical words) checked on the returned text; any failure
  (not configured, network error, bad shape, failed validation) returns `{"source":"fallback", ...}`
  and never raises. `.env`-based key handling (`backend/.env.example`), std-lib only, no new dependency.
- NEW endpoint `POST /insights/summary` in `backend/server.py`, NOT scoped under `/sessions/<child>`
  (deliberately -- no child id ever reaches this call).
- NEW `lib/services/insight_summary_service.dart`: calls the above from Flutter, off by default
  (`AppSettings.aiInsightsEnabled`), re-checks the banned-term list client-side too, caches by a hash
  of the signals so an unchanged plan doesn't repeat the call, and fails completely silently on any
  problem -- the existing rule-based text is always what's shown if this has nothing to add.
- Settings: new opt-in toggle with plain-language wording on exactly what is sent.
- `support_plan_screen.dart`: new card ABOVE the rule-based hero summary, labelled "Written with AI
  help", shown only when enabled and only when a safe result came back. Never replaces the rule text.
- Docs: `docs/LLM_INSIGHT_LAYER.md` (architecture, privacy, what to say to the panel).
- Tests: `backend/test_insight_summary.py` (25 tests, all network calls mocked), 4 new tests appended
  to `backend/test_server.py` (real HTTP round-trip against the actual server), `test/v27_insight_summary_test.dart`.
- Not done: no consent-form wording added yet for this feature (see the doc above) -- needed before
  any real pilot use. Not run through `flutter analyze`/`flutter test` here (no Flutter SDK).

## v26 (Support plan, calm look, Calm Quest)
- NEW `lib/insights/support_plan.dart`: rule-based Support plan for caregivers. Reads the child's own check-ins
  (last 14 days), before/after feelings (30 days), worry faces, Calm Corner visits. Output: a plain band
  (Mostly settled / Some worried moments / Many worried moments lately / Getting to know), signals with the
  evidence behind each, and suggested actions (Do now / This week / Worth considering) that the caregiver can
  "try" or set aside. Rules and thresholds: docs/SUPPORT_PLAN.md. No diagnosis wording; tested for that.
- NEW `lib/services/support_plan_service.dart`: remembers "I'll try this" / "Not now" per child (device only);
  "trying" starts a before/after description of check-ins that states it is not proof of cause.
- NEW `lib/screens/support_plan_screen.dart`: hero summary, 14-day feelings strip, signal cards, action cards,
  "Copy this plan to share" (plain text for a doctor or teacher), caution card.
- NEW `lib/screens/calm_quest_screen.dart`: the therapeutic-gaming component as its own tab ("Calm Quest"):
  how it works, progress, last result, Calm Corner, worry faces; starts the existing guided flow.
- Parent hub rebuilt: leads with the Support plan; groups Understand / Look after / Study tools.
- Calm look for the APP shell only (`CalmColors`, `buildMindyTheme`): mint background, teal, periwinkle, peach.
  Games keep their own bright colours (none of them read the theme).
- NEW `lib/services/demo_seeder.dart`: two invented sample histories (Settling in / Still worried), loaded only
  into the DEMO child from the grown-ups' area, labelled SYNTHETIC. For showing the plan in a panel demo.
- Tests: test/v26_support_plan_test.dart.
- NOT compiled or run here (no Flutter SDK). Run `flutter analyze` and `flutter test` first and send any
  messages back.
- Not done: the plan's thresholds are engineering choices, not clinical cut-offs, and are unvalidated.

## v25.1
- Fix: const error in checkin_screen.dart (greeting now built at runtime). Restored the "Why this game? (grown-ups)" button on the transition screen (the v24 insert had silently not applied, so _why was unused).

## v25 (master)
- Language: English / Sinhala / Tamil for tab names, check-in greeting, feeling faces and check-in buttons (Settings > Language). Sinhala and Tamil are DRAFTS that need a native-speaker review. Logs and exports stay English.
- Worry picture scale: before/after 5-face scale (Grown-ups), average change shown in Adaptive vs fixed. Prototype scale, not validated.
- Robot (KARA) simulator tile in Grown-ups (stored as KARA_SIMULATED).
- Not built: encryption at rest (see docs/ENCRYPTION_PLAN.md).
- All new code and test/v25_features_test.dart are NOT compiled or run (no Flutter SDK here).

## v24
- Demo mode: "Try the demo" on the sign-in screen creates a throw-away grown-up account and a DEMO- child (consent pre-set). Demo sessions are never uploaded (SyncService skips DEMO-), a yellow banner says DEMO - NOT REAL PARTICIPANT DATA.
- "Why this game? (grown-ups)" button on the transition screen: feeling, game, level, pace, condition and the engine reason.
- Grown-ups > "Adaptive vs fixed": descriptive comparison per study condition (sessions, children, mood change, completion, hints, load time, share under 3 s). No significance claims.
- Grown-ups > "Usability questionnaire": SUS (10 items), score 0-100, stored per child on the device.
- New tests: test/v24_features_test.dart. NOT YET RUN (no Flutter SDK here).
- Not built: local encryption, pre/post worry picture scale, robot simulator screen, Sinhala/Tamil labels.

## v23.3
- Startup hardening: each startup step has an 8 s timeout and error capture, so the app always reaches runApp; ErrorWidget shows the real error text instead of a blank/grey box. Blank-screen cause not yet identified: need flutter run console output.

## v23.2
- Engine: sad bubbleValley compat 2 -> 4 so the documented "sad, breathing helped -> gentle Bubble Valley" step wins over Pet Care now that the sad pool has 8 games (one test failed: 253 pass, 1 fail).

## v23.1
- Fix: journey_controller.dart imports game_type.dart (GameType.id), analyzer error from the user run; removed unused import in feed_test.

## v23
- Backend: GET /sessions/{id}/next-game (Appendix C v1 rule) + test (7 Python tests pass).
- docs/PROPOSAL_ALIGNMENT.md: FR/NFR/Appendix C traceability and proposal inconsistencies.
- Flutter code unchanged from v22 (still uncompiled by me).

# v22 additions
* **Fixed repeating games in the adventure** (see PANEL_QA.md Q5).
* **Mindy Feed** (new tab): TikTok-style vertical swipe feed (`lib/feed`, `lib/screens/feed_screen.dart`), as the proposal asks. Planner mixes brain-boost, fun and quiet-break cards; scared/sad or repeated quick skips get quiet games only. Records per-card dwell, play and quick-skip (`FeedLogService`, CSV via `toCsv`). Played games are stored with `trigger = feed` and do not advance the adventure.
* **Ask about a report / X-ray / skin photo**: client for the VQA backend (`vqa_client.dart`) and new screen; shows nothing invented when no service is connected. Contract in `INTEGRATION_CONTRACT.md`.
* `docs/PANEL_QA.md`: honest panel answers, incl. why games alone cannot decide mental health and what a defensible indicator needs.
* New tests: `feed_test.dart`, `vqa_test.dart`, three no-repeat adventure tests in `adaptive_engine_test.dart`. Not run (no Flutter SDK here).

# v21 additions
* **What seems to help** card (`lib/insights/what_helps.dart`): per-child pattern report. Compares activity types by self-reported feeling change **only when the child started low**, needs >=2 low starts per type and >=2 types before comparing, reports "nothing stood out" when gaps are small, hint trend (first vs second half, >=6 activities), whether the level felt right (child's own answers), and the engine's own reason for the latest 3 choices. Always shows its evidence count and a caution. 6 tests (`test/what_helps_test.dart`) - not yet run.
* **Research database**: `backend/` (SQLite, stdlib Python). Matches the app's existing upload endpoints. 6 Python tests run and pass. See `docs/DATABASE.md`.

# v18 additions (read this first)

* **Calm Corner** (`lib/screens/calm_corner_screen.dart`, `lib/services/calm_service.dart`): child-chosen
  regulation space led by Twinkle. Flow: 3-face feeling check -> breathing balloon (5 x 4s in / 4s out)
  or "look around" grounding (3 see, 2 hear, 1 touch) -> 3-face feeling check -> thank you.
  No scores, nothing can be failed. Visits are stored per child (`mindy_calm_v1_<id>`), deleted with the
  child, and are **not** research sessions: they never feed the adaptive engine or the export.
* **Caregiver output**: Calm Corner line in Wellbeing Insights (counts + the child's own "felt better"
  answers, never a measurement) and a **Copy summary to share** button (`ParentSummary.toPlainText`).
* Hero Shield no longer uses emoji for the bunny/clouds/stars (vector sprites, no facing problem).
* Home screen has a Calm Corner card.
* New tests: `test/calm_corner_test.dart` (6 tests). **Not run**: no Flutter SDK was reachable from the
  build environment. Bracket balance of all changed files was checked by script only.

# v17 increment (response to "basic, doesn't fit the screen, no home screen, ugly characters, weak insights")
Written, **not compiled or run** (no Flutter SDK here). New dependency: `flutter pub add flutter_svg`.
* **Artwork:** 31 original vector sprites (`lib/art/`, source in `art/sprites_src.py`). I rendered every sprite in a browser and looked at it before using it. The six hosts (Kara, Nova, Lumi, Bubbles, Pip, Twinkle) are redrawn; `MindyCharacter` now uses them everywhere.
* **Facing rule:** directional sprites are drawn facing right (the car faces up). `Sprite(faceRight:)` mirrors them. Turbo Car now uses a top-down car with the bonnet pointing the way it drives; Dino Dash dino runs right and the eagle flies left (mirrored); Sky Flight dragon faces right; Cloud Bounce unicorn turns to face left/right as you steer. Emoji are no longer used for anything with a front and back in those games.
* **Fits the screen:** every game now sits in a phone-shaped play field centred in the window (`PlayArea`, max 72% of height). Likely cause of "doesn't fit": games scale from width, so on a wide window (desktop/web/tablet) they stretched and spilled off the bottom.
* **Home screen** (new first tab): Mindy greeting, big "Start my adventure" card with progress stars, swipe row of games, treasures, the six friends.
* **Navigation:** 4 tabs - Home, Adventure, Games, Grown-ups. Grown-ups (behind the grown-up check) opens a hub: Parent summary, Reports, Reminders, Settings.
* **Parent insights:** plain-language summary, then stat tiles, a 7-day minutes chart, before/after feelings bars, and a per-game list (played, finished bar, fun face, hard/hints), then the observations.
* **Still not done / honest limits:** the 19 older games (except Turbo Car and Dino Dash) still use emoji for their pieces. I could not look at running screens, so layout in the games is reasoned, not seen. The Mindy mascot on Home/Adventure (BuddyWidget) is the old drawing.

# v17 increment (screen fit)
User feedback after running v16: games looked basic and did not fit the screen.
* Game screen layout (`game_shell.dart`, `game_header.dart`): the character strip (92 px) and bottom bar (~78 px) are gone. Help and Pause moved into a slimmer top bar. The character and speech bubble now float over the play area only while speaking. The instruction shows as a chip for 5 s then fades. The play area gains roughly 170 px of height.
* Dance Party pads were 8 px off the bottom edge; fixed. Teddy Clinic and Puffy's Day content now scales down on short screens (FittedBox).
* NOT verified: I have not seen the screens. Older games with fixed pixel sizes may still overflow on some phones; send a screenshot or the yellow-black overflow message.

# v16 increment
Written, **not compiled or played**.
* **Adaptation inside a game:** after 5 clean successes in a row (no help in between) a game that supports it gets slightly harder (up to 3 times per session; never in FIXED_BASELINE). Logged as a `difficulty` event (value = level + harder steps so far). Wired into the 7 newest games.
* **Child's words change the next level:** if the last session of an activity was rated "hard" the engine steps down one; "easy" and finished steps up one (inside the allowed range, never for scared/sad). Reason is stored in the decision trace.
* **3 new action games with obstacles, combos and power-ups:** Cloud Bounce (Kara; springs + storm-cloud obstacles), Fruit Slice Party (Nova; swipe, stinky-sock obstacles, snowflake slow-time power-up), Dance Party (Lumi; rhythm lanes, grey quiet-note obstacles). No game-over: a mistake only breaks the combo. 26 games in total; the 7 newest are listed first with a NEW tag in the Games tab. The 19 older games are unchanged and are still offered by the adaptive engine.
* Honest limit: "attractive" is my intent, not something I have seen on a screen. Art is emoji + painted shapes, and sound uses the existing effects. Real artwork and music would make a big difference.

# v15 increment
* 4 new games (carrot_catch, teddy_clinic, sky_flight, pet_care) with different mechanics; 23 games in total. Engine tables updated (offered only when the child is neutral/calm/happy, never when scared/sad/skipped - existing safety rule kept). Tests that count games updated 19 -> 23 and worlds 10 -> 14.
* Parent Summary card (`lib/insights/parent_summary.dart`) is now the first thing on the Insights tab: headline, what they enjoyed, what was tricky, how they said they felt, things to try, and (only if a rule observation is worth re-checking) a gentle "talk to someone" note. No diagnostic words (tested).
* Risk: the engine's activity choice can differ from v14 after the first pick because new games compete for ties; tests that assert an exact multi-step sequence (adaptive_engine_test.dart) may need adjusting after you run them.
* Still not compiled or played. Emoji are used for sprites; no new artwork files.

# v14 increment
Written, **not compiled** (no Flutter SDK reachable; see v13 note).
* Optional check-in answers saved per session: enjoyment (1-3), perceived difficulty (1-3), mid-game "enjoying?" (on the break screen), child "make it easier" requests. All skippable; the Next button never waits for them.
* Break screen (pause button) = break request; counted in `pausedCount`. Game never forces play to continue. "Make it easier" is honoured even in FIXED_BASELINE (child request overrides design) and is logged separately (`childEasierRequests`).
* Caregiver view: "What happened (observed)" card from `lib/insights/caregiver_summary.dart` - counts only, no interpretation, tested for banned wording.
* Export schema bumped to `mindy-export-v3` (4 new columns); Python `src/validate_export.py` checks it and refuses to model with < 30 children.
* **Removed a fabricated feature:** Reports tab used to show a hard-coded "routine blood test... within the typical range" explanation. It now says no service is connected.
* Not done: mid-play *timed* prompts (only on the break screen), richer emotion list (worried/nervous/uncomfortable - current picker has 5 states), check-in save retry UI, per-game run verification, live ML service.

# v13 increment (this prompt)
* Environment check: the Dart/Flutter SDK cannot be downloaded here (storage.googleapis.com, pub.dev and dl.google.com return 403 through the proxy). Compiling and running Flutter is therefore **impossible in this environment**, not merely skipped.
* Games tab (`lib/screens/game_library_screen.dart`): search box, category chips, favourites (stored on device, optional), responsive grid (SliverGrid, any number of games), empty state, scrolling. Pure filter `GameLibraryScreen.filterGames` + `test/game_library_test.dart` (written, not run).
* **Still missing against the latest prompt:** mid-game optional check-ins ("enjoying it?", "easier?"), post-play enjoyment/difficulty questions, saved-check-in retry/duplicate protection, caregiver summary view, live ML service (the Flutter<->Python link remains CSV export / report-JSON import; no backend exists), widget/navigation tests, per-game verification by running. Categories/duration/progress/resume on library cards are also not done.

# Implementation report (v12)
Done in code: accounts/consent/assent, per-child scoping, deletion, researcher role, neutral rule indicators (rules-v2) with data-quality checks, export schema `mindy-export-v2`, researcher overview. Not done: compilation, widget flow tests, 7 prompt-named extra games, trigger-type export column, journey resume, recommendation dismiss UI, encrypted storage, real consent text. See TESTING_AND_QA.md and RISK_REGISTER.md.

---
# Earlier (v11) report
# Implementation report (v11)

Honesty rule: **written, not compiled.** No Flutter SDK was available. Every "works" below means "code exists
and has a test written for it", not "I watched it run". Run `flutter pub get`, `flutter analyze`, `flutter test`
and fix any messages first.

## Added in v10 -> v11
* Support engine (`lib/games/support/support_engine.dart`) wired into every game through `GameSessionController`
  (help button, idle cue, escalation, logging). See HINT_AND_SUPPORT_POLICY.md.
* 9 new games (total 19): Sorting Stars (rule switching), Sleepy Fox (go/no-go), Jellyfish Catcher, Hero Shield,
  Rainbow Memory Quest, Turbo Car, Dino Dash, Honey Bee Collector, Bird Launcher. See CHALLENGE_DESIGN.md.
* Games tab (scrollable list of all 19, level slider, practice only; not stored).
* Rule-based indicators on the Insights tab (`insights/rule_indicators.dart`).
* New event types, new session summary fields and export columns.
* Tests: `support_and_games_test.dart`, `rule_indicators_test.dart` (+ updated counts).

## Brief vs reality
| Brief item | Status |
|---|---|
| 12+ different games | 19 registered with distinct mechanics. 10 older ones are simple/gentle; the 9 new ones have obstacles, rules, distractors, timing |
| Buddy's Daily Adventures (virtual pet), Superhero Rescue Mission, Road Rules Junior, Bubble Pop Focus, Ocean Treasure Explorer, Robot Pattern Builder, Friendship Garden Sorter | **Not built as named.** Closest equivalents exist: Sorting Stars (sorter with rule change), Bubble Pop Shooter, Pattern Power. Say so in your report |
| Hint ladder | Built, unit-tested (not run) |
| Fixed / adaptive / practice | Fixed + adaptive existed as study conditions (FIXED_BASELINE never changes difficulty, also blocks the "easier" step); practice is the Games tab |
| Library scrolls, every game reachable | `ListView` of all `GameType.values` (not run on a device) |
| Seeded challenges | Each game uses a fixed `Random(seed)`; same seed every session so sessions are comparable |
| Android emulator / analyze / tests | **Not run** |
| Per-game widget tests / integration tests | **Not written** (logic tests only) |
| Original art | Games use emoji and drawn shapes, not professional art |
| ML integrated in Flutter | No (see ML_INTEGRATION_STATUS.md) |

## Known weak points to check first
Compile errors (likely small: missing imports, types); `Text('...')` emoji look different per phone;
Bird Launcher drag feel; Turbo Car / Dino Dash speeds need play-testing; `GameLoop` games depend on `TickerMode`
for pause.
