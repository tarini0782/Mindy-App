#!/usr/bin/env python3
"""Power for the recommendation-appropriateness study.

    python3 tool/power_simulation.py

Why a simulation and not a formula: the ratings are clustered by rater and
by profile, so a textbook paired-t power calculation on "24 observations"
is wrong. The pre-specified analysis averages over raters within each
profile and condition, then tests the within-profile difference. In that
difference the profile main effect and the rater main effect cancel, which
leaves two sources of variance:

    Var(profile-level difference) = SD_profile_x_condition^2
                                    + 2 * SD_residual^2 / n_raters

So the number of RATERS matters more than the number of profiles, which is
the practical finding: recruit a fifth rater before adding more profiles.

The assumed values below are assumptions, not measurements. After the real
study, report the observed profile-by-condition SD so a future study can
plan from a measured value.
"""

import numpy as np
from scipy import stats

SD_RESID = 0.70          # per-rating noise on the 1-5 composite
SD_PROFILE_X_COND = 0.30 # raters disagree about which profile suits which arm
N_SIM = 20000
ALPHA = 0.05
SEED = 20261018


def power(n_profiles, n_raters, delta, sd_resid=SD_RESID,
          sd_pc=SD_PROFILE_X_COND, n_sim=N_SIM, alpha=ALPHA, seed=SEED):
    rng = np.random.default_rng(seed)
    sd = np.sqrt(sd_pc ** 2 + sd_resid ** 2 * 2 / n_raters)
    hits = 0
    for _ in range(n_sim):
        d = rng.normal(delta, sd, n_profiles)
        try:
            if stats.wilcoxon(d).pvalue < alpha:
                hits += 1
        except ValueError:
            pass
    return hits / n_sim


def main():
    print(__doc__.split("\n\n")[0])
    print(f"\nAssumptions: residual SD {SD_RESID}, profile-by-condition SD "
          f"{SD_PROFILE_X_COND}, {N_SIM} runs per cell, alpha {ALPHA}, "
          f"two-tailed Wilcoxon.\n")
    print(f"{'true diff':>10} {'3r/24p':>8} {'5r/24p':>8} "
          f"{'3r/36p':>8} {'5r/36p':>8}")
    for delta in (0.25, 0.40, 0.50, 0.75, 1.00):
        cells = [power(n, r, delta)
                 for n, r in ((24, 3), (24, 5), (36, 3), (36, 5))]
        print(f"{delta:>10.2f} " + " ".join(f"{c:>8.2f}" for c in cells))

    print("\nSD of the profile-level difference, which drives all of the above:")
    for r in (3, 5):
        for s in (0.20, 0.30, 0.45):
            sd = np.sqrt(s ** 2 + SD_RESID ** 2 * 2 / r)
            print(f"  raters={r}  SD_profile_x_cond={s:.2f}  ->  SD={sd:.3f}")

    print("\nReading: with 24 profiles and 3 raters the study can see a "
          "difference of about 0.4 composite points, not 0.25. Recruit 5 "
          "raters if possible; with only 3, use 36 profiles.")


if __name__ == "__main__":
    main()
