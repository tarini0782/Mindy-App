# Instructions for raters

Thank you for helping. This takes about 30–40 minutes.

## What you are rating

You will see 24 short descriptions of a child, each followed by **three
suggested activities** labelled A, B and C. For each suggestion you judge how
appropriate it is for that child, right now.

**You are rating the suggestion, not the child and not the app.** There are no
right answers being checked against a key.

## What you need to know first

- The children are **invented**. No real child produced any of this. The
  histories are generated test cases.
- The three suggestions for each child were produced by three different
  versions of the software. **You are not told which is which**, and the order
  changes for every child. Please do not try to work it out; if you form a
  theory, rate as if you had not.
- The app is for children roughly 3–12 preparing for medical visits. It is not
  a medical or diagnostic tool and makes no clinical claims.
- "Level" is difficulty, 1 (easiest) to 5 (hardest). "Pace" is slow or normal.

## How to read a child description

| Field | Meaning |
| --- | --- |
| checkIn | How the child said they feel just now, by tapping a picture. "skipped" means they did not answer |
| historyLength | short = about 4 past sessions, long = about 10 |
| trajectory | improving = the child has recently tended to feel better after activities; not_improving = they have tended to feel about the same |
| whyThisWasChosen | The app's own explanation for this suggestion |

## The three questions

Answer all three for **every** option (A, B and C), on this scale:

**Q1. Is this activity suitable for how the child said they feel?**

| 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- |
| Clearly unsuitable — could upset this child | Poorly suited | Neither suited nor unsuited | Well suited | Clearly the right kind of activity for this feeling |

**Q2. Is the difficulty level suitable, given this child's history?**

| 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- |
| Clearly wrong — far too hard or far too easy | Somewhat off | Acceptable | Well judged | Clearly the right level for this child |

**Q3. Would a caregiver be comfortable with this being offered now?**

| 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- |
| No — I would object to this being offered | Uneasy | Neutral | Comfortable | Entirely comfortable |

## The forced choice

For each child, after rating all three, write **one** letter (A, B or C) in the
`mostAppropriateOption_A_B_C` column: the single option you consider most
appropriate overall.

You must pick one even if two feel equal. If it was close, that is useful —
note it in the margin or tell the researcher afterwards.

## Practical notes

- Work through the children in the order given.
- The first two are practice and will be discarded. Rate them anyway.
- Do not go back and change earlier answers once you have moved on.
- If something is unclear, write a note rather than guessing silently.
- Please do not discuss your ratings with other raters until everyone has
  finished. Agreement between raters is part of what is being measured, and
  discussion would destroy it.

## What happens to your ratings

They are analysed to compare the three software versions on appropriateness.
Your name is not stored with the ratings; files are identified as rater 1,
rater 2 and so on.

If you would like to see the result when the study is finished, say so and the
researcher will send it to you.

---

### Note for the researcher, not for raters

Do not hand over `build/eval/condition_key.csv` with these sheets, and do not
leave it in the same folder. Check, before sending, that the sheet contains no
occurrence of `ADAPTIVE`, `DIFFICULTY_ONLY` or `FIXED_BASELINE` — the harness
asserts this, but check the file you actually send.

Record which rater file came from which person separately, and keep that list
out of the repository.
