# Mindy: Research Report

**Project:** J26-IT-445, component IT23256682 (Nanayakkara T.M.)
**Module:** IT4010
**Report generated:** 18 October 2026, from the implementation in this repository.

> **Status of this document.** Every description of system behaviour below was
> written by reading the source in `lib/` and `backend/`. Every place where a
> research result would normally appear is marked **[PLACEHOLDER]**, because no
> study has been run. No results are invented, and no outcome is claimed.
>
> **Nothing in this repository has been compiled or executed**, because no
> Flutter SDK was available to the author of this report. See §13.

---

## 1. Introduction and problem statement

Children aged roughly 3–12 commonly experience distress around medical visits:
unfamiliar rooms, equipment and procedures, with limited ability to describe
what they feel in words. Caregivers are left with an impression ("she gets
scared at the doctor") that is hard to translate into anything a clinician can
act on, and hard to track over time.

Mindy is a Flutter application that addresses a narrow, tractable slice of this
problem. A child chooses how they feel from pictures, plays a short activity
selected for that feeling, and reports how they feel afterwards. Over repeated
sessions the app accumulates a record of what the child chose, what they played,
and how their self-reported feeling changed, and it presents that record to a
caregiver in plain language with the amount of supporting evidence stated.

**The problem this project actually addresses** is therefore not "detect
anxiety in children" but: *can a child's own repeated, picture-based emotional
self-report drive an explainable choice of activity, and produce a caregiver-
facing account that is honest about its own uncertainty?*

**What this project explicitly does not address.** It does not diagnose, screen
for, or detect any condition. It does not claim therapeutic effect. These are
not modesty statements; they are design constraints enforced in code and tests
(§12).

## 2. Aim and measurable objectives

**Aim.** To design, implement and evaluate an explainable, history-aware
adaptive system that selects emotional-preparation and coping activities for
children from their own repeated self-reported feelings, and reports the
resulting pattern to a caregiver without diagnostic claims.

**Objectives.**

| # | Objective | Status | Evidence |
| --- | --- | --- | --- |
| O1 | Implement a picture-based emotional check-in usable by young children | Implemented | `lib/screens/checkin_screen.dart`, `lib/widgets/emotion_picker.dart` |
| O2 | Implement a two-layer adaptive engine that selects activity and difficulty from the check-in and stored history | Implemented | `lib/games/engine/adaptive_game_engine.dart` |
| O3 | Record, for every decision, a machine-readable and human-readable reason | Implemented | `lib/models/decision_trace.dart` |
| O4 | Implement three study conditions permitting a controlled comparison | Implemented, with defects identified in §7 | `lib/models/study_condition.dart` |
| O5 | Produce a caregiver-facing account that states its own evidence level | Implemented | `lib/insights/support_plan.dart`, `lib/insights/insights_calculator.dart` |
| O6 | Evaluate recommendation appropriateness against fixed and difficulty-only baselines | Harness built, study not run | `tool/` (§11) |
| O7 | Evaluate usability with caregivers | Not done; requires approval | — |
| O8 | Establish whether the contribution is novel | Partially done; search incomplete | §3, §5 |

## 3. Background and related work (verified sources)

Only sources that were opened and checked are cited. Six are listed here; the
fuller review with counterevidence is in `docs/LITERATURE_REVIEW.md`.

**Preparing children for medical procedures.** Exposure-based treatment for
fear and reactivity to medical procedures has supporting evidence across 62
studies (1955–2021, 715 participants), with the target procedure completed in
about 70% of the 60 studies reporting it (Abdel-Jalil, Baldwin & Leaf, 2024).
Only 14 of those 62 studies involved children, and child-specific results are
not reported separately.

**Digital preparation specifically.** Liguori et al. (2016, *JAMA Pediatrics*
170(8):e160533) randomised 40 children aged 6–11 to a 6-minute tablet video
before elective surgery versus standard nurse-led information; anxiety on the
modified Yale Preoperative Anxiety Scale differed by 13.5 points on entering
theatre (p = .003). Almuqad et al. (2026, *JMIR Pediatrics and Parenting*
9:e92880) systematically reviewed 13 studies of digital storytelling, VR and AR
for preoperative anxiety, reporting a pooled benefit but rating most included
trials at high risk of bias, mainly from lack of blinding. **Both describe
single-session interventions delivered immediately before one procedure.**

**Game-based emotional support.** Fleming et al. (2017) argue applied games can
widen reach and engagement while noting few independent trials. Gonçalves,
Silva & Reis (2025) reviewed 37 studies of serious games for emotion regulation
in preschoolers, finding most target clinical groups and that games for 3–5
year-olds are scarce.

**Child self-report.** Venham & Gaulin-Kremer (1979, *Pediatric Dentistry*
1(2)) validated a picture-selection measure of situational anxiety in children
from age 3 (test–retest 0.70, KR-20 0.838), which is the closest published
precedent for Mindy's check-in design. von Baeyer (2006, *Pain Research and
Management* 11(3):157–162) sets the limit: faces-type self-report is well
supported from about age 4, but "as many as three-quarters" of typically
developing 3-year-olds may not understand a graded self-report task at all.

**Game-based behavioural assessment.** Kim et al. (2025, *JMIR Serious Games*
13:e73408) predicted the K-WISC-V Processing Speed Index from 25 minutes of
serious-game play in children with ADHD aged 6–13 (59 analysed), reducing 140
behavioural variables to six and reaching RMSE 10.07 with an ensemble model.
This is directly relevant: it is what gameplay-based assessment looks like when
done properly, and it required a clinical sample and a validated reference
instrument.

## 4. Existing approaches and their limitations

| Approach | Example | Limitation relative to this project |
| --- | --- | --- |
| Single-session digital preparation | Liguori et al. 2016 | One viewing before one procedure; nothing adapts, nothing accumulates, no caregiver record |
| Immersive distraction (VR/AR) | Almuqad et al. 2026 (13 studies) | Delivered at the point of procedure; requires hardware; high risk of bias in the evidence base |
| Serious games for emotion regulation | Gonçalves et al. 2025 (37 studies) | Mostly clinical populations; little co-design; not tied to medical preparation |
| Game-based behavioural assessment | Kim et al. 2025 | Requires a clinical sample and a validated reference measure, which this project does not have |
| Dynamic difficulty adjustment | Souza et al. 2025 (34 studies) | Adapts to performance, not to how the child says they feel |

## 5. Research gap and proposed contribution

**The gap, stated as narrowly as the evidence allows.** Digital preparation for
children's medical procedures is established but single-session. Game-based
emotion-regulation work is established but rarely tied to medical preparation.
Difficulty adaptation is mature but keyed to performance rather than reported
feeling. Game-based behavioural assessment is established but requires clinical
reference data.

**Candidate contribution.** A repeated-session system in which (a) the child's
own reported feeling is the governing input to activity selection, (b) an
explicit safety restriction takes precedence over any optimisation, (c)
gameplay-derived features are held as descriptive context rather than being
required to be predictive, and (d) every recommendation records a reason a
caregiver can read and an examiner can reconstruct.

**This is a candidate, not an established absence.** The prior-art search has
covered PubMed/PMC, JAMA, JMIR, arXiv and general web indexes. It has **not**
covered IEEE Xplore, ACM Digital Library, PsycINFO, Scopus, Web of Science or
the Cochrane Library, and no commercial hospital-preparation products have been
examined. **[PLACEHOLDER: complete the remaining database searches and revise
this section before claiming novelty.]**

## 6. System overview and architecture

Full detail in `docs/ARCHITECTURE.md`. In summary:

```
Child check-in (pictures)  ─┐
Stored session history     ─┼─►  AdaptiveGameEngine  ─►  Activity + level + pace
Gameplay performance bands ─┘         │                        │
                                      ▼                        ▼
                               DecisionTrace            GameSessionController
                            (reason, scores, rule)      (plays, logs events)
                                      │                        │
                                      └────────┬───────────────┘
                                               ▼
                                     SessionRepository (local)
                                               │
                        ┌──────────────────────┼────────────────────┐
                        ▼                      ▼                    ▼
                  SupportPlan          InsightsCalculator     Export / sync
              (caregiver actions)    (evidence-gated windows)  (research use)
```

Layers, as implemented:

- **Layer 1 — which activity.** A deterministic suitability score per activity:
  `emotionalCompatibility + recentMoodResponse + engagementHistory +
  performanceFit + regulationNeed + gentleStepUp − previousActivity −
  repetition − recoveryPenalty`, constrained first by a safety rule.
- **Layer 2 — which difficulty.** The reported emotion fixes an allowed level
  range; within it the activity's previous level moves by at most one step, and
  only on consistent evidence from at least two prior banded sessions of that
  activity (or three overall).
- **Determinism.** The engine is pure Dart with no clock except an injected
  `now`, no randomness and no I/O. Identical inputs always produce an identical
  decision, which is what makes replay-based verification possible.

**Safety rule (the project's central design commitment).** A check-in of
*scared*, *sad*, or *skipped* restricts selection to a calm pool of activities
at the lowest level and slow pace. Comfort takes precedence over any score.

## 7. The adaptive engine and the three study conditions

| | ADAPTIVE | DIFFICULTY_ONLY | FIXED_BASELINE |
| --- | --- | --- | --- |
| Activity chosen by | Suitability score | Fixed sequence | Fixed sequence |
| Level chosen by | Emotion range + ≤1 performance step | Emotion range + ≤1 step | Constant (level 3) |
| Reported feeling affects | Activity and level | Level only | Nothing |
| Reason recorded | Full score components | Condition + level reason | Condition statement |

**Three defects in this comparison, identified by code inspection.** These are
reported rather than silently fixed, because two of them require supervisor
approval to change (§12).

1. **Unequal activity pools.** ADAPTIVE scores all 27 activities;
   the other two cycle a 6-item `fixedSequence`. A measured difference could
   therefore reflect content variety rather than adaptation.
2. **Unequal safety floor.** `FIXED_BASELINE` returns level 3 and the next
   sequence item regardless of a scared, sad or skipped check-in, while
   ADAPTIVE restricts those cases to the calm pool at level 1. This is both a
   confound and an ethics problem: the baseline is deliberately less responsive
   to distress, and randomising a distressed child into it would not be
   defensible.
3. **Level adaptation may never fire in a short study.** A level step requires
   two consistent banded sessions of the same activity (or three overall), and
   Breathing Garden produces no performance band at all. With too few sessions
   per profile, DIFFICULTY_ONLY cannot diverge from FIXED_BASELINE and the
   corresponding hypotheses become untestable by construction.

**Verification of the proposed six-activity study pool.** `fixedSequence`
contains Bubble Valley, Feelings Memory, Breathing Garden, Pattern Power,
Rainbow Puzzle and Calm Maze. Checked against the engine source: it contains
**no medical-familiarisation activity** (Teddy Clinic is not in it), and only
**three** of the six are members of the calm pool. A study restricted to those
six would never offer a medical activity, and all conditions would face the
same three options whenever the check-in is restricted. The evaluation harness
therefore uses a **nine-activity study pool** (the six plus Teddy Clinic,
Firefly Jar and Sleepy Fox).

## 8. The 27 activities and the role of each

Techniques are assigned from what each activity's code actually does. An
activity is **not** labelled with a therapeutic technique its content does not
support.

| Technique | Activities | Count |
| --- | --- | --- |
| Paced breathing (real timed inhale/hold/exhale cycle) | Breathing Garden | 1 |
| Emotional awareness (content is explicitly about naming feelings) | Feelings Memory | 1 |
| Medical familiarisation (clinic objects, roles, ordered care steps) | Teddy Clinic | 1 |
| Calming distraction (no timer, no hazard, nothing expires, child-paced) | Firefly Jar, Calm Maze, Puffy's Day | 3 |
| Attention and self-control practice (go/no-go, rule switching) | Sleepy Fox, Sorting Stars | 2 |
| Engagement play (no technique claimed) | Bubble Valley, Pattern Power, Rainbow Puzzle, Bubble Pop Shooter, Happy Connect, Cloud Hop, Peekaboo Pals, Jellyfish Catcher, Hero Shield, Rainbow Memory Quest, Turbo Car, Dino Dash, Honey Bee, Bird Launcher, Carrot Catch, Sky Flight, Cloud Bounce, Fruit Slice, Dance Party | 19 |

**The content gap, stated plainly.** One activity in twenty-seven contains
medical content. If the approved title claims medical-visit preparation, this
is the project's clearest weakness. Relabelling cannot fix it; only new content
can. A minimum credible addition is specified in the evaluation plan
(check-up sequencing, coping-plan rehearsal, waiting-room familiarisation) and
is **not implemented**, pending the supervisor's decision on the title.

**Calm-pool design rules** (enforced across every regulation activity): no
timer, no hazard, nothing expires or escapes, off-target taps are logged as
neutral touches and never as mistakes, and no activity can be failed.

## 9. Data collection and storage

**What is stored per session** (`lib/games/models/game_session.dart`): session
id, pseudonymous child id, activity, level, difficulty label, pace, study
condition, decision trace, start time, emotion before/after, emotion source,
check-in duration, completion flag and percent, successes, mistakes,
interactions, pause count, duration, mean response time, response-time
variability, replay answer, perceived difficulty, load time, sync status.

**Where it is stored.** Locally, in `SharedPreferences`, as a single JSON
array under the key `mindy_sessions_v7`; caregiver observations under
`mindy_observations_v7`. An optional Python backend (`backend/`, standard
library only, SQLite) accepts synced copies for research use. The device copy
is the source of truth.

**Identifiers.** Pseudonymous participant codes only. Birth year only, no full
date. No location, no contacts, no advertising identifiers, no photographs
except the caregiver's own optional report image, which is not transmitted.

**Database recommendation: keep the existing storage (Option A).** Evidence and
reasoning in `docs/DATA_AND_PRIVACY.md` §Database decision. In summary: the
entire local dataset is a few hundred JSON objects per child; no query beyond
"all sessions for this child" is performed anywhere in the codebase; and
`shared_preferences` is already a dependency. Introducing SQLite would add a
plugin, a schema, a migration path and a failure mode, in exchange for query
capability nothing uses. **The one genuine deficiency is that the local store is
unencrypted**, which is an ethics blocker (§12), and which a database change
alone would not fix.

## 10. Synthetic-data evaluation methodology

Because no ethics approval exists and no child may be approached, the
evaluation uses synthetic child profiles and adult raters. This evaluates
**recommendation appropriateness only**.

- **Profiles.** A factorial design crossing current check-in (scared, sad,
  neutral, calm, happy, skipped) × history length (short/long) × recent
  trajectory (improved vs unchanged-or-worse) = 24 profiles. Long histories
  carry enough completed, banded sessions to let a level step fire.
- **Runner.** Each profile is run through all three conditions at the same
  journey step; recommendation and full trace are captured.
- **Blinding.** Condition labels stripped, presentation order randomised per
  profile under a recorded seed; the key is written to a separate file.
- **Rubric.** Three 5-point anchored items (activity suitability for the
  reported feeling; level suitability for the history; caregiver comfort), plus
  one forced choice per profile.
- **Primary outcome.** The three-item composite, ADAPTIVE vs FIXED_BASELINE,
  with a pre-specified internal-consistency check (α ≥ 0.7) and a fallback to
  item 1 alone.
- **Analysis.** Per profile, average over raters within condition, then a
  within-profile paired Wilcoxon signed-rank test. Profile and rater main
  effects cancel inside the paired difference by design. Sensitivity: a
  cumulative-link mixed model on raw ordinal ratings with crossed random
  intercepts for profile and rater.

**All generated profiles and example outputs are labelled
`SYNTHETIC / DEVELOPMENT DATA — NOT REAL PARTICIPANT DATA`.**

## 11. Evaluation measures and statistical analysis plan

**Power (simulated, not quoted from a rule of thumb).** Ratings simulated on
the 1–5 composite with residual SD 0.7 and profile-by-condition SD 0.3; 20,000
runs per cell; α = .05 two-tailed. `tool/power_simulation.py` reproduces this.

| True difference | 3 raters, 24 profiles | 5 raters, 24 profiles | 3 raters, 36 profiles | 5 raters, 36 profiles |
| --- | --- | --- | --- | --- |
| 0.25 points | 0.42 | 0.57 | 0.60 | 0.75 |
| 0.40 points | 0.81 | 0.93 | 0.94 | 0.99 |
| 0.50 points | 0.94 | 0.99 | 0.99 | 1.00 |
| 0.75 points | 1.00 | 1.00 | 1.00 | 1.00 |

**Consequence for the design.** With 24 profiles and 3 raters the study detects
a difference of roughly 0.4 composite points or larger; a 0.25-point difference
is missed more often than not. Raters buy more power than profiles do.
**Recruit 5 raters; if only 3 are available, use 36 profiles.**

**Multiplicity.** One primary comparison (H1) unadjusted; H2, H3 and all
forced-choice contrasts form a Holm-corrected secondary family.

**Reporting.** Effect sizes with bootstrap confidence intervals throughout, plus
inter-rater agreement (Krippendorff's α for the ordinal items, Fleiss' κ for the
forced choice). Agreement below ≈0.4 means the rubric is not measuring anything
stable and must be reported as such.

**Four claims, kept separate.** Software correctness; recommendation
appropriateness; caregiver usability; child benefit. Only the first two are
reachable in this project. **Adult ratings of synthetic scenarios cannot
establish that any child felt better, was readier for a visit, or was less
anxious.**

**[PLACEHOLDER: results. No ratings have been collected.]**

## 12. Privacy, ethics, limitations and future work

**Implemented safeguards.** Pseudonymous codes; birth year only; caregiver gate
on all adult screens; per-child deletion; practice play excluded from the
research record; synthetic demo data labelled in the UI; non-diagnostic output
wording enforced by tests; a banned-term validator applied on both the server
and the client to any AI-generated text, covering diagnostic and clinical
vocabulary.

**Required before any participant contact** (none of this is done):

- Institutional ethics approval, with protocol, information sheets and a
  written distress procedure
- Caregiver informed consent **and** separate child assent, revisited rather
  than taken once
- A data protection impact assessment
- **Encryption at rest** — not implemented; the local store is plain JSON
- Native-speaker review of the Sinhala and Tamil text, currently drafts
- Consent wording covering the optional AI paragraph, which transmits
  aggregated numbers to a third-party service and is absent from the current
  consent screen
- A stated retention and destruction schedule

**Limitations.**

1. No real participant data exists; nothing in this repository has been
   evaluated with a child.
2. The worry picture scale is a prototype, not a validated instrument.
3. Thresholds and weights in the engine are engineering choices, not clinical
   norms, and are labelled as such in the source.
4. Mindy's stated age range starts at 3, which is precisely where picture-based
   self-report is least reliable (von Baeyer, 2006).
5. Behavioural features are not comparable across activities: a response time
   in Fruit Slice and one in Rainbow Puzzle measure different things. Any
   analysis must stay within an activity or use features defined identically
   across a named subset.
6. The literature search is not systematic and is incomplete (§5).
7. **Nothing has been compiled or run** (§13).

**Future work.** Complete the database searches; run the rater study; obtain
ethics approval; add medical-familiarisation content if the title retains that
focus; implement encryption at rest; and only then consider whether behavioural
features relate to any external measure — which would require a clinical sample
and a validated reference instrument, as Kim et al. (2025) demonstrates.

## 13. Testing and implementation results

**Python backend — executed and passing.** 36 tests across
`backend/test_insight_summary.py` (25) and `backend/test_server.py` (11),
covering configuration loading, prompt construction, output validation, the
never-raises contract of `generate_summary()`, and real HTTP round-trips
against the running server. These were run and passed.

**Dart/Flutter — written, never executed.** 26 test files exist under `test/`.
**No claim is made that they pass.** No Flutter or Dart SDK was available in the
environment where this code was written, so every Dart change has been reviewed
by reading only.

Before relying on anything Dart in this repository, run:

```
flutter pub get
flutter analyze
flutter test
```

and treat the output as authoritative over any statement in this document.

**[PLACEHOLDER: paste the output of `flutter analyze` and `flutter test` here,
with the count of passing and failing tests.]**

**A defect found and fixed by inspection during this work**, recorded as an
example of the review process: the Firefly Jar activity populated its initial
state by calling a `setState`-wrapped method directly inside `initState()`,
which Flutter disallows because `initState` runs during the parent's build
phase. It was changed to mutate the field directly. This would have thrown at
runtime on first opening that activity.

## 14. References

1. Abdel-Jalil, M., Baldwin, J. L., & Leaf, J. B. (2024). A systematic review of the literature on exposure-based treatments for fear and reactivity to medical procedures. *Behavioral Interventions, 39*(3). Synopsis: https://asatonline.org/research-treatment/research-synopses/exposure-based-treatments/
2. Almuqad, F. A., Alsaedi, G. T., Alahmadi, T. A., Alalawi, S. I., Mulla, R. M., Almohammadi, R. M., & Abulfaraj, M. (2026). Effectiveness of digital storytelling and immersive technology interventions in reducing preoperative anxiety among children: systematic review and meta-analysis. *JMIR Pediatrics and Parenting, 9*, e92880. https://pmc.ncbi.nlm.nih.gov/articles/PMC13490931/
3. Fleming, T. M., et al. (2017). Serious games and gamification for mental health: current status and promising directions. *Frontiers in Psychiatry, 7*, 215. https://frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2016.00215/full
4. Gonçalves, C., Silva, E., & Reis, L. P. (2025). A systematic review of serious games for training emotion regulation skills in preschool children. *European Conference on Games Based Learning, 19*(1), 322–328. https://api.crossref.org/works/10.34190/ecgbl.19.1.4147
5. Kim, J.-S., et al. (2025). A novel approach using serious game data to predict the WISC-V Processing Speed Index in children with ADHD: machine learning study. *JMIR Serious Games, 13*, e73408. https://games.jmir.org/2025/1/e73408
6. Liguori, S., Stacchini, M., Ciofi, D., Olivini, N., Bisogni, S., & Festini, F. (2016). Effectiveness of an app for reducing preoperative anxiety in children: a randomized clinical trial. *JAMA Pediatrics, 170*(8), e160533. https://jamanetwork.com/journals/jamapediatrics/fullarticle/2528515
7. Souza, C. H. R., Nascimento, D. F., Berretta, L. O., & Carvalho, S. T. (2025). Solutions for dynamic difficulty adjustment in digital games: a systematic literature review. *Entertainment Computing, 55*, 101041. https://repositorio.bc.ufg.br/items/36654b2c-0c40-4a08-8d21-8ff7f53765c4
8. Venham, L. L., & Gaulin-Kremer, E. (1979). A self-report measure of situational anxiety for young children. *Pediatric Dentistry, 1*(2). https://www.aapd.org/globalassets/media/publications/archives/venham-01-02.pdf
9. von Baeyer, C. L. (2006). Children's self-reports of pain intensity: scale selection, limitations and interpretation. *Pain Research & Management, 11*(3), 157–162. https://pmc.ncbi.nlm.nih.gov/articles/PMC2539005
10. Zheng, Y., Li, R., Li, S., Zhang, Y., Yang, S., & Ning, H. A review on serious games for ADHD. arXiv:2105.02970. https://arxiv.org/pdf/2105.02970
11. Information Commissioner's Office (2020). Age Appropriate Design Code (secondary summary). https://www.scl.org/10795-ico-publishes-final-version-of-age-appropriate-design-code/

All links were opened and checked between 14 and 18 October 2026.
