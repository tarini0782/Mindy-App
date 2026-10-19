# Research data dictionary

Sessions CSV columns are listed in `ExportService.csvColumns` (single source of truth) and mirrored in
`mindy_ml/tests/dart_columns.py`. New in v11: `supportCount`, `maxSupportStage`, `attemptsAfterSupport`,
`successesAfterSupport`, `difficultyAdjustments` (all integers; 0 when none).
Practice play (Games tab) is **never stored**, so every exported row is research data.
Derived measures (documented where calculated):
* switch cost, fox-tap rate, miss rate, RT variability, completion rate, mood change: `insights/rule_indicators.dart`
  and docs/RULE_BASED_OUTPUT.md (cut-offs are engineering rules).
* Child-level ML features: `mindy_ml/docs/DATA_DICTIONARY.md`.
Missing values are empty cells. No names or contact details are exported; participant code is researcher-entered.
Alternative explanations to state in reports: age, familiarity with touch screens, fatigue, device, language, accessibility.
