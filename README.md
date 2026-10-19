# Mindy

An emotion-adaptive activity companion for children, built as a final-year
research prototype (project J26-IT-445, component IT23256682).

A child says how they feel by tapping a picture, plays a short activity chosen
for that feeling, and says how they feel afterwards. Over repeated sessions the
app builds a plain-language account for a caregiver, with the amount of
supporting evidence always stated.

> **Mindy is not a medical or diagnostic tool.** It does not detect, screen for
> or diagnose anything, and no claim is made that it reduces anxiety. See
> `docs/RESEARCH_REPORT.md` §12 for the full limitations.

---

## Status, read this first

**Nothing in this repository has been compiled or run.** It was written without
a Flutter SDK available. The Python backend and the analysis tools *have* been
executed and pass; the Dart code has been reviewed by reading only.

Your first job is to run the Flutter toolchain and fix whatever it reports.

## Setup

You need Flutter 3.x with Dart 3.4 or newer (`flutter --version`).

```bash
# 1. Platform folders are not in this repo. Generate them in place.
#    This does not overwrite lib/, test/, assets/ or pubspec.yaml.
flutter create .

# 2. Dependencies.
flutter pub get
#    If version resolution fails (the pubspec was written without a live
#    pub server to check against):
#    flutter pub upgrade --major-versions

# 3. Check and test.
flutter analyze
flutter test

# 4. Run. The study code has no default; pick your own secret.
flutter run --dart-define=MINDY_STUDY_CODE=choose-a-secret
```

Researcher mode requires a researcher account **and** that study code compiled
in. There is deliberately no default PIN or password anywhere.

## Optional: the research backend

Standard library Python only, no pip install needed.

```bash
cd backend
cp .env.example .env     # optional; only for the AI wording layer
python3 server.py
python3 -m unittest discover -p "test_*.py"   # 36 tests, these do pass
```

The app works fully offline without it. The backend only stores synced copies
for research use, and the device remains the source of truth.

## The evaluation study

```bash
# Generate the synthetic profiles and blinded rater sheets from the REAL engine
flutter test test/evaluation_harness_test.dart
# -> build/eval/rater_sheet.csv       give this to raters
# -> build/eval/condition_key.csv     keep this AWAY from raters

# How many raters and profiles you need
python3 tool/power_simulation.py

# Analyse returned ratings
python3 tool/analyse_ratings.py \
    --ratings 'build/eval/ratings_*.csv' \
    --key build/eval/condition_key.csv
```

Rater-facing instructions and the rubric: `docs/RATER_INSTRUCTIONS.md`.

To see the analysis run before you have real ratings:
`python3 tool/make_example_ratings.py` — it writes **invented** numbers,
clearly labelled, purely to prove the pipeline works. They are not a result.

## Repository layout

```
lib/
  characters/   avatar model + painter, the six host characters
  games/        27 activities, the adaptive engine, shared game shell
  insights/     support plan, evidence-gated windows, caregiver wording
  models/       emotion, session, decision trace, study condition
  screens/      28 screens (child flow, caregiver area, research tools)
  services/     storage, accounts, settings, avatars, sync, audio
  theme/        the app-wide palette and ThemeData
  widgets/      shared UI pieces
test/           26 test files (never executed - see Status above)
tool/           evaluation and analysis scripts (these do run)
backend/        optional Python research backend (stdlib only, SQLite)
docs/           research report, architecture, testing, privacy, and more
assets/         audio and art folders (placeholders; the app runs without them)
```

## Where to start reading

| If you want | Read |
| --- | --- |
| The research write-up | `docs/RESEARCH_REPORT.md` |
| How the code fits together | `docs/ARCHITECTURE.md` |
| What is tested and what is not | `docs/TESTING.md` |
| What data is stored and why | `docs/DATA_AND_PRIVACY.md` |
| How activities get chosen | `docs/ADAPTIVE_ENGINE.md` |
| What is still undecided | `docs/HANDOVER.md` |

## Ethics

No real child data has been collected and none may be, until institutional
ethics approval is granted, caregiver consent and child assent are obtained,
and encryption at rest is implemented. All demo data in the app is synthetic
and labelled as such on screen.
