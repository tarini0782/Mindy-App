#!/usr/bin/env python3
"""
Applies Mindy's documented difficulty policy to an EXTERNAL, PUBLISHED dataset
and compares it with that dataset's own rule-based adaptation labels.

    Krisdiawan, R. A., Husen, D., & Herwanto, H. (2026).
    Anonymized Gameplay Log Dataset for First-Grade Mathematics Educational
    Game Prototype. Zenodo. Licence: CC BY 4.0.

WHAT THIS IS
------------
A reproducibility and robustness check. It shows that Mindy's difficulty rule
is deterministic, that it behaves sensibly on data it was not designed around,
and exactly where it disagrees with an independently published rule.

WHAT THIS IS NOT
----------------
  * Not training. Nothing here fits a model. The dataset has 9 students,
    54 level records and ONE "Struggling" record; no model can be fitted or
    evaluated on that.
  * Not validation of Mindy. These are different children, a different
    country, a different task (first-grade mathematics, in Indonesian) and
    different measures.
  * Not a source of reaction-time evidence. Response times in this dataset
    are recorded in WHOLE SECONDS at the question level. Mindy's Sleepy Fox
    stimulus window is 1.5-2.6 seconds in total, so this dataset's timing
    resolution is coarser than Mindy's entire response window. It cannot
    inform any reaction-time threshold.

MINDY'S POLICY, AS IMPLEMENTED (source of truth is the Dart, not this file)
--------------------------------------------------------------------------
Performance band  -- lib/games/models/game_session.dart, `performanceBand`
    accuracy < 0.50                          -> low
    accuracy >= 0.85 and not "very variable" -> high
    otherwise                                -> normal
    "very variable" = sd(response times) / mean > 0.9
    A band is only assigned to a COMPLETED session of an activity that has
    right/wrong moments.

Difficulty step   -- lib/games/engine/adaptive_game_engine.dart, `_levelFor`
    The last 2 banded sessions of the same activity (else the last 3 overall)
    must ALL be high  -> +1
    must ALL be low   -> -1
    anything mixed, or too few sessions -> no change
    The step is never more than one, and never from a single session.

THE DATASET'S OWN RULE
----------------------
    accuracy >= 0.80 and help_used == 0 -> Mastered   -> Increase
    accuracy >= 0.60                    -> Adequate   -> Maintain
    accuracy <  0.60                    -> Struggling -> Decrease

Usage:
    python3 tool/external_dataset_check.py <path to the unzipped dataset dir>
"""

import csv
import statistics as st
import sys
from collections import Counter, defaultdict

EVIDENCE_NEEDED = 2       # Mindy: last 2 banded sessions of the same activity
BAND_LOW = 0.50
BAND_HIGH = 0.85
VARIABILITY_CUTOFF = 0.9  # sd / mean


def band(accuracy, response_times):
    """Mindy's performance band, as implemented in game_session.dart."""
    if accuracy is None:
        return None
    if accuracy < BAND_LOW:
        return "low"
    if accuracy >= BAND_HIGH:
        if len(response_times) >= 3:
            mean = st.mean(response_times)
            sd = st.pstdev(response_times)
            if mean > 0 and sd / mean > VARIABILITY_CUTOFF:
                return "normal"   # too variable to call it smooth
        return "high"
    return "normal"


def mindy_step(recent_bands):
    """Mindy's difficulty step from the most recent banded sessions."""
    if len(recent_bands) < EVIDENCE_NEEDED:
        return 0, "not enough recent sessions yet"
    window = recent_bands[-EVIDENCE_NEEDED:]
    if all(b == "high" for b in window):
        return +1, "consistently smooth play"
    if all(b == "low" for b in window):
        return -1, "consistently tricky play"
    return 0, "recent sessions mixed: no change"


THEIR_STEP = {"Increase": +1, "Maintain": 0, "Decrease/Reinforcement": -1}


def main(root):
    levels = list(csv.DictReader(open(f"{root}/adaptive_feature_dataset.csv")))
    answers = list(csv.DictReader(open(f"{root}/answer_level_dataset.csv")))

    # Response times per (student, level), for the variability clause.
    times = defaultdict(list)
    for a in answers:
        v = a["response_time_seconds"]
        if v not in ("", "NA"):
            times[(a["student_id"], a["level"])].append(float(v))

    print("=" * 74)
    print("EXTERNAL DATASET -- Krisdiawan et al. 2026, Zenodo, CC BY 4.0")
    print("NOT Mindy participant data. Real children, a different study.")
    print("=" * 74)

    students = sorted({r["student_id"] for r in levels})
    print(f"\n1. WHAT IS ACTUALLY IN IT")
    print(f"   students          {len(students)}")
    print(f"   level records     {len(levels)}")
    print(f"   answer records    {len(answers)}")
    rts = [t for v in times.values() for t in v]
    print(f"   response times    n={len(rts)}  min={min(rts):.0f}s  "
          f"median={st.median(rts):.0f}s  max={max(rts):.0f}s")
    print(f"   whole seconds?    {all(abs(t - round(t)) < 1e-9 for t in rts)}"
          "   <- coarser than Mindy's whole 1.5-2.6s response window")
    accs = [float(r["accuracy_level"]) for r in levels]
    print(f"   accuracy          median={st.median(accs):.2f}  "
          f"at ceiling (1.00)={sum(a == 1.0 for a in accs) / len(accs):.0%}")
    print(f"   their labels      {dict(Counter(r['student_state'] for r in levels))}")
    print("   -> one 'Struggling' record in 54. Nothing can be trained or")
    print("      evaluated on a class with a single member.")

    # ---- a documentation gap in the published rule table -----------------
    gap = [r for r in levels
           if float(r["accuracy_level"]) >= 0.80 and int(r["total_help_used"]) > 0]
    print(f"\n2. A GAP IN THEIR PUBLISHED RULE TABLE")
    print(f"   {len(gap)} of {len(levels)} records have accuracy >= 0.80 but used help.")
    print(f"   Their stated rules label these: "
          f"{dict(Counter(r['student_state'] for r in gap))}")
    print("   The table never states that help demotes a high-accuracy level;")
    print("   it happens by fall-through to the second rule. 30% of the")
    print("   dataset's labels are set by an unstated consequence of rule order.")
    print("   Mindy's own rules must be checked for the same failure mode.")

    # ---- how much work Mindy's own variability clause is doing -----------
    demoted = kept = 0
    for r in levels:
        acc = float(r["accuracy_level"])
        if acc < BAND_HIGH:
            continue
        if band(acc, times[(r["student_id"], r["level"])]) == "high":
            kept += 1
        else:
            demoted += 1
    print(f"\n2b. MINDY HAS THE SAME KIND OF HIDDEN CLAUSE")
    print(f"   Of the {kept + demoted} records at accuracy >= {BAND_HIGH},")
    print(f"   Mindy's variability clause (sd/mean > {VARIABILITY_CUTOFF}) demotes")
    print(f"   {demoted} from 'high' to 'normal' -- "
          f"{demoted / max(kept + demoted, 1):.0%} of them.")
    print("   That rate is low, which is the reassuring result: the clause is")
    print("   a guard against erratic-but-correct play, not a hidden brake on")
    print("   most sessions. It still fires silently, so it belongs in the")
    print("   documentation of the band wherever the band is reported.")
    print("   Caveat on the number itself: these response times are whole")
    print("   seconds at question level, so sd/mean here is coarse and this")
    print("   is a weak test of the clause, not a strong one.")

    # ---- Mindy's policy over each student's sequence ---------------------
    print(f"\n3. MINDY'S POLICY APPLIED TO THE SAME 54 RECORDS")
    print("   Each student's 6 sequential levels are treated as a session")
    print("   history for one activity. This is an ANALOGY, not an")
    print("   equivalence: their 'level' is curriculum order, Mindy's is")
    print("   difficulty. Read the disagreement, not the agreement rate.")
    agree = disagree = 0
    held_back = 0
    rows = []
    for s in students:
        seq = sorted((r for r in levels if r["student_id"] == s),
                     key=lambda r: int(r["level"]))
        bands = []
        for r in seq:
            acc = float(r["accuracy_level"])
            b = band(acc, times[(s, r["level"])])
            step, why = mindy_step(bands)
            theirs = THEIR_STEP[r["adaptation_action"]]
            bands.append(b)
            if step == theirs:
                agree += 1
            else:
                disagree += 1
                if theirs != 0 and step == 0:
                    held_back += 1
            rows.append((s, r["level"], acc, b, step, theirs, why))

    print(f"\n   {'child':6} {'lvl':>3} {'acc':>5} {'band':>7} "
          f"{'Mindy':>6} {'theirs':>7}  reason")
    for s, lv, acc, b, step, theirs, why in rows[:12]:
        print(f"   {s:6} {lv:>3} {acc:>5.2f} {str(b):>7} "
              f"{step:>+6} {theirs:>+7}  {why}")
    print(f"   ... {len(rows) - 12} more rows")

    print(f"\n   agree {agree}/{len(rows)}   disagree {disagree}/{len(rows)}")
    print(f"   of the disagreements, {held_back} are Mindy declining to move")
    print("   where their rule moved. That is the consistency requirement")
    print("   doing its job: their rule changes difficulty on a single")
    print("   level's accuracy; Mindy needs two consistent banded sessions.")
    print("   Whether that caution is right is a research question, not a")
    print("   bug -- but it is now a MEASURED difference, not an assertion.")

    print(f"\n4. WHAT THIS DOES NOT SHOW")
    print("   Nothing about whether either rule helps a child. There is no")
    print("   outcome measure in this dataset -- no wellbeing label, no")
    print("   caregiver report, no post-test. Agreement with another rule")
    print("   is not evidence that either rule is correct.")
    print("=" * 74)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    main(sys.argv[1].rstrip("/"))
