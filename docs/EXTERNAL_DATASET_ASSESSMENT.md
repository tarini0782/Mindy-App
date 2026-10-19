# External dataset assessment — Zenodo gameplay log package

**Dataset:** Krisdiawan, R. A., Husen, D., & Herwanto, H. (2026).
*Anonymized Gameplay Log Dataset for First-Grade Mathematics Educational Game
Prototype.* Zenodo. Record 20576432.
**Licence:** CC BY 4.0 — reuse and adaptation permitted **with attribution**.

**Method:** every number below was computed by running
`tool/external_dataset_check.py` over the unzipped package. Nothing here is
quoted from the README without checking it against the CSVs.

> This is **real data from real children** in another study. It is not
> Mindy participant data and not synthetic data. Any file in this project
> derived from it must say so, and must carry the citation above. It must
> never be merged into a Mindy session store, and it must never appear under
> the `SYNTHETIC / DEVELOPMENT DATA` banner — that banner means something
> different and using it here would misdescribe the provenance.

---

## 1. What is actually in it

| | |
| --- | --- |
| Students | 9 |
| Sessions | 9 |
| Level records | 54 (9 students × 6 levels) |
| Answer records | 171 |
| Response times | n=171, min 1 s, median 6 s, max 58 s, **whole seconds** |
| Accuracy per level | median **1.00**; 83% of records at the ceiling |
| Their adaptation labels | Mastered 29, Adequate 24, **Struggling 1** |

Domain: first-grade mathematics (counting, ordering, place value), in
Indonesian. Not wellbeing, not medical preparation, not anxiety.

## 2. What it cannot do for Mindy

**It cannot train anything.** 9 students, 54 records, and one single
"Struggling" record. A class with one member cannot be learned or evaluated.
83% of records sit at 100% accuracy — a ceiling effect that leaves almost no
variance to model even if the sample were larger.

**It cannot inform any reaction-time threshold.** Response times are recorded
in **whole seconds, at question level**. Sleepy Fox's entire stimulus window
is 1.5–2.6 seconds. The dataset's timing resolution is coarser than Mindy's
whole response window, so it says nothing about go/no-go latency,
anticipatory responses or response variability as Mindy measures them.

**It contains no outcome at all.** No wellbeing measure, no emotion check-in,
no caregiver report, no post-test. So it cannot show that any adaptation rule
— theirs or Mindy's — helped a child.

**It has no go/no-go, no rule-switching, no tap timestamps, no tap
coordinates, no commission or omission events.** Indicators 2, 3 and the
Sorting Stars indicators have no counterpart in it whatsoever.

## 3. Three things it is genuinely good for

### 3.1 A citable precedent for rule-based adaptation — the strongest use

The panel question this answers is: *"why is a rule engine good enough for a
final-year research project?"*

This is an independently published educational game, with its own dataset,
whose adaptation layer is **also rule-based on accuracy**:

| | |
| --- | --- |
| accuracy ≥ 0.80 and no help | Mastered → Increase |
| accuracy ≥ 0.60 | Adequate → Maintain |
| accuracy < 0.60 | Struggling → Decrease |

Their own README states these are *preliminary rule-based features*, not
validated model outputs. That is the same honest position Mindy takes, in
print, from another group. Cite it where the literature review claims that
rule-based adaptation is a legitimate starting point rather than a shortcut.

It also lets the review state Mindy's **difference** concretely instead of
asserting novelty: their rule moves difficulty on a **single** level's
accuracy, with no consistency requirement, no bound on the step size, and no
safety layer. Mindy requires two consistent banded sessions of the same
activity, bounds the step to ±1, and restricts to calm activities at level 1
when a check-in is scared, sad or skipped.

### 3.2 A reproducibility check that needs no ethics approval

`tool/external_dataset_check.py` runs Mindy's documented band and step policy
over their 54 records and compares it with their labels. Measured result:

- agree **21/54**, disagree **33/54**
- of the disagreements, **19** are Mindy *declining to move* where their rule
  moved — the consistency requirement doing exactly what it was written to do

This is a real, runnable, panel-demonstrable experiment on external data, and
it makes the caution in Mindy's rule a **measured** difference rather than a
claim. It is not evidence that Mindy's rule is better. There is no outcome in
the data to be better *at*.

The analogy is imperfect and the script says so: their "level" is curriculum
order, Mindy's is difficulty. Read the disagreements, not the agreement rate.

### 3.3 A template for your own data package

Their package ships `data_dictionary.csv`, `ETHICAL_NOTE.txt`,
`DATA_AVAILABILITY_STATEMENT.txt`, `CITATION.cff`, `file_manifest.csv` and a
validation summary. That is the shape your own dataset deliverable should
take. CC BY 4.0 permits adapting the structure with attribution.

## 4. A methodological observation worth making

Their published rule table has a gap, and it is large.

**16 of 54 records (30%)** have accuracy ≥ 0.80 **and** used help. The first
rule requires `help == 0`, so these fall through to the second rule and are
labelled **Adequate**, not Mastered. The table never states that help demotes
a high-accuracy level — it happens as an unstated consequence of rule order.
Nearly a third of the dataset's labels are set that way.

Making this point shows a reviewer you read the data rather than the
abstract. It also obliges the same check on Mindy: the band rule has a
comparable silent clause, where accuracy ≥ 0.85 is demoted from `high` to
`normal` if `sd/mean > 0.9` on response times. On this dataset it fires on
**2 of 45** eligible records (4%) — low, which is the reassuring result, and
a weak test besides, because these response times are whole seconds. It still
fires silently, so it belongs in the documentation wherever a band is shown
to a caregiver.

## 5. If you use it, you must

1. Cite Krisdiawan, Husen & Herwanto (2026) wherever a number from it
   appears, and state the CC BY 4.0 licence.
2. Check the Zenodo record for the assigned DOI — the package ships
   `CITATION.cff` with the DOI marked *"to be assigned"*, so the version in
   the ZIP is not citable as-is.
3. Keep it outside `lib/` and outside any Mindy session store. The script
   reads it from a path you pass in; nothing is copied into the project.
4. Never describe it as validating Mindy, and never report its children's
   numbers as Mindy results.

## 6. Running it

```
python3 tool/external_dataset_check.py <path to the unzipped dataset folder>
```

Executed successfully in the development environment on 18 October 2026.
Python standard library only; no new dependency is added to the project.
