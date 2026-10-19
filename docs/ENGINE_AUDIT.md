# Engine and reporting audit

**Date:** 18 October 2026. **Method:** reading the source in `lib/`, not the
previous documentation. Where this contradicts an earlier doc, this is right.

> **Environment limitation, stated plainly.** No Flutter or Dart SDK exists in
> the environment where these changes were written. **Nothing below has been
> compiled or run here.** Your last local result (`flutter analyze`, 15 info
> issues, 0 errors; `flutter test`, 4 failures since fixed) is the baseline to
> protect. Local validation is still required — commands in §6.

---

## 1. Audit table

| Component | Actual implementation | Evidence in code | Current weakness | Proposed improvement | Regression risk |
| --- | --- | --- | --- | --- | --- |
| Activity eligibility | A per-emotion `_compat` map; a key's presence means eligible | `adaptive_game_engine.dart` `_scoreAll`, `allowed` | Exclusion records only `allowed: false` — not *why* (emotion bucket? pool? both?) | Record an exclusion reason per candidate | Low, additive to the trace |
| Candidate scoring | 11 additive components, already weighted as literals | `_scoreAll` | Weights are baked into the values, so no separate weight/feature view; a formula change is invisible to history | Version the weight set; keep defaults | Medium — touches the trace schema |
| Tie-breaking | Highest total, then fewest plays, then enum order | `_select` | Deterministic but **not recorded**. A tie-broken choice looks identical to a clear win | Expose it (done, read-only, in `DecisionExplanation.decidedByTieBreak`) | None — derived, no model change |
| Fallback when nothing is eligible | Returned `GameType.breathingGarden` unconditionally | `_select`, floored branch | **Escaped a restricted pool.** Breaks the guarantee the study comparison rests on | **Fixed:** fall back inside the pool | Low, covered by a new test |
| Difficulty step | ±1 max, needs 2 consistent banded sessions of that activity (or 3 overall) | `_levelFor` | Sound. But see the band bug below | None | — |
| Performance bands | Accuracy-based, from successes/mistakes | `game_session.dart` `performanceBand` | **Calming activities earned bands.** `hasPerformanceData` excluded only Breathing Garden by name | **Fixed:** keyed off `isRegulation`; band returns null | Low; only Firefly Jar changes behaviour |
| Missing features | Absent evidence becomes `0` | `_scoreAll` (`deltas.isEmpty ? 0`) | 0 means both "no evidence" and "neutral evidence". Defensible, but undocumented and untested | Document; add a test pinning the intent | Low |
| Decision trace | Rich: rule id, components, totals, state snapshot, human sentence | `decision_trace.dart` | Nothing *read* it. A trace nobody renders is not an explanation | **Added** `DecisionExplanation` | None — read-only |
| Replay | `stateSnapshot` is stored | `_build` | No test reconstructs a decision from a stored trace | Replay test | Low |
| Duplicate sessions | `add()` returns early on a duplicate id, silently | `session_repository.dart` | A silent drop already caused the demo seeder to store nothing | Already fixed at the id level; the silent drop itself remains | Medium if changed — leave for now |
| Caregiver report | Short plain screen + full detail screen | `wellbeing_*` | Per-session facts and a longitudinal timeline are still missing | Stage 3 | — |
| Indicator 7 "after a slip" | Error rate in 3 attempts after a mistake vs all others | `rule_indicators.dart` `recovery` | Overlapping windows: a mistake inside the window restarts it, so clustered errors are counted in the "after" group repeatedly | Reviewed below (§3) | — |

## 2. The three highest-impact weaknesses

### W1. A calming activity could raise its own difficulty — **fixed**

`hasPerformanceData` was `this != GameType.breathingGarden`: one game excluded
by name. But **every** regulation activity follows the calm-pool rule that
nothing can be failed, so none of them ever calls `recordMistake()`. Firefly
Jar records only successes, so `accuracy` was always 1.0 → `PerformanceBand.high`
on every completed session → two of those read as "consistently smooth play"
→ a difficulty step up on an activity whose entire purpose is to be
undemanding.

This was introduced with Firefly Jar in v27 and has existed since.

Fix: `hasPerformanceData => !isRegulation`, and `performanceBand` returns null
for such activities regardless of the raw numbers. Keying it off the role
means any future regulation activity is excluded automatically.

### W2. A fallback could leave the candidate pool — **fixed**

Both fallbacks returned `GameType.breathingGarden` unconditionally. With the
study pool restricted (the v28 evaluation parameter), a fallback could return
an activity outside the pool — silently breaking the one guarantee the
three-condition comparison depends on. Low probability, total impact: it
would invalidate the comparison without any error.

Fix: both fallbacks now pick inside the pool when one is set.

### W3. The engine explained itself to nobody — **addressed**

The trace recorded everything needed (per-candidate components, totals,
rule id, modifier reason) and **nothing read it**. The caregiver saw a
sentence; the researcher saw nothing at all.

`lib/insights/decision_explanation.dart` derives, from the stored trace only:
the winner, the real runner-up, the components that actually differed and by
how much, whether the tie-break decided it, what would have to change before
the level moves again, the full ranking for a researcher, and — importantly —
what the trace **cannot** answer.

It computes nothing itself, so it cannot drift from the engine's reasoning.

## 3. Review of indicator 7, "What happened after a slip"

Audited as required, before being relied on.

**Definition as implemented:** a mistake opens a window of the next 3
attempts; those attempts form the "after" group, everything else the
baseline; the indicator reports the error-rate difference and the median
pause before the next attempt.

**Known methodological weaknesses, documented rather than hidden:**

1. **Overlapping windows.** A mistake inside the window restarts it, so a run
   of errors keeps the window open and those errors land in the "after"
   group. This *inflates* the after-rate when errors cluster — which is the
   exact pattern the indicator claims to detect. The measure is therefore
   partly circular.
2. **Baseline contamination.** The baseline is "everything else", which
   includes attempts just *before* a mistake — often the hardest part of a
   session.
3. **Cross-game pooling.** Attempts are pooled across activities with
   different difficulty curves.
4. **Session boundaries** are respected (windows do not cross sessions), and
   the minimum evidence is 2 sessions, 6 after-attempts and 12 others.

**Recommendation:** keep it as a descriptive observation with these
limitations stated, or move to a non-overlapping definition (first N attempts
after a mistake, excluding any that follow a further mistake). That is a
research-design change, so it is **not** made here — see §5.

It must never be renamed resilience, frustration tolerance, or persistence.
It describes play.

## 4. What changed in this pass

| File | Change | Test |
| --- | --- | --- |
| `lib/games/models/game_type.dart` | `hasPerformanceData` keyed off `isRegulation` | `v29_engine_audit_test.dart` W1 |
| `lib/games/models/game_session.dart` | `performanceBand` returns null with no right/wrong moments | W1 |
| `lib/games/engine/adaptive_game_engine.dart` | Both fallbacks respect the pool; `_select` takes the pool | W2 |
| `lib/insights/decision_explanation.dart` | **New.** Explanation derived from the real trace | W3 |
| `test/v29_engine_audit_test.dart` | **New.** 12 tests across the three weaknesses plus determinism | — |

Not changed: any game's mechanics, event names, event ordering, scoring,
Sleepy Fox's go/no-go semantics, Sorting Stars' rule switching, the game
count, or default normal-play behaviour.

## 5. Decisions that need your supervisor, not me

1. **Indicator 7's window definition** (§3). Overlapping windows make the
   measure partly circular. Changing it changes what the indicator means.
2. **Whether gameplay performance stays in activity scoring.** It is still
   used in `performanceFit` and the level step. Audited, not removed.
3. **Weight-set versioning.** Needed before any weight changes, or historical
   decisions stop being interpretable. Not started.
4. **Whether the baseline keeps the shared safety floor** (from the earlier
   evaluation plan) — still open.

## 6. Local validation, still required

```
cd C:\mindy_app
flutter analyze
flutter test
flutter test test/v29_engine_audit_test.dart
flutter test test/v29_demo_indicators_test.dart
```

Expect W1's fix to change one thing you can see: Firefly Jar sessions no
longer report a performance band, so any existing display of "smooth play"
for that activity will go quiet. That is the correct behaviour.

## 7. Still outstanding from the brief

Stage 3 (per-session summary, longitudinal timeline, indicator detail view)
and Stage 4 (replay test, expanded synthetic profile matrix, hand-calculated
score tests) are **not** done. The brief's own working method is to stop
after each stage and wait for local test results, which is what this is.
