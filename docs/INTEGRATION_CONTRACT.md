# Integration contract between the four components

| Component (member) | What it provides | What the mobile app does |
|---|---|---|
| AI/ML backend, VQA engine (IT23153318) | `POST /vqa/ask` | Sends picture + question, shows the answer exactly as returned |
| Mobile game platform (IT23256682) | Feed, adventure, Calm Corner, caregiver insights | this app |
| Outbreak web platform (IT23415768) | optional `GET /outbreaks/summary` | not wired yet (see below) |
| IoT companion robot (IT23207622) | emotion check-ins, report scans | reads robot check-ins; robot can post them |

## 1. VQA (client done: `lib/services/vqa_client.dart`, screen: `report_screen.dart`)
`POST {baseUrl}/vqa/ask`, `multipart/form-data`:
* `modality`: `skin` | `xray` | `lab`
* `question`: plain text
* `image`: file (JPEG/PNG, max 8 MB)

The app sends **no** child code, name, age or location.

Response `200 application/json` (all three of `answer`, `confidence`, `disclaimer` are required; otherwise the app refuses to show it):
```json
{
  "answer": "plain-language answer",
  "confidence": 0.0,
  "findings": [{"label": "normal", "probability": 0.0}],
  "explanation": {"method": "grad-cam", "heatmapUrl": "https://..."},
  "disclaimer": "Supports, does not replace, a clinician.",
  "requiresClinicianReview": false,
  "modelVersion": "x.y.z"
}
```
`501` / `503` = model not ready (the app says so and shows nothing). Heatmap URLs must be https. Confidence below 0.6, or `requiresClinicianReview: true`, shows a red "please show a doctor" banner.

## 2. Sessions, check-ins, robot (server done: `backend/server.py`, 6 tests)
`GET /sessions/ping`, `POST /sessions/<child>/records`, `POST /sessions/<child>/checkin`, `GET /sessions/<child>/latest-checkin`.
Robot rule: a robot check-in has `source` = `KARA` (or `robot`). The app only trusts a robot check-in that is recent; a simulated one is stored as `KARA_SIMULATED`.

## 3. Outbreak platform (not wired)
If the group wants it, a Grown-ups card could show `GET /outbreaks/summary?country=LK` (`{"updated": ISO date, "items": [{"disease","region","severity"}]}`). Agree the schema first; the app would only display it with its source and date.

## 4. Everything over HTTPS
The app refuses to upload or call over plain http.
