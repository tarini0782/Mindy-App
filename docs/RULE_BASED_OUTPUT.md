# Rule-based output and novelty (v10)

## Why rule-based
No public dataset contains Mindy's games, so a trained model cannot be justified yet.
v10 therefore produces its **output from explicit IF-THEN rules** on the event log
(`lib/insights/rule_indicators.dart`). Every cut-off is a named constant (`IndicatorRules`),
every card shows its evidence and the rule used, and the Python pipeline in `mindy_ml`
can later test these rules against independent reference measures (paper SDQ).
Cut-offs are **engineering rules, not clinical thresholds**. Wording is "observed in play",
never a diagnosis.

## What is new (novelty claim, stated carefully)
1. **Check-in -> play -> check-in loop inside the game.** The child's feeling before play
   chooses the activity and level (safety rule: scared / sad / skipped only get calm
   activities; Sorting Stars and Sleepy Fox are never offered then). The feeling after play
   closes the loop and feeds the mood indicator.
2. **Classic child-development task designs inside cute games**, logged at event level:
   - *Sorting Stars* = rule switching (colour -> shape). Logs `rule_change`, `perseveration`.
   - *Sleepy Fox* = go / no-go. Logs `commission` (tapped the fox), `omission` (missed a friend).
   Same paradigms researchers use, but delivered as child-friendly play with a story character.
3. **One event schema for 12 games** (success, mistake, touch, response, commission,
   perseveration, omission, rule_change) so indicators and later ML work across games.
4. **Three study arms** (ADAPTIVE / DIFFICULTY_ONLY / FIXED_BASELINE) so adaptation can be tested.
5. **Practice is separated from research data**: the Games tab is free play, never stored.

Do not claim: clinical validity, that the games diagnose anything, or that these are the first
such games. The honest claim is a *design and a testable pipeline*.

## The six indicators (rules-v2, matches lib/insights/rule_indicators.dart)
Levels: Not enough information / Nothing stood out / Worth reviewing across additional sessions. At or above the cut-off = "worth reviewing".
| Indicator | Cut-off | Minimum evidence |
|---|---|---|
| Rule-change errors (Sorting Stars) | switch cost >= .15 | 2 sessions, 6 post-switch answers, 12 others |
| Tapping the fox (Sleepy Fox) | >= 30% | 6 fox items |
| Missed friends | >= 25% | 12 friend items |
| Response-time variability | sd/mean >= .60 | 3 sessions |
| Finishing activities | finished < 70% | 4 sessions |
| Feelings after play | mean change <= -0.4 | 4 sessions |
Cut-offs are engineering rules, not clinical thresholds.

## Evaluating the rules (the research part)
1. Pilot children play 5+ sessions (Sorting Stars and Sleepy Fox at least 3 each).
2. Parent completes the paper SDQ; researcher scores it by hand (do not enter it in the app).
3. Export Sessions/Events CSV (Researcher mode > Data), run `mindy_ml`:
   compare each indicator's level with the SDQ band (agreement, confusion table) and report
   honestly, including "no clear relation" outcomes.
4. Adjust thresholds ONLY on a separate set of children, never on the children you test on.

## Known limits
* With two boxes, a wrong sort after a switch is by construction the old rule's answer, so
  `perseveration` is "error early after a switch", not proof of rule perseveration.
* Response times include touch-travel time and device differences.
* Fox counts are derived from the level table (`FoxParams.foxCount`).
* Dart code was written without a Flutter SDK available: run `flutter pub get`,
  `flutter analyze`, `flutter test` first and fix any compile messages.
