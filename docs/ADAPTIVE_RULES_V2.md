# Adaptive rules from how the child plays — specification

Covers reaction speed, response variability, hesitation, error reactions,
obstacle responses, and the feeling-versus-play rule.

**How to read the Status column.** *Implemented* means it is in the code
today. *Proposed* means it is specified here and not built. *Needs
approval* means building it would change the approved research design and
is your supervisor's decision, not mine.

> **Nothing in this file is a diagnostic instrument.** Every rule below
> describes an interaction with a game. The literature is cited to show
> the measures are not invented, not to claim Mindy measures the same
> construct a validated instrument measures. Cut-offs are engineering
> defaults and are unvalidated until you validate them.

---

## 0. The finding that shapes section D

The rule you asked for — *scared but playing well → make it harder* —
runs against the single most relevant piece of theory here.

**Attentional Control Theory** (Eysenck, Derakshan, Santos & Calvo, 2007)
predicts that anxiety impairs **processing efficiency** more than
**performance effectiveness**. Accuracy is largely preserved; what costs
is time and effort. A follow-up summary puts it plainly: anxiety "is more
likely to impair processing efficiency, rather than performance
effectiveness" (Edwards & Edwards, 2018).

So *scared but accurate* is the **expected** anxious profile, not evidence
that the child is fine. It is the signature of a child working harder to
hold the same standard. Responding to it by increasing demand is the
opposite of what the theory implies.

There is also a structural obstacle in your own code. `levelRange(scared)`
returns `(1, 1)` — floor equals ceiling. Every level change is clamped
into that range, so for a scared child the step is **arithmetically
impossible** without changing the safety rule your reviewer approved. That
rule is not incidental; it is the thing that makes the app safe to put in
front of an anxious child.

What *is* defensible, and what D1–D3 below do: detect the mismatch,
record it, report it, and only ever **reduce** demand automatically.

---

## A. Reaction speed

| ID | Input | Condition | Decision | Evidence needed | Status |
| --- | --- | --- | --- | --- | --- |
| A1 | Stimulus-to-response latency | Median per session, compared with **the same child's** previous sessions of the **same activity at the same level** | Description only — no adaptation on speed alone | ≥ 8 valid trials in a session, ≥ 2 sessions | Proposed |
| A2 | Response latency | Median rises ≥ 25% over the child's own baseline across 2 consecutive sessions | Offer the same level again rather than stepping up | 2 sessions, ≥ 8 trials each | Proposed |
| A3 | Response latency | Response faster than 200 ms after stimulus onset | Mark the trial **invalid**; exclude from accuracy and latency | per trial | Proposed |
| A4 | Speed with accuracy | Fast **and** inaccurate (below the child's own accuracy median, latency below it too) | Slow the pace one step; do **not** lower the level | 2 sessions | Proposed |

**A3 matters more than it looks.** Without an anticipatory cut-off, a
child who taps rhythmically scores "fast and correct" by chance on a
go/no-go task, and A1–A2 then read their guessing as skill. 200 ms is the
conventional floor for a genuine visually driven response.

**A4 is the speed–accuracy trade-off.** Never treat faster as better on
its own. A child who halves their response time and doubles their error
rate has got worse, not better.

## B. Response variability

| ID | Input | Condition | Decision | Evidence needed | Status |
| --- | --- | --- | --- | --- | --- |
| B1 | Spread of response times | Median absolute deviation reported alongside the median | Description only | ≥ 8 valid trials | **Implemented** (`responseTimeVariabilityMs`) |
| B2 | SD ÷ mean | > 0.9 | Performance band demoted from `high` to `normal` | per session | **Implemented** (`performanceBand`) |

**Read the caution before you build on this.** Kofler et al. (2014) found
that reaction-time variability in children with ADHD was **largely
accounted for by working memory**, not independent of it: the raw group
difference was large (tau *d* = −0.93), but after controlling for central
executive working memory it vanished (*d* = −0.11, not significant), with
working memory explaining 88–100% of the difference. The reverse was not
true — variability explained only 10–29% of the working memory deficit.

**What follows for Mindy:** variability is a legitimate *descriptive*
measure of how evenly a child responded. It is **not** a marker you can
attribute to attention, and the existing indicator "How even the response
speed was" is correctly named. Keep it that way.

## C. Hesitation and pauses

| ID | Input | Condition | Decision | Evidence needed | Status |
| --- | --- | --- | --- | --- | --- |
| C1 | Time from task ready to first action | Above the child's own median by ≥ 2× | Offer a hint; no difficulty change | 3 occurrences in a session | Proposed |
| C2 | Gap between available choice and selection | Per-game threshold, never one global number | Description only | ≥ 5 choices | Proposed |
| C3 | Inactivity while the task is live | > 12 s with no action | Companion offers help (already does in Calm Maze) | per occurrence | **Implemented** (Calm Maze only) |
| C4 | Hint requests | Count per session | Feeds the support ladder | — | **Implemented** |
| C5 | Leaving before the end | Distinguish an explicit exit from a timeout, a pause, or the app being backgrounded | Abandon does not count as a journey step | — | **Implemented** (`recordAbandon`) |

**C2's per-game rule is not pedantry.** A 4-second pause in Calm Maze is
a child looking at scenery. The same pause in Sleepy Fox is a missed
trial. One global hesitation threshold would make those identical.

## D. Feeling against play — the rule you asked for

| ID | Condition | Decision | Evidence needed | Status |
| --- | --- | --- | --- | --- |
| D1 | Reported **calm or happy**, but the last 2 banded sessions of this activity are `low` | Step the level down 1 **and** set the pace to slow | 2 banded sessions, same activity | **Proposed — safe, recommend building** |
| D2 | Reported **scared or sad**, but the last 2 banded sessions are `high` | **No automatic change.** Record it in the decision trace and surface it as a research observation | 2 banded sessions, same activity | **Proposed — recommend building the record, not the step** |
| D3 | Either mismatch occurring in ≥ 2 of the child's last 5 banded sessions | Indicator: "When feelings and play did not match" | 5 banded sessions | Proposed |

**D1 is safe** because it only ever reduces demand. A child who says they
feel fine and is struggling gets an easier, slower activity. Nothing about
that can harm them, and it does not touch the safety floor.

**D2 is the one to take to your supervisor.** The argument for building
only the *record*: section 0. The argument someone might make for building
the *step*: a child who consistently outperforms the comfort floor may be
under-stimulated, and boredom has its own cost. That is a real argument.
It is also a decision about what the app does to an anxious child, which
is exactly the class of decision that needs a supervisor's name on it.

**If it is approved**, the safe form is: never leave the calm pool, never
raise the level above the safety floor, and lift only the **pace** from
slow to normal — reversible, bounded, and visible in the trace. Changing
`levelRange` is not the safe form.

**D3 is the output you asked for.** The honest title is descriptive —
"when feelings and play did not match" — and the alternative explanations
have to be printed with it: the child may not have understood the faces,
may have picked the first one, may feel differently about the activity
than about the day, or may be anxious *and* capable, which section 0 says
is the common case rather than a contradiction.

## E. Errors and what follows them

| ID | Input | Condition | Decision | Evidence needed | Status |
| --- | --- | --- | --- | --- | --- |
| E1 | Response time after an error vs after a correct response | Descriptive comparison | Description only | ≥ 6 post-error trials | Proposed |
| E2 | Error rate in the 3 attempts after a mistake vs all others | ≥ threshold | Indicator 7, "What happened after a slip" | 2 sessions, 6 after-attempts, 12 others | **Implemented** |
| E3 | Same obstacle failed 3× in a row | Offer a hint or a simpler variant; never repeat unchanged | per occurrence | Proposed |

**E1 is post-error slowing**, and it is well established in children of
exactly Mindy's age range. Denervaud, Hess, Sander & Pourtois (2021) found
8–12 year-olds slowed after errors just as adults did — they describe it
as an automatic attentional response to the error, already in place by age
8, and the same across schooling types. The *affective* side of error
monitoring differed by age; this attentional side did not.

**So the presence of post-error slowing is normal and not notable.** If
anything is worth describing it is its **absence** — and even then as an
observation, never as a finding about the child. E2 already carries the
documented weakness that its windows overlap (see `ENGINE_AUDIT.md` §3).

## F. Difficulty adaptation — what the field actually does

Víteková, Eichhorn, Pirker & Plecher (2026) reviewed dynamic difficulty
adjustment in serious games. Of the signals used:

- **performance-based metrics: 17 papers** — the most common by a wide
  margin, and the easiest to collect without extra hardware
- physiological (EEG, heart rate, facial expression): 8
- emotion-based: 4
- Elo rating: 3
- human digital twin: 1

**This is a direct defence of Mindy's design** when the panel asks why a
simple accuracy-based rule rather than something richer: accuracy-based
adaptation is what the field predominantly does, and the review notes that
physiological signals are under-used partly because measuring them during
play is effortful and obtrusive — which for anxious children in a medical
context is a reason, not an excuse.

**Cite the review's cautions too, because they apply to you.** It reports
small sample sizes, inconsistent evaluation metrics, and that about 16% of
the papers reviewed had no DDA evaluation at all. Mindy having a
pre-registered evaluation plan puts it ahead of a sixth of the published
work in its own field — a point worth making.

---

## Recommended build order

1. **A3** (anticipatory cut-off). Cheap, and it protects every other
   latency measure from being quietly wrong.
2. **D1** (calm but struggling → easier and slower). Safe, useful, small.
3. **D3** (the mismatch indicator). The research output you asked for.
4. **E3** (stop repeating a failed obstacle). A kindness, and uncontroversial.
5. **A1, A2, A4, B1, C1, C2, E1** — the descriptive layer. Build after
   there is event data with reliable timestamps to compute them from.
6. **D2's step** — only with a supervisor's sign-off, and only in the
   bounded pace-only form.

## What must be true before any of these run

Every latency rule assumes the event log carries a **stimulus-ready
timestamp** and a **response timestamp** from a monotonic clock, not wall
time. Check that before building A1–A4; if the timestamps are wall-clock
or only session-level, these rules will produce numbers that look fine and
mean nothing.

## Sources

- Eysenck, M. W., Derakshan, N., Santos, R., & Calvo, M. G. (2007).
  Anxiety and cognitive performance: Attentional control theory.
  *Emotion, 7*(2), 336–353.
- Edwards, E. J., & Edwards, M. S. (2018). The link between anxiety and
  cognitive performance: What we know a decade on. *The Cognitive
  Psychology Bulletin, Spring*(3), 11–12.
- Kofler, M. J., Alderson, R. M., Raiker, J. S., Bolden, J., Sarver,
  D. E., & Rapport, M. D. (2014). Working memory and intraindividual
  variability as neurocognitive indicators in ADHD: Examining competing
  model predictions. *Neuropsychology, 28*(3), 459–471.
- Denervaud, S., Hess, A., Sander, D., & Pourtois, G. (2021). Children's
  automatic evaluation of self-generated actions is different from adults.
  *Developmental Science, 24*, e13045.
- Víteková, L., Eichhorn, C., Pirker, J., & Plecher, D. A. (2026). Dynamic
  difficulty adjustment in serious games: A literature review.
  *Information, 17*(1), 96.
