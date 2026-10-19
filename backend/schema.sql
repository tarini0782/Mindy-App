-- Mindy research database (SQLite; the same tables work in PostgreSQL).
-- Pseudonymous IDs only. No names, emails, birthdays or free-text notes.
CREATE TABLE IF NOT EXISTS sessions (
  session_id         TEXT PRIMARY KEY,
  child_id           TEXT NOT NULL,          -- pseudonymous participant code
  started_at         TEXT NOT NULL,
  activity           TEXT NOT NULL,
  level              INTEGER,
  difficulty         TEXT,
  study_condition    TEXT,                   -- ADAPTIVE | DIFFICULTY_ONLY | FIXED_BASELINE
  emotion_before     TEXT,
  emotion_after      TEXT,
  mood_delta         INTEGER,
  completed          INTEGER,
  duration_seconds   INTEGER,
  accuracy           REAL,
  successes          INTEGER,
  mistakes           INTEGER,
  avg_response_ms    REAL,
  support_count      INTEGER,
  max_support_stage  INTEGER,
  enjoyment          INTEGER,
  perceived_difficulty INTEGER,
  recommendation_reason TEXT,
  received_at        TEXT NOT NULL,
  raw_json           TEXT NOT NULL           -- the full record, so nothing is lost
);
CREATE INDEX IF NOT EXISTS idx_sessions_child ON sessions(child_id, started_at);

CREATE TABLE IF NOT EXISTS events (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id  TEXT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  t_ms        INTEGER NOT NULL,
  type_code   INTEGER NOT NULL,
  value_ms    REAL
);
CREATE INDEX IF NOT EXISTS idx_events_session ON events(session_id);

CREATE TABLE IF NOT EXISTS checkins (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  child_id    TEXT NOT NULL,
  emotion     TEXT,
  source      TEXT,
  at          TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_checkins_child ON checkins(child_id, at);
