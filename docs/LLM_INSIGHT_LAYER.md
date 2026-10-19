# AI-written insight paragraph (v27)

## What this is
A writing layer on top of the Support plan's own rule-based findings (see `docs/SUPPORT_PLAN.md`).
It does not predict, diagnose, or decide anything. It takes numbers the rule engine already computed
(band, check-in share, trend, which signals fired, the top suggested action titles) and asks a
pretrained LLM to turn them into 2-3 warm, plain sentences. The original rule-based summary is always
shown as well, directly underneath -- this never replaces it.

## Why it exists
Caregivers read a lot of short text in this app. A general-purpose language model is good at combining
several numbers into one readable sentence; the rule engine is not trying to do that job, it is trying
to be traceable. Keeping the two separate means the traceable version is never lost.

## What it is NOT
- Not a trained model. Nothing was fitted to any dataset. It is someone else's already-trained model
  used as a writing tool, with no learning happening on our side.
- Not a new finding. It cannot say anything the rule engine did not already compute.
- Not able to see raw sessions, the child's name, or any identifier. See exactly what is sent in
  `InsightSummaryService.signalsFor` (lib/services/insight_summary_service.dart).

## Architecture
```
Flutter app (off by default, Settings toggle)
   -> InsightSummaryService.refresh()
   -> POST {backend}/insights/summary   {"signals": {...aggregated numbers...}}
   -> backend/server.py -> insight_summary.generate_summary()
   -> (if MINDY_LLM_PROVIDER + MINDY_LLM_API_KEY are set) calls Anthropic or OpenAI
   -> insight_summary.validate_output() checks length + banned clinical terms
   -> {"source": "llm", "text": "..."} or {"source": "fallback", "reason": "..."}
   -> Flutter re-checks the banned-term list itself (defence in depth) before showing it
```

## Privacy and consent
- Off by default. A caregiver must turn it on in Settings, where the exact wording says what is sent.
- Only aggregated numbers travel to the backend, and only on to the third-party LLM provider if one is
  configured. No raw session, no name, no participant id.
- The API key lives only in `backend/.env` (see `backend/.env.example`), never in the Flutter app and
  never committed. `.gitignore` excludes it.
- For a real study, this would need its own line in the consent form: "a short, de-identified summary
  of play patterns may be sent to a third-party AI service to generate wording." Not yet added to
  `consent_screen.dart` -- do this before using it with real participants.

## Failure behaviour
Every failure path (toggle off, no backend address, network error, timeout, non-200, the model ignoring
its instructions) ends the same way: nothing is shown, and the existing rule-based text is what the
caregiver sees. Tested in `test/v27_insight_summary_test.dart` and `backend/test_insight_summary.py`.

## Setting it up
1. Get an API key from console.anthropic.com or platform.openai.com.
2. Copy `backend/.env.example` to `backend/.env` and fill in `MINDY_LLM_PROVIDER` and `MINDY_LLM_API_KEY`.
3. Run the backend as usual; it loads `.env` on startup.
4. In the app: Settings -> set the backend address -> turn on "Smarter wording for the support plan".

## What to say about this at the panel
"This demonstrates a real ML integration -- a pretrained model, called safely, with a guardrail and a
tested fallback -- used as a writing layer over our own rule-based findings. It does not learn from our
data and does not replace the traceable rule engine; it is additive, optional, and off by default."
