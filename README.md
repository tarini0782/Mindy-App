# Mindy – Emotion-Adaptive Activity Companion for Children

**Final Year Research Project:** J26-IT-445  
**Research Component:** IT23256682

## About the Project

Mindy is a mobile application developed as part of my final-year research project. It is designed to help children take part in short activities based on how they are feeling.

At the beginning of a session, the child selects a picture that represents their current feeling. Based on this selection, the application chooses a suitable activity. After completing the activity, the child is asked to select how they feel again.

The application keeps records of previous sessions and uses this information to generate summaries for caregivers. These summaries provide a simple overview of the child's activity history and indicate the amount of supporting evidence available.

**Important:** Mindy is a research prototype and is not a medical or diagnostic tool. It does not detect, screen for or diagnose any medical or psychological condition. It also does not claim to reduce anxiety. Further details about the project's limitations are available in Section 12 of `docs/RESEARCH_REPORT.md`.

---

## Project Status

The application has been developed using Flutter and Dart. The Flutter test suite has been executed, with 355 tests passing during the previous testing run.

An Android debug APK was also successfully built and installed on the Android emulator. However, during subsequent testing, the emulator displayed a black screen and the connection between Flutter and the emulator was interrupted. Further testing is required to verify the complete application flow and runtime behaviour.

The Python backend and research analysis tools have also been tested successfully.

The project is still a research prototype, and additional testing and improvements are required before it can be used for research involving real participants.

## Getting Started

### Requirements

To run the application, the following software is required:

- Flutter 3.x
- Dart 3.4 or newer
- Android Studio or another supported development environment
- Android emulator or a physical Android device (for Android testing)

Check the installed Flutter and Dart versions using:

```bash
flutter --version
```

### Installation

**1. Generate the platform folders**

The platform-specific folders are not included in the repository. Generate the required files by running:

```bash
flutter create .
```

This generates the platform files without replacing the existing `lib/`, `test/`, `assets/` or `pubspec.yaml` files.

**2. Install the dependencies**

```bash
flutter pub get
```

If dependency resolution fails, try:

```bash
flutter pub upgrade --major-versions
```

**3. Run code analysis and tests**

```bash
flutter analyze
flutter test
```

**4. Run the application**

```bash
flutter run --dart-define=MINDY_STUDY_CODE=choose-a-secret
```

Replace `choose-a-secret` with your own study code.

Researcher mode requires both a researcher account and the study code included during compilation. There is no default PIN or password in the application.

---

## Optional Research Backend

The project also includes an optional Python backend. It uses Python's standard library, so no additional packages need to be installed.

To start the backend:

```bash
cd backend
cp .env.example .env
python3 server.py
```

The `.env` file is optional and is only required for the AI wording feature.

To execute the backend tests:

```bash
python3 -m unittest discover -p "test_*.py"
```

The backend includes 36 tests, which have passed during the previous testing run.

The application can also run without the backend. It supports offline use, and the device remains the main source of stored data. The backend is used to store synchronised copies for research purposes.

---

## Research Evaluation

An evaluation process has been included to assess the activity-selection engine and the information presented to caregivers.

The evaluation uses synthetic profiles generated through the actual application engine. It also generates separate files for the raters and the researcher.

### 1. Generate the evaluation files

Run the following command:

```bash
flutter test test/evaluation_harness_test.dart
```

This generates two files:

- `build/eval/rater_sheet.csv` – The file provided to the raters.
- `build/eval/condition_key.csv` – The condition information, which must be kept separately and must not be shared with the raters.

### 2. Calculate the required number of raters and profiles

Run:

```bash
python3 tool/power_simulation.py
```

### 3. Analyse the collected ratings

After receiving the completed rating sheets, run:

```bash
python3 tool/analyse_ratings.py \
    --ratings 'build/eval/ratings_*.csv' \
    --key build/eval/condition_key.csv
```

The rating instructions and evaluation criteria are available in:

`docs/RATER_INSTRUCTIONS.md`

### Example Ratings

The analysis process can also be checked before collecting actual ratings.

Run:

```bash
python3 tool/make_example_ratings.py
```

This generates sample ratings using invented values to check whether the analysis process works correctly. These values are only for testing the analysis pipeline and must not be treated as actual research findings.

---

## Project Structure

The repository is organised into the following folders:

```text
lib/
  characters/   Avatar models, painting logic and six host characters
  games/        27 activities, adaptive engine and shared game components
  insights/     Support plans, evidence tracking and caregiver summaries
  models/       Emotion, session, decision trace and study condition models
  screens/      28 screens covering child, caregiver and researcher sections
  services/     Storage, accounts, settings, avatars, sync and audio
  theme/        Application colours and ThemeData
  widgets/      Reusable interface components

test/           26 Flutter test files
tool/           Evaluation and research analysis scripts
backend/        Optional Python backend with SQLite
docs/           Research, architecture, testing and privacy documentation
assets/         Audio and graphical asset folders
```

### Folder Descriptions

- **`lib/characters/`** – Contains the avatar models, character designs and painting logic for the six host characters.
- **`lib/games/`** – Contains the 27 activities, adaptive engine and shared game components.
- **`lib/insights/`** – Handles caregiver support plans, evidence tracking and summary generation.
- **`lib/models/`** – Contains the data models used for emotions, sessions, decision traces and study conditions.
- **`lib/screens/`** – Contains the screens used in the child, caregiver and researcher sections.
- **`lib/services/`** – Handles data storage, accounts, settings, avatars, synchronisation and audio.
- **`lib/theme/`** – Contains the application's colours, styles and theme settings.
- **`lib/widgets/`** – Contains reusable user interface components.
- **`test/`** – Contains the Flutter test files used to check different parts of the application.
- **`tool/`** – Contains scripts used for evaluation and analysis of research ratings.
- **`backend/`** – Contains the optional Python backend and SQLite database implementation.
- **`docs/`** – Contains the research report, architecture, testing, privacy and other project documentation.
- **`assets/`** – Contains folders for audio and graphical assets. These are optional for running the application.

---

## Project Documentation

The following documents provide more information about the implementation and different parts of the project.

- **Research Report** – `docs/RESEARCH_REPORT.md`  
  Covers the research background, implementation details and project limitations.

- **Architecture** – `docs/ARCHITECTURE.md`  
  Explains the overall application structure and how the different components work together.

- **Testing** – `docs/TESTING.md`  
  Describes the testing process, test coverage and current testing status.

- **Data and Privacy** – `docs/DATA_AND_PRIVACY.md`  
  Explains what information is stored and how data privacy is handled.

- **Adaptive Engine** – `docs/ADAPTIVE_ENGINE.md`  
  Describes how activities are selected and adjusted based on the child's input and previous sessions.

- **Handover** – `docs/HANDOVER.md`  
  Lists the remaining tasks, pending decisions and areas that need further attention.

---

## Ethics and Data Privacy

No real data from children has been collected for this project.

The application currently uses synthetic data for demonstration and testing purposes. This data is labelled as synthetic within the application.

Before collecting any real data from children, institutional ethics approval must be obtained. Caregiver consent and child assent must also be secured, and encryption at rest must be implemented.

These requirements must be fulfilled before proceeding with research involving real child participants.
