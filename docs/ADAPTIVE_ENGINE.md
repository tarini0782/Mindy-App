# Adaptive engine (rule-based, not machine learning)

File: `lib/games/engine/adaptive_game_engine.dart` (pure Dart). Layer 1 chooses the activity by a suitability
score (emotion compatibility, recent mood response, engagement, performance fit, regulation need, gentle step-up,
minus previous-activity, repetition, recovery penalties). Safety rule: scared / sad / skipped check-in only get
calm activities. Layer 2 sets level 1-5: the emotion sets an allowed range; the activity's previous level moves by at
most one step, only after 2 same-activity or 3 overall consistent sessions; never Easy -> Hard in one move.
Study conditions: ADAPTIVE (activity + difficulty adapt), DIFFICULTY_ONLY and FIXED_BASELINE (predetermined
sequence; fixed level 3; no silent changes). Every decision stores a `DecisionTrace` (inputs, scores of all
activities, rule id, baseline level, modifier and reason, human-readable reason, timestamp, condition).
v11: the 7 new challenge games are in the suitability tables for neutral / calm / happy only.
Not stored: a separate decision UUID or algorithm-version field (the rule id is stored). Support-ladder
difficulty changes happen *during* play and are logged as `difficulty` events, separate from engine decisions.


## v22: variety
* Scared / skipped / sad pool: 8 low-arousal activities (was 2-3). Safety rule unchanged: these check-ins only receive this pool, level 1, slow pace.
* `alreadyThisAdventure` (-10) discourages repeating an activity inside one adventure; `novelty` (+1) favours never-tried activities. Both are components in the decision trace.
* Feed sessions (`trigger = feed`) are stored and synced but do not advance the adventure.
