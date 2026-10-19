# Game event schema (what the code actually stores)

Per event (compact list in JSON, one row in Events CSV): `[tMs, typeCode, valueMs]`.
`tMs` = ms of ACTIVE play since the game opened (monotonic Stopwatch, pauses excluded). Capped at 600 events.
Events CSV columns: sessionId, anonymousChildId, participantId, activity, level, studyCondition, eventIndex, tMs, type, valueMs.

| code | type | meaning | valueMs |
|---|---|---|---|
| 0 | success | right response | - |
| 1 | mistake | gentle error | - |
| 2 | touch | neutral tap / drag / launch | - |
| 3 | response | response time | ms |
| 4 | commission | tapped when told not to (Sleepy Fox) | - |
| 5 | perseveration | error in first 2 cards after a rule change (Sorting Stars) | - |
| 6 | omission | missed target / timeout | - |
| 7 | rule_change | game switched its rule | - |
| 8 | support | support offered | stage 1 cue, 2 hint, 3 demo, 4 easier, 5 break |
| 9 | difficulty | difficulty lowered | new level |
Not implemented: per-event UUIDs (use sessionId + eventIndex), game-specific detail strings, wall-clock timestamps per event
(session `timestamp` gives chronology). Response-time definition: shown/appears (or previous action) -> tap, measured on a
frame-ticked clock that freezes when paused (Memory Quest and Bee use DateTime).


## Session-level child answers (schema mindy-export-v3)
`enjoyment` 1 not fun/2 okay/3 fun; `perceivedDifficulty` 1 easy/2 just right/3 hard; `midGameEnjoying` true/false; `childEasierRequests` count. Empty = skipped. Older exports are `mindy-export-v2` (without these columns).


## `difficulty` event value
Value = level at that moment. Automatic or child-requested easier steps log the base level; flow-adaptation harder steps log level + number of harder steps so far (`harderSteps`).
