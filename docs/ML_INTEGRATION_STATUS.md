# ML integration status (truthful)

* Flutter does **not** run any model. It displays a pasted report JSON (`screening_report.dart`), never computes it.
* `mindy_ml` (Python) is complete as a pipeline: child-level features, child-level split, CV on training children,
  baseline vs models, permutation importance. It has been run **only on synthetic development data** (bannered; results are not evidence).
* No Mindy-specific real dataset exists yet. Real public data: ChildCIdb needs a licence email (see
  `mindy_ml/docs/REAL_DATASET_GUIDE.md`); an adapter + trainer exist but were tested only on a format fixture.
* No accuracy / F1 / validity claims are made anywhere.
* Until a real study exists, the output shown to caregivers is the **rule-based** indicator set.
