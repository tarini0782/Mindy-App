# Where Mindy stores data (and when you need a database)

| Layer | What | Where | Status |
|---|---|---|---|
| On the phone | sessions, events, decision traces, Calm Corner visits, accounts | `shared_preferences` JSON, one key per child | working, tested |
| Research server | every session + every event + check-ins, queryable | `backend/server.py` + `backend/schema.sql` (SQLite; same tables run on PostgreSQL) | working, 6 tests pass (Python) |
| Analysis | CSV/JSON export -> `mindy_ml` | `GET /export/sessions.csv` or the in-app export | working |

* The app is **offline-first**: it always saves on the phone, then `SyncService` uploads in the background to `POST /sessions/<child>/records`. If the server is off, nothing breaks.
* The app only uploads over **HTTPS**. For a pilot run the server behind a TLS proxy (Cloudflare Tunnel, Caddy, nginx) and enter the https URL in the researcher settings.
* The server stores pseudonymous codes only. Export endpoints need `X-Study-Key` (env `MINDY_STUDY_KEY`); with no key set they are disabled.
* Not done: user login on the server, encryption at rest, backups, ethics-approved retention rules. Do not collect real child data until ethics approval and consent are in place.

Run: `cd backend && MINDY_STUDY_KEY=<long secret> python server.py --port 8080` (Python 3, no packages to install). Test: `python -m unittest test_server`.
