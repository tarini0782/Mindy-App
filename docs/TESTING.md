# Testing

## The honest status

| Suite | Count | Executed? | Result |
| --- | --- | --- | --- |
| Python backend | 36 tests | **Yes** | All pass |
| Python analysis tools | pipeline run end to end | **Yes** | Runs correctly |
| `flutter analyze` | whole project | **Yes, 18 Oct 2026** | 142 → **15 issues, 0 errors, 0 warnings** (info-level style only) |
| `flutter test` | 28 test files | **Yes, 18 Oct 2026** | Run 1: 325 passed, 10 failed. Run 2: **333 passed, 4 failed**. All causes found and fixed; a third run has not been done here |

**The project compiles.** The first-ever `flutter analyze` run found 142 issues,
of which 20 were hard errors. All 20 are fixed (see below), along with the 3
warnings and about 110 of the information-level messages.

The Dart **tests** have still never been executed. **Do not quote them as
passing** until you have run `flutter test` yourself and seen the output.

### What the first compile found, and what was done

| Error | Cause | Fix |
| --- | --- | --- |
| `label`, `faceEmoji`, `title` undefined — `calm_quest_screen.dart` (8 errors) | Extension getters used without importing the libraries that define them | Added `models/emotion_state.dart` and `games/models/game_type.dart` imports |
| `MoodChange` undefined — `wellbeing_full_summary_screen.dart` (5 errors) | `MoodChange` lives in `models/emotion_state.dart`; the import was not carried over when this file was split out of the parent-summary screen | Added the import |
| `initialize`/`show` argument errors — `notification_service.dart` (7 errors) | The code called the plugin with named arguments; the real API takes them positionally | Rewrote both calls; the notification id is now masked to 32 bits, since a raw millisecond epoch overflows an Android notification id |

### First test run: 325 passed, 10 failed

Two of the ten were real product bugs. The rest were stale expectations or
faults in the tests themselves.

| Failure | Category | Cause and fix |
| --- | --- | --- |
| `signalsFor` leaked the child's name | **Real privacy bug** | The AI wording layer sent signal titles, details and action titles verbatim, and that wording is written for a caregiver, so it contains the child's nickname — which was going to a third-party LLM. `SupportPlan` now carries `childName`, and `signalsFor` strips it with `redactName()` (whole-word, case-insensitive). Two tests lock the property down |
| Demo seeder produced 0 sessions | **Real bug** | Session ids were `demo-<scenario>-<i>` with no child in them, and `SessionRepository.add()` silently returns on a duplicate id. Re-seeding the same scenario for a different demo child dropped all 15 sessions with no error. Ids are now `demo-<childId>-<scenario>-<i>` |
| `adaptive_engine_test`: expected 8 allowed activities, got 9 | Stale expectation | The calm pool grew to 9 when Firefly Jar was added in v27. Updated |
| `games_and_controls_test`: expected 2 regulation activities, got 3 | Stale expectation | Same cause. Updated, and the test's "twenty-six activities" title corrected to twenty-seven |
| Firefly Jar widget tests: "A Timer is still pending" ×2 | My test bug | The test constructs `GameSessionController` itself, and the controller owns a 1s idle timer and a 3s speech timer. The widget's dispose does not own it. Added `addTearDown(c.dispose)` |
| `pumpAndSettle` timed out ×4 (report split, avatar creator) | My test bug | Both screens contain a continuously looping animation — the mascot, and the avatar's idle bob — so the widget tree never settles and `pumpAndSettle` can never return. Replaced with explicit `pump()` frames |

### Second run: 333 passed, 4 failed

| Failure | Cause and fix |
| --- | --- |
| `games_and_controls_test`: expected 17 world keys and 26 ids | Two more counts left stale by Firefly Jar, which added both an 18th world (`firefly_meadow`) and a 27th id. The first run only surfaced the first assertion in the test; fixing it revealed the next |
| Firefly Jar: "A Timer is still pending" ×2, **again** | My first fix was wrong. `addTearDown` callbacks run *after* the framework's pending-timer check, so disposing there is always too late. The controller is now unmounted and disposed inside the test body |
| `wellbeing_report_split_test`: "Found 0 widgets with text containing Window by window" | The navigation worked — the assertion was impossible. That section sits far down a `ListView`, and Flutter does not build off-screen list children, so the finder could never see it. The test now asserts on the screen's first paragraph |

A lesson worth keeping: a stale count assertion hides the next one behind it,
so fixing counts is iterative. And `addTearDown` is the wrong tool for anything
the test framework validates at the end of the test body.

Warnings fixed: an unused import in `parent_hub_screen.dart`, and two
write-only fields (`_sinceSpawn` in Dino Dash, `_cell` in Calm Maze) that were
assigned but never read — the live values are `_spawnIn` and `_px`/`_py`.

Information-level fixes: ~90 `withOpacity` → `withValues(alpha:)`,
`WillPopScope` → `PopScope` (the old one breaks Android predictive back),
`onWillAccept`/`onAccept` → the `WithDetails` variants, `Matrix4.scale` →
`scaleByDouble`, two genuine `BuildContext`-after-await bugs, and assorted
`const` and style lints.

**Deliberately not fixed:** the two `Radio` `groupValue`/`onChanged`
deprecations in `usability_screen.dart`. Migrating to `RadioGroup` would raise
the minimum SDK to Flutter 3.32, and these are information-level only. Note
that `pubspec.yaml` now requires Dart 3.6 / Flutter 3.27 because of
`withValues`.

## Commands

```bash
# Dart - run these first, before trusting anything
flutter pub get
flutter analyze
flutter test

# one file
flutter test test/v28_study_mode_test.dart

# Python backend (these do pass)
cd backend && python3 -m unittest discover -p "test_*.py" -v

# Analysis tools
python3 tool/power_simulation.py
python3 tool/make_example_ratings.py       # invented demo data, labelled
python3 tool/analyse_ratings.py --ratings 'build/eval/example_ratings_SYNTHETIC_rater*.csv' \
                                --key build/eval/condition_key.csv
```

## What each Dart suite covers

| File | Covers |
| --- | --- |
| `v28_study_mode_test.dart` | The two evaluation parameters: that defaults preserve shipped behaviour, that the pool is respected in every condition, that the shared safety floor holds for every distressed check-in, that the study pool fixes both defects found in `fixedSequence` |
| `v28_avatar_test.dart` | Avatar model clamping and round-trip, per-child scoping, save/edit/delete, the cap on saved characters, that every preset renders, that the creator saves |
| `evaluation_harness_test.dart` | **A generator, not an assertion suite.** Produces the synthetic profiles and blinded rater sheets. Also asserts the sheet leaks no condition name and that no distressed profile is offered a non-calm activity |
| `v27_insight_summary_test.dart` | The AI wording layer: off by default, banned-term rejection client-side, caching, graceful failure on every error path |
| `firefly_jar_test.dart` | The Firefly Jar activity: registration, calm-pool membership, level scaling, that play completes and off-target taps never count as mistakes |
| `wellbeing_report_split_test.dart` | The parent summary is short, with the dense detail one tap away |
| `v26_support_plan_test.dart` | Support plan bands, signals, actions, and that no diagnostic wording appears |
| The other 21 files | Games, engine behaviour, persistence, accounts, consent, feed, calm corner, exports |

## Tests that exist to stop specific mistakes

These are worth knowing about, because they encode decisions rather than
mechanics:

- **No diagnostic language.** Output wording is asserted against a banned-term
  list. If someone later writes "shows signs of anxiety" into a caregiver
  string, a test fails.
- **The blinded sheet must not leak the condition.** The harness greps its own
  output for `ADAPTIVE`, `DIFFICULTY_ONLY` and `FIXED_BASELINE` and fails if it
  finds them.
- **A distressed check-in never gets a non-calm activity**, in any condition,
  once the shared safety floor is on.
- **Defaults preserve shipped behaviour.** The v28 parameters are tested to be
  no-ops when omitted, so the research changes cannot silently alter what a
  child experiences in normal play.
- **Saved characters are scoped per child**, so one child's avatar can never
  appear in another's app.

## Known gaps

- No golden/screenshot tests. Visual regressions in the new theme would not be
  caught automatically.
- No integration test that walks a full session end to end (check-in → play →
  check-in → stored → appears in the plan). This is the most valuable test
  still missing.
- Several games have no dedicated test; they are exercised only indirectly.
- `GameType.values.length` is asserted in two files. Adding an activity means
  updating both, which the compiler will not tell you about.
- The 36 Python tests cover the insight layer and server endpoints well, but
  there is no test of the SQLite schema under concurrent writes.

## When you run the Dart suite for the first time

Expect failures. The code has never been compiled, so the likely categories are
import paths, a missing `const`, an exhaustive-switch complaint after the new
`GameType`, and analyzer warnings from `analysis_options.yaml`. Send the exact
output rather than a summary — the error text names the file and line, and that
is what makes the fix quick.
