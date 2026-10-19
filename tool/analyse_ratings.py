#!/usr/bin/env python3
"""Analysis for the Mindy recommendation-appropriateness study.

Reads the blinded rater sheets and the separate condition key, unblinds
them, and runs the PRE-SPECIFIED analysis in docs/RESEARCH_REPORT.md
section 11.

    python3 tool/analyse_ratings.py --ratings build/eval/ratings_*.csv \
                                    --key build/eval/condition_key.csv

Assumptions, stated because they change the result:

  1. The unit of analysis is the PROFILE, not the rating. For each profile
     and condition the composite is averaged over raters first, then the
     within-profile difference between conditions is tested. Profile and
     rater main effects cancel inside that paired difference, which is why
     no mixed model is needed for the primary test.
  2. The composite is the mean of q1, q2, q3. Cronbach's alpha is reported;
     the pre-registered fallback if alpha < 0.70 is q1 alone.
  3. The primary comparison is ADAPTIVE vs FIXED_BASELINE, tested
     unadjusted. Every other comparison is secondary and Holm-corrected.
  4. Missing ratings are dropped pairwise, and the count is reported. This
     is only defensible for a handful of omissions; if a rater skipped many
     items, say so in the write-up rather than silently averaging.

Nothing here invents data. Run it on real ratings, or on the clearly
labelled demonstration file produced by tool/make_example_ratings.py.
"""

import argparse
import csv
import glob
import itertools
import math
from collections import defaultdict

import numpy as np
from scipy import stats

PRIMARY = ("ADAPTIVE", "FIXED_BASELINE")
ITEMS = ["q1_activity_suits_feeling_1to5",
         "q2_level_suits_history_1to5",
         "q3_caregiver_comfortable_1to5"]


def _rows(path):
    """csv.DictReader over a file, skipping '#' banner/comment lines.

    The generated files carry a synthetic-data banner as a leading comment
    row; without this filter DictReader would treat that banner as the
    header and silently find no columns.
    """
    with open(path, newline="", encoding="utf-8") as fh:
        lines = [ln for ln in fh if not ln.lstrip().startswith("#")]
    yield from csv.DictReader(lines)


def read_key(path):
    """profileId -> option letter -> condition."""
    key = defaultdict(dict)
    for row in _rows(path):
        key[row["profileId"]][row["option"]] = row["condition"]
    return key


def read_ratings(paths, key):
    """Returns long-format records with the condition attached."""
    out = []
    dropped = 0
    for path in paths:
        rater = path.split("/")[-1].replace(".csv", "")
        for row in _rows(path):
            pid, opt = row.get("profileId"), row.get("option")
            if not pid or not opt:
                continue
            if pid not in key or opt not in key[pid]:
                raise SystemExit(
                    f"{path}: profile {pid} option {opt} is not in the key. "
                    "The ratings and the key are from different runs.")
            vals = []
            for item in ITEMS:
                raw = (row.get(item) or "").strip()
                vals.append(float(raw) if raw else math.nan)
            if all(math.isnan(v) for v in vals):
                dropped += 1
                continue
            out.append({
                "rater": rater,
                "profileId": pid,
                "option": opt,
                "condition": key[pid][opt],
                "q": vals,
                "composite": float(np.nanmean(vals)),
                "forced": (row.get("mostAppropriateOption_A_B_C") or "").strip().upper(),
            })
    return out, dropped


def cronbach_alpha(matrix):
    """matrix: rows = observations, cols = items."""
    m = np.asarray(matrix, dtype=float)
    m = m[~np.isnan(m).any(axis=1)]
    k = m.shape[1]
    if m.shape[0] < 3 or k < 2:
        return float("nan")
    item_var = m.var(axis=0, ddof=1).sum()
    total_var = m.sum(axis=1).var(ddof=1)
    if total_var == 0:
        return float("nan")
    return (k / (k - 1)) * (1 - item_var / total_var)


def krippendorff_ordinal(units):
    """units: list of lists of ordinal codes (one list per unit, one code
    per rater who rated it). Returns alpha, or nan when undefined."""
    values = sorted({v for u in units for v in u})
    if len(values) < 2:
        return float("nan")
    idx = {v: i for i, v in enumerate(values)}
    counts = np.zeros(len(values))
    for u in units:
        for v in u:
            counts[idx[v]] += 1

    def delta2(c, k):
        if c > k:
            c, k = k, c
        inner = counts[c:k + 1].sum() - (counts[c] + counts[k]) / 2.0
        return inner ** 2

    num = 0.0
    n_pairable = 0
    for u in units:
        m = len(u)
        if m < 2:
            continue
        n_pairable += m
        for a, b in itertools.permutations(u, 2):
            num += delta2(idx[a], idx[b]) / (m - 1)
    if n_pairable < 2:
        return float("nan")
    do = num / n_pairable

    den = 0.0
    total = counts.sum()
    for a in range(len(values)):
        for b in range(len(values)):
            if a == b:
                continue
            den += counts[a] * counts[b] * delta2(a, b)
    de = den / (total * (total - 1))
    return float("nan") if de == 0 else 1 - do / de


def fleiss_kappa(table):
    """table: rows = items, cols = categories, cells = number of raters."""
    t = np.asarray(table, dtype=float)
    n = t.sum(axis=1)
    if t.shape[0] == 0 or not np.all(n == n[0]) or n[0] < 2:
        return float("nan")
    n = n[0]
    p_j = t.sum(axis=0) / (t.shape[0] * n)
    P_i = (np.square(t).sum(axis=1) - n) / (n * (n - 1))
    p_bar, pe = P_i.mean(), np.square(p_j).sum()
    return float("nan") if pe == 1 else (p_bar - pe) / (1 - pe)


def rank_biserial(d):
    """Paired rank-biserial effect size for Wilcoxon signed-rank."""
    d = d[d != 0]
    if d.size == 0:
        return 0.0
    ranks = stats.rankdata(np.abs(d))
    rpos = ranks[d > 0].sum()
    rneg = ranks[d < 0].sum()
    return float((rpos - rneg) / ranks.sum())


def boot_ci(d, n_boot=10000, seed=7):
    rng = np.random.default_rng(seed)
    if d.size == 0:
        return (float("nan"), float("nan"))
    means = [rng.choice(d, d.size, replace=True).mean() for _ in range(n_boot)]
    return tuple(np.percentile(means, [2.5, 97.5]))


def compare(profile_means, a, b):
    pids = [p for p in profile_means
            if a in profile_means[p] and b in profile_means[p]]
    d = np.array([profile_means[p][a] - profile_means[p][b] for p in pids])
    if d.size < 3 or np.all(d == 0):
        return {"n": d.size, "median_diff": float(np.median(d)) if d.size else float("nan"),
                "p": float("nan"), "rbc": float("nan"), "ci": (float("nan"),) * 2}
    p = stats.wilcoxon(d).pvalue
    return {"n": d.size, "mean_diff": float(d.mean()),
            "median_diff": float(np.median(d)), "p": float(p),
            "rbc": rank_biserial(d), "ci": boot_ci(d)}


def holm(pvals):
    order = sorted(range(len(pvals)), key=lambda i: pvals[i])
    adj = [0.0] * len(pvals)
    running = 0.0
    for rank, i in enumerate(order):
        val = (len(pvals) - rank) * pvals[i]
        running = max(running, val)
        adj[i] = min(1.0, running)
    return adj


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ratings", nargs="+", required=True,
                    help="rater CSVs; globs allowed")
    ap.add_argument("--key", required=True)
    args = ap.parse_args()

    paths = sorted({p for pat in args.ratings for p in glob.glob(pat)})
    if not paths:
        raise SystemExit("No rating files matched.")

    key = read_key(args.key)
    recs, dropped = read_ratings(paths, key)
    if not recs:
        raise SystemExit("No usable ratings found.")

    raters = sorted({r["rater"] for r in recs})
    profiles = sorted({r["profileId"] for r in recs})
    print(f"Raters: {len(raters)}  Profiles: {len(profiles)}  "
          f"Ratings: {len(recs)}  Blank rows dropped: {dropped}")
    if len(raters) < 3:
        print("WARNING: fewer than 3 raters. Agreement statistics are "
              "not meaningful and the study is underpowered.")

    alpha = cronbach_alpha([r["q"] for r in recs])
    print(f"\nInternal consistency of the 3 items (Cronbach's alpha): {alpha:.3f}")
    if not math.isnan(alpha) and alpha < 0.70:
        print("  alpha < 0.70 -> the PRE-REGISTERED FALLBACK applies: "
              "use q1 alone as the primary outcome.")
        for r in recs:
            r["composite"] = r["q"][0]

    # profile x condition means, averaged over raters (assumption 1)
    bucket = defaultdict(list)
    for r in recs:
        bucket[(r["profileId"], r["condition"])].append(r["composite"])
    profile_means = defaultdict(dict)
    for (pid, cond), vals in bucket.items():
        profile_means[pid][cond] = float(np.mean(vals))

    print("\nMean composite by condition (over profile means):")
    for cond in ("ADAPTIVE", "DIFFICULTY_ONLY", "FIXED_BASELINE"):
        vals = [m[cond] for m in profile_means.values() if cond in m]
        if vals:
            print(f"  {cond:<16} {np.mean(vals):.3f}  (n={len(vals)} profiles)")

    contrasts = [("ADAPTIVE", "FIXED_BASELINE"),
                 ("ADAPTIVE", "DIFFICULTY_ONLY"),
                 ("DIFFICULTY_ONLY", "FIXED_BASELINE")]
    results = {c: compare(profile_means, *c) for c in contrasts}

    print("\nPRIMARY (unadjusted): ADAPTIVE vs FIXED_BASELINE")
    r = results[PRIMARY]
    print(f"  n={r['n']} profiles  mean diff={r.get('mean_diff', float('nan')):+.3f}  "
          f"95% CI [{r['ci'][0]:+.3f}, {r['ci'][1]:+.3f}]")
    print(f"  Wilcoxon p={r['p']:.4f}   rank-biserial={r['rbc']:+.3f}")

    sec = [c for c in contrasts if c != PRIMARY]
    praw = [results[c]["p"] for c in sec]
    padj = holm([0.0 if math.isnan(p) else p for p in praw])
    print("\nSECONDARY (Holm-corrected):")
    for c, pa in zip(sec, padj):
        rr = results[c]
        print(f"  {c[0]} vs {c[1]}: mean diff="
              f"{rr.get('mean_diff', float('nan')):+.3f}  raw p={rr['p']:.4f}  "
              f"Holm p={pa:.4f}  rank-biserial={rr['rbc']:+.3f}")

    # agreement on the composite, per condition
    print("\nInter-rater agreement (Krippendorff's alpha, ordinal, "
          "on rounded composites):")
    for cond in ("ADAPTIVE", "DIFFICULTY_ONLY", "FIXED_BASELINE"):
        units = []
        for pid in profiles:
            vals = [int(round(r["composite"])) for r in recs
                    if r["profileId"] == pid and r["condition"] == cond]
            if len(vals) >= 2:
                units.append(vals)
        a = krippendorff_ordinal(units) if units else float("nan")
        print(f"  {cond:<16} {a:.3f}" if not math.isnan(a)
              else f"  {cond:<16} n/a")

    # forced choice
    picks = defaultdict(dict)
    for r in recs:
        if r["forced"]:
            picks[r["rater"]][r["profileId"]] = r["forced"]
    if picks:
        print("\nForced choice (secondary, supporting evidence):")
        tally = defaultdict(int)
        total = 0
        table = []
        for pid in profiles:
            counts = defaultdict(int)
            for rater in raters:
                opt = picks.get(rater, {}).get(pid)
                if opt and opt in key[pid]:
                    counts[key[pid][opt]] += 1
                    tally[key[pid][opt]] += 1
                    total += 1
            if counts:
                table.append([counts.get(c, 0) for c in
                              ("ADAPTIVE", "DIFFICULTY_ONLY", "FIXED_BASELINE")])
        for cond in ("ADAPTIVE", "DIFFICULTY_ONLY", "FIXED_BASELINE"):
            pct = 100.0 * tally[cond] / total if total else 0.0
            print(f"  {cond:<16} chosen {tally[cond]:>3} / {total}  ({pct:.1f}%)")
        k = fleiss_kappa(table) if table else float("nan")
        print(f"  Fleiss' kappa across raters: "
              + (f"{k:.3f}" if not math.isnan(k) else "n/a"))
    else:
        print("\nForced choice: no answers found in the sheets.")

    print("\nReminder for the write-up: this evaluates RECOMMENDATION "
          "APPROPRIATENESS under synthetic scenarios. It does not show that "
          "any child felt better, was readier for a visit, or was less "
          "anxious.")


if __name__ == "__main__":
    main()
