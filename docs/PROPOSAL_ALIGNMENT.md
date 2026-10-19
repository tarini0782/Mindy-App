# Alignment with the submitted proposal (IT23256682, J26-IT-445)

Source: the proposal .docx (Sept 2026). Status words: DONE = implemented and (where stated) tested;
PARTIAL; NOT MEASURED = no measurement exists yet; GAP.

## Scope check (read this first)
The proposal's component is an **emotion-adaptive CBT mini-game app that reduces children's anxiety around
medical visits**, driven by **self-reported** emotion (in-app check-in or robot), **rule-based v1, ML deferred to v2**.
It does NOT mention a swipe feed, attention/compulsivity indicators or behaviour-based screening.
Those parts of this app (Feed tab, behavioural indicators, What-helps report) are extensions. Present them
as exploratory extras, and keep the proposal's evaluation (pre/post anxiety, adaptive vs fixed) as the main study.

## Functional requirements
| FR | Status | Where / note |
|---|---|---|
| FR1 age 3-12 games | PARTIAL | Many mini-games; several older ones still emoji-based. No age-band testing yet. |
| FR2 adjust difficulty/pace/theme from emotion | PARTIAL | Done from SELF-REPORT. The FR text says "real-time emotion/stress readings"; only the robot check-in path exists, no sensors. Reword FR2 or say sensors are v2. |
| FR3 touch/gesture for bed-bound child | PARTIAL | Touch/tap/swipe only. No bed-posture or low-energy usability test. |
| FR4 rewards + feedback | DONE | Rewards, stars, character reactions. |
| FR5 staff/parent pause/resume/exit | DONE | Pause overlay (Keep playing / Leave). Not PIN-gated for staff. |
| FR6 text-light instructions | PARTIAL | One visual instruction bar; not literacy-tested. |
| FR7 log session metrics, send to backend | DONE | Session records + SQLite backend; upload HTTPS-only. Tested (Python). |
| FR8 integrate with robot/engine to launch games | PARTIAL | Robot check-in client + Appendix C endpoints. Real robot never connected. |

## Appendix C contract
- POST /sessions/{id}/checkin {child_id, emotion, source, timestamp}: DONE (client + backend, tested).
- GET /sessions/{id}/next-game: ADDED in v23 backend (scared/sad -> calm_breathing_v1 easy slow;
  neutral -> standard_v1 medium; calm/happy -> standard_v1 hard). Python test passes.
- Fallback to in-app check-in when no recent robot check-in: DONE.
- The Flutter engine is richer than this v1 rule and does not emit these strings. Say so; treat the v1 rule
  as the FIXED rule baseline and the engine as the enhanced condition.

## Non-functional requirements
| NFR | Status |
|---|---|
| Load <3 s, input <100 ms | NOT MEASURED (needs a device profile run) |
| Crash-free >=98% | NOT MEASURED |
| SUS | NOT MEASURED. Proposal gives two thresholds (68 in Table 6, 75 in Table 9). Pick one. |
| Adaptation accuracy | Unit tests exist for the engine; proposal gives 95% (Table 6) and 85% (Table 9). Pick one. |
| HTTPS/TLS | DONE in client (https only). |
| "No telemetry stored unencrypted" | GAP: local data is not encrypted at rest. |
| 50 MB game modules | NOT TESTED |
| Visual-only operability | PARTIAL |
| 60 FPS, no rapid flashes | NOT MEASURED; no flash audit done. |

## Inconsistencies inside the proposal document (fix before submission)
1. Cover ID IT23207622 vs declaration IT23256682.
2. Supervisor title: "Ms." (acknowledgement) vs "Dr." (declaration) Kaushalya.
3. SUS target 68 vs 75; adaptation accuracy 95% vs 85%.
4. Reference numbers clash: [8] = medication adherence in text but "Xploro [8]" in Table 2; [7] used for robots and Woebot; [9]/[10]/[11] reused differently.
5. Heading typos: "53.4 Evaluation Metrics", "3. METHODOLOGY3.1".
6. Table 1 marks Woebot/Wysa "Medical Report Q&A: yes" and says "no app combines..." - soften to "none found in this search".
7. Table 4 says emotions are scared/sad/neutral/happy; Appendix C and the app also use calm (5 states).
8. Specific objective 5 / Table 6 ask for a statistically significant anxiety drop; with a small volunteer sample, say effect sizes and CIs, not significance claims.
9. Group-member names/IDs: confirm spelling with teammates.

## What I did not verify
Flutter code of v23 is not compiled by me (no SDK here). Only the Python backend tests were run (7 pass).

## v24 additions
- Evaluation tooling: Grown-ups > Adaptive vs fixed (condition table incl. load time and share under 3 s) and Usability questionnaire (SUS). Both are descriptive/collection tools; no results exist until real consented sessions are collected.
- Demo mode for presentations: DEMO- participant codes are never uploaded and are bannered.
- Still open: encryption at rest, pre/post anxiety picture scale, crash-rate and latency measurement, real robot connection.

## v25 additions
- Pre/post visual scale: prototype 5-face worry scale with before/after pairing (not validated; choose a validated scale with the supervisors).
- Robot simulator: lets the integration be demonstrated; source stored as KARA_SIMULATED.
- Language: Sinhala and Tamil drafts for child-facing text (native-speaker review needed).
- Encryption at rest: still a GAP (plan in docs/ENCRYPTION_PLAN.md).
