# Testing and QA (truthful status)
| Check | Result |
|---|---|
| flutter pub get / analyze / test / run | **BLOCKED: no Flutter SDK in the build environment** |
| Dart test files written | account, adaptive engine, export, games, insights, ML data, persistence, rule indicators, support |
| Python `unittest discover` in mindy_ml | **PASSED: 11 tests OK** (synthetic data) |
| Manual bracket/import scan of Dart | done; 2 known false positives |
| Widget/flow tests (register→export) | NOT WRITTEN |
| Device/emulator play-through of 19 games | NOT RUN |
Expect some compile errors on first `flutter analyze`; fix before the demo.

| game_library_test.dart (4 tests) | written; **BLOCKED: no Flutter SDK** |
| checkin_and_summary_test.dart (8 tests) | written; BLOCKED: no Flutter SDK |
| Python test_validate_export.py + earlier | **PASSED: 17 tests OK** (run: python3 -m unittest discover -s tests) |
| new_games_test.dart, parent_summary_test.dart | written; BLOCKED: no Flutter SDK |
| action_games_test.dart | written; BLOCKED: no Flutter SDK |
| art_and_layout_test.dart | written; BLOCKED: no Flutter SDK. Sprites themselves were rendered in Chromium and inspected by eye |
