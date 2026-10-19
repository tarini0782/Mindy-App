"""Mindy research backend: a tiny HTTP API over SQLite. Standard library only.

Run:      MINDY_STUDY_KEY=choose-a-long-secret python server.py --port 8080
Endpoints (match lib/services/emotion_signal_client.dart):
  GET  /sessions/ping
  POST /sessions/<child>/records        one session record (idempotent)
  POST /sessions/<child>/checkin        one emotion check-in
  GET  /sessions/<child>/latest-checkin
  GET  /sessions/<child>/next-game      proposal Appendix C v1 rule (see decide_game)
  GET  /export/sessions.csv             researcher only: header X-Study-Key
  GET  /export/summary                  researcher only: counts per condition
  POST /insights/summary                writes a short parent-facing paragraph from
                                         already-computed numbers via a pretrained LLM
                                         (see insight_summary.py). Never given a child id
                                         or raw sessions. Falls back to {"source":"fallback"}
                                         when no provider is configured, the call fails, or
                                         the model's text fails the safety check.

The app only uploads over HTTPS. For a real study put this behind a TLS
proxy (Caddy, nginx, Cloudflare Tunnel). Use it only with ethics approval.
"""
import argparse
import csv
import hmac
import io
import json
import os
import re
import sqlite3
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import insight_summary

HERE = os.path.dirname(os.path.abspath(__file__))
ID_RE = re.compile(r"^[A-Za-z0-9_-]{3,40}$")
MAX_BODY = 512 * 1024
_lock = threading.Lock()


def now():
    return datetime.now(timezone.utc).isoformat()


def connect(path):
    db = sqlite3.connect(path, check_same_thread=False)
    db.execute("PRAGMA foreign_keys = ON")
    with open(os.path.join(HERE, "schema.sql"), encoding="utf-8") as f:
        db.executescript(f.read())
    return db


# Proposal Appendix C, v1 decision rule (rule-based, not ML).
V1_RULE = {
    "SCARED": ("calm_breathing_v1", "easy", "slow"),
    "SAD": ("calm_breathing_v1", "easy", "slow"),
    "NEUTRAL": ("standard_v1", "medium", "normal"),
    "CALM": ("standard_v1", "hard", "normal"),
    "HAPPY": ("standard_v1", "hard", "normal"),
}


def decide_game(emotion):
    """Returns the Appendix C selection for an emotion code, or None if unknown."""
    r = V1_RULE.get(str(emotion or "").upper())
    if not r:
        return None
    return {"game": r[0], "difficulty": r[1], "pace": r[2], "rule": "APPENDIX_C_V1"}


def save_session(db, child, j):
    """Returns 'stored' or 'duplicate'. Raises ValueError for bad input."""
    sid = j.get("sessionId")
    if not isinstance(sid, str) or not ID_RE.match(sid):
        raise ValueError("bad sessionId")
    if j.get("anonymousChildId") != child:
        raise ValueError("child id in URL and body differ")
    if not isinstance(j.get("timestamp"), str) or not isinstance(j.get("activity"), str):
        raise ValueError("timestamp and activity are required")
    with _lock:
        cur = db.execute(
            """INSERT OR IGNORE INTO sessions(session_id, child_id, started_at, activity,
               level, difficulty, study_condition, emotion_before, emotion_after, mood_delta,
               completed, duration_seconds, accuracy, successes, mistakes, avg_response_ms,
               support_count, max_support_stage, enjoyment, perceived_difficulty,
               recommendation_reason, received_at, raw_json)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (sid, child, j["timestamp"], j["activity"], j.get("level"), j.get("difficulty"),
             j.get("studyCondition"), j.get("emotionBefore"), j.get("emotionAfter"),
             j.get("moodDelta"), 1 if j.get("completed") else 0, j.get("durationSeconds"),
             j.get("accuracy"), j.get("successes"), j.get("mistakes"),
             j.get("averageResponseTimeMs"), j.get("supportCount"), j.get("maxSupportStage"),
             j.get("enjoyment"), j.get("perceivedDifficulty"), j.get("recommendationReason"),
             now(), json.dumps(j)))
        if cur.rowcount == 0:
            db.commit()
            return "duplicate"
        for e in (j.get("events") or [])[:2000]:
            if isinstance(e, list) and len(e) >= 2:
                db.execute("INSERT INTO events(session_id,t_ms,type_code,value_ms) VALUES (?,?,?,?)",
                           (sid, int(e[0]), int(e[1]), e[2] if len(e) > 2 else None))
        db.commit()
        return "stored"


CSV_COLS = ["session_id", "child_id", "started_at", "activity", "level", "difficulty",
            "study_condition", "emotion_before", "emotion_after", "mood_delta", "completed",
            "duration_seconds", "accuracy", "successes", "mistakes", "avg_response_ms",
            "support_count", "max_support_stage", "enjoyment", "perceived_difficulty"]


def export_csv(db):
    out = io.StringIO()
    w = csv.writer(out)
    w.writerow(CSV_COLS)
    q = "SELECT %s FROM sessions ORDER BY child_id, started_at" % ",".join(CSV_COLS)
    for row in db.execute(q):
        w.writerow(row)
    return out.getvalue()


def summary(db):
    rows = db.execute("""SELECT study_condition, COUNT(*), COUNT(DISTINCT child_id),
                         AVG(mood_delta) FROM sessions GROUP BY study_condition""").fetchall()
    return [{"studyCondition": r[0], "sessions": r[1], "children": r[2],
             "meanMoodDelta": None if r[3] is None else round(r[3], 3)} for r in rows]


def make_handler(db, study_key):
    class H(BaseHTTPRequestHandler):
        server_version = "MindyBackend/1"

        def log_message(self, *a):  # keep child IDs out of logs
            pass

        def _send(self, code, body, ctype="application/json"):
            data = body if isinstance(body, bytes) else body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def _json(self, code, obj):
            self._send(code, json.dumps(obj))

        def _body(self):
            n = int(self.headers.get("Content-Length") or 0)
            if n <= 0 or n > MAX_BODY:
                raise ValueError("body missing or too large")
            return json.loads(self.rfile.read(n).decode("utf-8"))

        def _researcher(self):
            given = self.headers.get("X-Study-Key", "")
            if not study_key or not hmac.compare_digest(given, study_key):
                self._json(401, {"error": "researcher key required"})
                return False
            return True

        def do_GET(self):
            p = self.path.split("?")[0].strip("/").split("/")
            try:
                if p == ["sessions", "ping"]:
                    return self._json(200, {"ok": True})
                if len(p) == 3 and p[0] == "sessions" and p[2] == "latest-checkin" and ID_RE.match(p[1]):
                    r = db.execute("""SELECT emotion, source, at FROM checkins WHERE child_id=?
                                      AND lower(source) IN ('robot','kara') ORDER BY at DESC LIMIT 1""",
                                   (p[1],)).fetchone()
                    if not r:
                        return self._json(404, {"error": "none"})
                    return self._json(200, {"emotion": r[0], "source": r[1], "timestamp": r[2]})
                if len(p) == 3 and p[0] == "sessions" and p[2] == "next-game" and ID_RE.match(p[1]):
                    r = db.execute("""SELECT emotion FROM checkins WHERE child_id=? AND emotion IS NOT NULL
                                      ORDER BY at DESC LIMIT 1""", (p[1],)).fetchone()
                    d = decide_game(r[0]) if r else None
                    if not d:
                        return self._json(404, {"error": "no usable check-in; show the in-app check-in"})
                    return self._json(200, d)
                if p == ["export", "sessions.csv"]:
                    if self._researcher():
                        self._send(200, export_csv(db), "text/csv")
                    return
                if p == ["export", "summary"]:
                    if self._researcher():
                        self._json(200, summary(db))
                    return
                self._json(404, {"error": "not found"})
            except Exception:
                self._json(500, {"error": "server error"})

        def do_POST(self):
            p0 = self.path.split("?")[0].strip("/").split("/")
            if p0 == ["insights", "summary"]:
                try:
                    j = self._body()
                    signals = j.get("signals") if isinstance(j, dict) else None
                    if not isinstance(signals, dict):
                        return self._json(400, {"error": "signals object required"})
                except (ValueError, json.JSONDecodeError) as e:
                    return self._json(400, {"error": str(e)})
                try:
                    return self._json(200, insight_summary.generate_summary(signals))
                except Exception:
                    # Never 500 here: the caller's whole purpose is a graceful
                    # fallback, so give it one even if something unexpected broke.
                    return self._json(200, {"source": "fallback", "reason": "server error"})

            p = self.path.split("?")[0].strip("/").split("/")
            if len(p) != 3 or p[0] != "sessions" or not ID_RE.match(p[1]):
                return self._json(404, {"error": "not found"})
            try:
                j = self._body()
                if not isinstance(j, dict):
                    raise ValueError("object expected")
                if p[2] == "records":
                    return self._json(200, {"result": save_session(db, p[1], j)})
                if p[2] == "checkin":
                    with _lock:
                        db.execute("INSERT INTO checkins(child_id,emotion,source,at) VALUES (?,?,?,?)",
                                   (p[1], j.get("emotion"), j.get("source"), j.get("timestamp") or now()))
                        db.commit()
                    return self._json(200, {"result": "stored"})
                self._json(404, {"error": "not found"})
            except (ValueError, KeyError, TypeError, json.JSONDecodeError) as e:
                self._json(400, {"error": str(e)})
            except Exception:
                self._json(500, {"error": "server error"})

    return H


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--db", default="mindy.sqlite3")
    a = ap.parse_args()
    insight_summary.load_dotenv()
    key = os.environ.get("MINDY_STUDY_KEY", "")
    if not key:
        print("MINDY_STUDY_KEY not set: export endpoints are disabled.")
    srv = ThreadingHTTPServer(("0.0.0.0", a.port), make_handler(connect(a.db), key))
    print("Mindy backend on port", a.port)
    srv.serve_forever()


if __name__ == "__main__":
    main()
