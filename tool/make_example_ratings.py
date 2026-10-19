#!/usr/bin/env python3
"""Produce a DEMONSTRATION set of ratings so the analysis pipeline can be
run end to end before any real rater is recruited.

    python3 tool/make_example_ratings.py

!!  THE NUMBERS THIS WRITES ARE INVENTED.  !!
They exist only to prove that analyse_ratings.py runs and that the output
format is what the dissertation needs. They are NOT a result, they are NOT
a pilot, and they must never appear in the report as findings. Every file
it writes carries the synthetic banner in a comment row and in its name.

It needs build/eval/condition_key.csv, which comes from the Dart harness:
    flutter test test/evaluation_harness_test.dart
"""

import csv
import os
from collections import defaultdict

import numpy as np

BANNER = "SYNTHETIC / DEVELOPMENT DATA - NOT REAL PARTICIPANT DATA"
KEY = "build/eval/condition_key.csv"
OUT_DIR = "build/eval"
N_RATERS = 5
SEED = 20261018

# Invented condition means on the 1-5 scale. Chosen only to exercise the
# analysis; they are not a prediction of what real raters would say.
TRUE_MEAN = {"ADAPTIVE": 3.9, "DIFFICULTY_ONLY": 3.5, "FIXED_BASELINE": 3.4}
SD_RATER = 0.35      # rater leniency
SD_PROFILE = 0.45    # some profiles are easier to serve than others
SD_RESID = 0.70      # per-rating noise


def main():
    if not os.path.exists(KEY):
        raise SystemExit(
            f"{KEY} not found. Run the Dart harness first:\n"
            "  flutter test test/evaluation_harness_test.dart")

    rng = np.random.default_rng(SEED)
    key = defaultdict(dict)
    with open(KEY, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            key[row["profileId"]][row["option"]] = row["condition"]

    profiles = sorted(key)
    prof_eff = {p: rng.normal(0, SD_PROFILE) for p in profiles}

    for r in range(1, N_RATERS + 1):
        name = f"example_ratings_SYNTHETIC_rater{r}"
        rater_eff = rng.normal(0, SD_RATER)
        rows = []
        for p in profiles:
            scores = {}
            for opt, cond in key[p].items():
                base = TRUE_MEAN[cond] + rater_eff + prof_eff[p]
                q = [int(np.clip(round(rng.normal(base, SD_RESID)), 1, 5))
                     for _ in range(3)]
                scores[opt] = (q, float(np.mean(q)))
            best = max(scores, key=lambda o: scores[o][1])
            for opt in sorted(key[p]):
                q, _ = scores[opt]
                rows.append({
                    "profileId": p,
                    "option": opt,
                    "q1_activity_suits_feeling_1to5": q[0],
                    "q2_level_suits_history_1to5": q[1],
                    "q3_caregiver_comfortable_1to5": q[2],
                    "mostAppropriateOption_A_B_C": best,
                })
        path = os.path.join(OUT_DIR, name + ".csv")
        with open(path, "w", newline="", encoding="utf-8") as fh:
            fh.write(f"# {BANNER} - invented ratings, not a result\n")
            w = csv.DictWriter(fh, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
        print("wrote", path)

    print(f"\n{BANNER}")
    print("Analyse with:")
    print("  python3 tool/analyse_ratings.py \\")
    print("      --ratings 'build/eval/example_ratings_SYNTHETIC_rater*.csv' \\")
    print("      --key build/eval/condition_key.csv")


if __name__ == "__main__":
    main()
