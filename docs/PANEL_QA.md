# Panel Q&A: honest answers (J26-IT-445, mobile game platform component)

## Q1. "Will you decide a child's mental health from these games?"
**No, and the app does not.** Mindy produces *behavioural indicators for review*, never a diagnosis.

Why a handful of games cannot decide anything on their own:
* One short session is noisy: tiredness, mood, hunger, device, time of day and age all change play.
* There are no age norms yet, so "slow" or "many errors" has no reference point.
* Whether a game measures a trait (attention, impulsivity, flexibility) is an open validity question, not an assumption.

What Mindy actually reports: what the child did and said, how much evidence there is, and other possible reasons. Wording is fixed to "Not enough information / Nothing stood out / Worth reviewing across additional sessions".

**Suggested wording for your sub-objective in the viva:** "to capture gameplay behaviour that may be associated with attention, impulsivity, compulsive-like repetition and stress, and present it as an *indicator for professional review*". Avoid "screen for ADHD / OCD": no tool here can, and an ethics board will challenge it.

## Q2. "What would make a risk indicator defensible?"
A model is only a risk indicator after it has been checked against an outside measure. Plan (needs ethics approval first):
1. **Criterion labels** from an established parent/teacher questionnaire or clinician rating, chosen with the clinical supervisor (check licensing; the app does not reproduce any questionnaire).
2. **Several sessions per child** so reliability (does the same child score similarly twice?) can be checked.
3. **Child-level splits** (all sessions of a child in train *or* test), already enforced in `mindy_ml`.
4. **Report** AUC with a confidence interval, sensitivity/specificity, calibration, and compare with an age-only baseline. If the game features do not beat age alone, say so.
5. **Minimum sample:** the pipeline refuses to model fewer than 30 children. A final-year pilot realistically supports *feasibility, reliability and a preliminary association*, not diagnostic accuracy. Claim that, not more.
6. **Human in the loop:** output is a flag for a clinician or caregiver, never an automated decision.

## Q3. "Where is the machine learning?"
Rule-based and explainable now (`rules-v2`, every cut-off visible). The Python pipeline (`mindy_ml`) is ready and tested, and trains only on real, consented, labelled data. The current models in the repo are trained on synthetic development data and are bannered as such. No real child data has been collected.

## Q4. "What is the novelty?"
See the literature review. In short: an explainable per-child loop linking the child's own before/after feelings to the activity type, adapting activity and level from it, delivered in a swipe feed plus an adventure, with caregiver output that states its evidence. A prior-art check must be repeated before the viva.

## Q5. "Why did the adventure repeat the same game?" (fixed in v22)
When a child said scared or sad, the engine allowed only 2-3 calm activities, so a six-step adventure had to repeat. Now: eight low-arousal activities in that pool, a strong penalty for any activity already played in the same adventure, and a small bonus for never-tried activities. Tests check a full six-step adventure has no repeats for scared, sad and neutral. The low-arousal pool was chosen by design and needs review by the clinical supervisor.

## Q6. "How does your app fit the whole project?"
See `INTEGRATION_CONTRACT.md`. Mobile app: swipe feed + adventure + Calm Corner + caregiver insights + report/X-ray/skin question screen (client for the VQA backend) + reminders. Robot: posts emotion check-ins the app reads. Backend: stores sessions and serves the VQA endpoint.

## Q7. Limits to state yourself
No ethics approval yet; no real data; game-to-construct mapping is design intent; no age norms; consent text is a placeholder; local storage is not encrypted; low-arousal pool and report wording not clinically reviewed; VQA output depends on a model this app does not contain.
