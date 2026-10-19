# Handover

Everything done in this pass, what is unresolved, and exactly what to run.

> **Version naming.** The delivered archive is `mindy_app_v29.zip`; the code and
> docs tag this work as **v28** (`pubspec.yaml` says `0.28.0+28`). The archive
> number is just the next download in sequence — an earlier zip today was
> already called v28. Inside the project, v28 is the correct tag.
>
> A backup of the previous state is at `mindy_backup_20261018_v28/`, outside
> this folder, taken before any change in this pass.

## 0. First compile (18 Oct 2026)

`flutter analyze` ran for the first time in this project's history and the code
compiled. 142 issues, 20 of them hard errors. **All 20 errors are fixed**, plus
3 warnings and roughly 110 information-level messages. Full breakdown in
`docs/TESTING.md`.

Two of the errors were mine (a dropped import when the parent-summary screen
was split in two). The other eighteen were pre-existing and had simply never
been surfaced, because without a `pubspec.yaml` the project could not be
analysed at all.

Then `flutter test` ran for the first time: **325 passed, 10 failed**. All ten
causes were found and fixed. Two were real product bugs, not test problems:

1. **The AI wording layer was sending the child's nickname to a third-party
   LLM.** The plan's signal and action text is written for a caregiver, so it
   contains the child's name, and `signalsFor()` was passing it through
   verbatim. `SupportPlan` now carries `childName` and the service redacts it.
2. **The demo seeder could silently store nothing.** Session ids omitted the
   child id, and `SessionRepository.add()` drops a duplicate id without error,
   so re-seeding a scenario for a second demo child produced zero sessions.

Both fixes have tests. Re-run `flutter analyze` and `flutter test` to confirm —
these fixes have **not** been executed here, same limitation as always.

## 1. Summary of changes

### The blocker that was found and fixed

**There was no `pubspec.yaml`.** The project could never have been built:
`flutter pub get` would have failed immediately with "no pubspec.yaml file
found", which is probably why nothing has ever compiled. One has been written,
with the dependency list extracted from the actual `package:` imports in `lib/`
and `test/` rather than guessed, plus every asset folder declared.

`analysis_options.yaml` was also missing and has been added.

### Research and documentation

| File | What it is |
| --- | --- |
| `docs/RESEARCH_REPORT.md` | The 14-section research report, written from the implementation. Every place a result would go is marked `[PLACEHOLDER]` |
| `docs/ARCHITECTURE.md` | Layers, the decision engine, how to add an activity |
| `docs/TESTING.md` | What is tested, what is not, what has actually been run |
| `docs/DATA_AND_PRIVACY.md` | What is stored, where it goes, and the database decision with evidence |
| `docs/RATER_INSTRUCTIONS.md` | Rater-facing instructions and the anchored rubric |
| `README.md` | Rewritten: setup, commands, layout, status |

### Evaluation harness

| File | What it does | Runs? |
| --- | --- | --- |
| `test/evaluation_harness_test.dart` | Builds 24 factorial synthetic profiles, runs each through all three conditions using the **real** engine, writes blinded rater sheets and a separate key | Needs Flutter |
| `tool/power_simulation.py` | Simulated power for the clustered paired design | **Executed** |
| `tool/analyse_ratings.py` | Composite, Cronbach's alpha with fallback, Wilcoxon, bootstrap CI, Holm, Krippendorff's alpha, Fleiss' kappa, forced choice | **Executed** |
| `tool/make_example_ratings.py` | Invented demo ratings so the pipeline can be run before raters exist | **Executed** |

The Python pipeline was run end to end here and works. The example run
correctly triggered the pre-registered fallback (Cronbach's alpha 0.61 < 0.70 →
use item 1). **Its numbers are invented and must never appear as results.**

### Engine changes (only the approved ones)

Two parameters on `AdaptiveGameEngine.recommend()`, both defaulting to existing
behaviour:

- `pool` — restricts selectable activities in **every** condition
- `equalSafetyFloor` — applies the distressed-check-in restriction in **every**
  condition

Plus `AdaptiveGameEngine.studyPool`, nine activities. Verification showed the
six-item `fixedSequence` contains **no** medical-familiarisation activity and
only **three** calm-pool members, so a six-activity study would never offer a
medical activity and would push every condition onto the same three options for
a third of the profiles. The nine-item pool fixes both.

Tests: `test/v28_study_mode_test.dart`.

### New look and the character creator

- `CalmColors` retuned to a "magical adventure" palette — deep indigo text on
  soft lilac, storybook violet primary, sky-blue secondary. Because every
  screen references token **names**, all 28 screens re-themed at once with no
  per-screen edits. Contrast ratios for each text/background pair are recorded
  in the source comment; all meet WCAG AA for body text.
- `lib/characters/avatar.dart` — the model: skin, hair style and colour,
  outfit and colour, headwear, wings, face, extras, plus four ready-made
  presets. Stored as integer indices.
- `lib/characters/avatar_painter.dart` — draws it entirely from shapes. No
  image assets, nothing derived from any commercial character. Includes
  `AvatarView`, usable anywhere.
- `lib/services/avatar_service.dart` — persists per child, up to 6 saved
  characters, switch/edit/delete, cleared when a child's data is deleted.
- `lib/screens/character_creator_screen.dart` — the creator, with a live
  preview that updates as choices are made, plus a "my characters" list.
- Wired into: home screen (character strip, tap to edit), Settings, the active
  child hook in `main.dart`, and the per-child reset.

Tests: `test/v28_avatar_test.dart`.

### Repository hygiene

- `.gitignore` rewritten: secrets, participant data, Flutter and Python
  artefacts, and `build/eval/` (which holds the **condition key**).
- Secret scan run: the only match is `sk-from-file`, a deliberate fake inside
  a backend test fixture. No real keys, no `.env`, no participant data files.
- `backend/.env.example` holds placeholders only.

## 2. What was deliberately NOT done

| Not done | Why |
| --- | --- |
| Gameplay features demoted to descriptive-only context | Unresolved research-design decision. The engine today uses performance bands in `performanceFit` and in the level step. Changing that alters an approved architecture — your supervisor decides, not me |
| New medical-familiarisation activities | Gated on whether the approved title keeps medical-visit preparation. Designs are specified in the evaluation plan; nothing is built |
| Re-theming the 27 activities individually | They deliberately do not read the app theme, so a mid-study visual change cannot alter what a child sees. Re-skinning them would risk working mechanics for no research gain |
| Encryption at rest | Specified in `docs/DATA_AND_PRIVACY.md`, not implemented. It is an ethics blocker |
| Any claim that tests pass | No Flutter SDK was available. Nothing Dart has been executed |

## 3. Unresolved decisions, for your supervisor

1. Does the title keep **medical-visit preparation**? Decides whether the three
   familiarisation activities get built.
2. Do gameplay features stay in adaptation, or become descriptive context only?
3. Is the **safety-floored baseline** accepted? It makes the comparison fair and
   ethical, and makes the baseline less "pure". The methods chapter must say
   which was chosen.
4. Is the **nine-activity study pool** accepted for the comparison?
5. Does the exploratory gameplay component stay in the title?
6. Does your institution require ethics approval for **adult raters**? Check
   before recruiting; materials can be prepared meanwhile.

## 4. Exact steps to run it

```bash
cd mindy_app_v25

# platform folders are not in the repo
flutter create .

flutter pub get                  # if resolution fails:
                                 # flutter pub upgrade --major-versions
flutter analyze                  # expect findings; this is the first compile
flutter test                     # expect failures; send the exact output

flutter run --dart-define=MINDY_STUDY_CODE=choose-a-secret
```

Then the parts that already work:

```bash
cd backend && python3 -m unittest discover -p "test_*.py"   # 36 tests pass
cd .. && python3 tool/power_simulation.py
```

## 5. Publishing to GitHub

```bash
git init
git add -A
git status                       # read this before committing
git commit -m "Mindy v28: pubspec, research report, evaluation harness, new theme and character creator"
git branch -M main
git remote add origin https://github.com/<you>/mindy.git
git push -u origin main
```

**Keep the repository private** until you and your supervisor have agreed it
should be public. Before the first push, confirm `git status` shows no `.env`,
no `*.sqlite3`, no `build/eval/`, and no file containing real participant data.

## 6. Next actions, in order

1. Run `flutter create .`, `flutter pub get`, `flutter analyze`, `flutter test`
   and send me the exact output. Nothing else is worth doing until this passes.
2. Take the six decisions in §3 to your supervisor.
3. Run `flutter test test/evaluation_harness_test.dart`, check the generated
   `rater_sheet.csv` by eye, and keep `condition_key.csv` separate.
4. Confirm the rater-study ethics position, then recruit 5 raters if possible.
5. Finish the literature search across the databases listed in the research
   report §5 before writing any novelty claim.
