# Architecture

How Mindy fits together, and the rules that keep the research part testable.

## The one rule that shapes everything

**The decision engine is pure Dart.** `lib/games/engine/adaptive_game_engine.dart`
imports no Flutter, touches no storage, uses no randomness, and reads no clock
except a `now` passed into it. Identical inputs always produce an identical
decision.

That is why the engine can be replayed over synthetic histories, why the rater
study can be generated deterministically, and why an examiner can reconstruct
any decision from its stored trace. Keep it that way: if the engine ever needs
`DateTime.now()` or `SharedPreferences`, pass the value in instead.

## Layers

```
screens/        Flutter UI. Knows about services; never about engine internals.
   │
services/       State + persistence. ChangeNotifiers, singletons, local storage.
   │
insights/       Pure analysis over stored sessions. No UI, no storage.
games/engine/   The decision engine. Pure. No Flutter.
models/         Plain data: emotion, session, trace, study condition.
```

Dependencies point downwards only. `insights/` and `games/engine/` must never
import anything from `screens/` or `services/`.

## A session, end to end

```
 1  checkin_screen        child taps a feeling picture
 2  AdaptiveGameEngine    layer 1 picks the activity, layer 2 picks the level
                          -> GameRecommendation + DecisionTrace
 3  game_factory          maps GameType -> the activity widget
 4  GameShell             header, host character, pause, hint ladder, logging
 5  <activity>_game       the child plays; records touches, successes, timing
 6  checkin (after)       child taps how they feel now
 7  SessionRepository     the GameSession is stored locally
 8  insights/             SupportPlan and InsightsCalculator read the history
 9  support_plan_screen   the caregiver sees it, with its evidence level
```

## The decision engine

**Layer 1, which activity.** A suitability score per activity:

```
  emotionalCompatibility      how well the activity suits the reported feeling
+ recentMoodResponse          how this child felt after it before
+ engagementHistory           did they finish it, did they want to replay
+ performanceFit              was it the right stretch last time
+ regulationNeed              do recent sessions suggest they need calm
+ gentleStepUp                a soft step up after regulation helped
- previousActivity            never immediately repeat
- repetitionAvoidance         discourage recently played
- recoveryPenalty             the last attempt went badly
- alreadyThisAdventure        strongly discourage repeats within one journey
+ novelty                     small bonus for never-tried activities
```

**The safety rule comes first and is not a score.** A check-in of scared, sad
or skipped restricts selection to the calm pool, at the lowest level, at slow
pace. No score can override it.

**Layer 2, which level.** The reported emotion fixes an allowed level range.
Inside that range the activity's own previous level moves by at most one step,
and only on consistent evidence from at least two banded sessions of that
activity (or three overall). Never mid-session. Never for a distressed child.

**Every decision writes a `DecisionTrace`**: rule id, condition, journey step,
emotion and its source, previous activity and level, recent mood change,
engagement, the evidence sentence, the selection, the baseline level, the
modifier and why, a recovery flag, every activity's score components, a state
snapshot, and a human-readable sentence.

## Study conditions

| | ADAPTIVE | DIFFICULTY_ONLY | FIXED_BASELINE |
| --- | --- | --- | --- |
| Activity | scored | fixed sequence | fixed sequence |
| Level | adapts | adapts | constant |
| Feeling affects | both | level only | nothing |

Two **evaluation-only** parameters were added in v28, both defaulting to the
shipped behaviour so normal play is unchanged:

- `pool` — restricts selectable activities, in every condition. The rater study
  passes `AdaptiveGameEngine.studyPool` (nine activities).
- `equalSafetyFloor` — applies the distressed-check-in restriction in every
  condition, not only ADAPTIVE.

Why they exist: without the first, a measured difference could be explained by
ADAPTIVE having 27 activities against the baselines' 6. Without the second, the
baseline is deliberately less responsive to distress, which is both a confound
and an ethics problem. See `docs/RESEARCH_REPORT.md` §7.

## Activities

27 activities behind one `GameType` enum. Adding one means touching exactly
five places, and the compiler finds four of them for you:

1. the `GameType` enum
2. its `_Meta` entry (id, title, world, colours, instruction)
3. the `_roles` map (`ActivityRole`)
4. `buildGameBody()` in `game_factory.dart` — exhaustive switch
5. the reward-currency switch in `reward_service.dart` — exhaustive switch

Also update the `_compat` tables in the engine if the activity should be
reachable, and the two tests that assert `GameType.values.length`.

**Calm-pool rules**, enforced in every regulation activity: no timer, no
hazard, nothing expires or escapes, off-target taps log a neutral touch and
never a mistake, nothing can be failed.

## Characters

Two separate systems, deliberately:

- **Host characters** (`characters/character_id.dart`): the six fixed guides,
  one per world. Not customisable.
- **The child's avatar** (`characters/avatar.dart` + `avatar_painter.dart`):
  drawn entirely from shapes in a 100×120 space, stored as integer indices,
  persisted per child by `AvatarService`. No image assets, nothing copied from
  any commercial character.

## Storage

`SharedPreferences`, one JSON array per collection, versioned keys. See
`docs/DATA_AND_PRIVACY.md` for the database decision and the encryption gap.

## Theme

`CalmColors` holds the palette; `buildMindyTheme()` builds the `ThemeData`.
Screens reference the **token names**, never raw hex, so the whole app can be
re-themed by changing values in one file — which is exactly what v28 did.

Games are the exception: each activity carries its own bright colours in its
`_Meta` and does not read the app theme, so re-theming the shell never changes
how an activity looks to a child mid-study.
