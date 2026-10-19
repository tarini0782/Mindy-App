import json, os, tempfile, threading, unittest, unittest.mock as mock, urllib.request, urllib.error
from http.server import ThreadingHTTPServer
import server
import insight_summary

def rec(sid, child="P-ABC123", **kw):
    d = {"sessionId": sid, "anonymousChildId": child, "timestamp": "2026-01-01T10:00:00",
         "activity": "carrot_catch", "level": 2, "difficulty": "Medium",
         "studyCondition": "ADAPTIVE", "emotionBefore": "SAD", "emotionAfter": "CALM",
         "moodDelta": 2, "completed": True, "events": [[100, 1, None], [900, 2, 450.0]]}
    d.update(kw)
    return d

class T(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp()
        cls.db = server.connect(os.path.join(cls.tmp, "t.db"))
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), server.make_handler(cls.db, "secret-key-123"))
        cls.base = "http://127.0.0.1:%d" % cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()
    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def call(self, method, path, body=None, headers=None):
        data = None if body is None else json.dumps(body).encode()
        r = urllib.request.Request(self.base + path, data=data, method=method,
                                   headers={"Content-Type": "application/json", **(headers or {})})
        try:
            with urllib.request.urlopen(r) as resp:
                return resp.status, resp.read().decode()
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode()

    def test_ping(self):
        self.assertEqual(self.call("GET", "/sessions/ping")[0], 200)

    def test_store_is_idempotent_and_saves_events(self):
        c, b = self.call("POST", "/sessions/P-ABC123/records", rec("s-1"))
        self.assertEqual((c, json.loads(b)["result"]), (200, "stored"))
        c, b = self.call("POST", "/sessions/P-ABC123/records", rec("s-1"))
        self.assertEqual(json.loads(b)["result"], "duplicate")
        n = self.db.execute("SELECT COUNT(*) FROM events WHERE session_id='s-1'").fetchone()[0]
        self.assertEqual(n, 2)

    def test_rejects_mismatched_child_and_bad_input(self):
        self.assertEqual(self.call("POST", "/sessions/P-OTHER1/records", rec("s-2"))[0], 400)
        self.assertEqual(self.call("POST", "/sessions/P-ABC123/records", {"x": 1})[0], 400)
        self.assertEqual(self.call("POST", "/sessions/bad%20id/records", rec("s-3"))[0], 404)

    def test_export_needs_key(self):
        self.call("POST", "/sessions/P-ABC123/records", rec("s-4"))
        self.assertEqual(self.call("GET", "/export/sessions.csv")[0], 401)
        self.assertEqual(self.call("GET", "/export/sessions.csv", headers={"X-Study-Key": "wrong"})[0], 401)
        c, b = self.call("GET", "/export/sessions.csv", headers={"X-Study-Key": "secret-key-123"})
        self.assertEqual(c, 200)
        self.assertIn("session_id,child_id", b)
        self.assertIn("s-4", b)

    def test_export_disabled_without_server_key(self):
        h = server.make_handler(self.db, "")
        srv = ThreadingHTTPServer(("127.0.0.1", 0), h)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            r = urllib.request.Request("http://127.0.0.1:%d/export/summary" % srv.server_address[1],
                                       headers={"X-Study-Key": ""})
            with self.assertRaises(urllib.error.HTTPError) as cm:
                urllib.request.urlopen(r)
            self.assertEqual(cm.exception.code, 401)
        finally:
            srv.shutdown()

    def test_robot_checkin_roundtrip_and_app_checkin_not_returned(self):
        self.call("POST", "/sessions/P-ZZZ999/checkin", {"emotion": "HAPPY", "source": "APP", "timestamp": "2026-01-01T00:00:00Z"})
        self.assertEqual(self.call("GET", "/sessions/P-ZZZ999/latest-checkin")[0], 404)
        self.call("POST", "/sessions/P-ZZZ999/checkin", {"emotion": "SAD", "source": "KARA", "timestamp": "2026-01-02T00:00:00Z"})
        c, b = self.call("GET", "/sessions/P-ZZZ999/latest-checkin")
        self.assertEqual(json.loads(b)["emotion"], "SAD")

    def test_next_game_follows_appendix_c_rule(self):
        c = "P-RULE01"
        self.assertEqual(self.call("GET", "/sessions/%s/next-game" % c)[0], 404)
        for emo, game, diff, pace in [("SCARED", "calm_breathing_v1", "easy", "slow"),
                                      ("SAD", "calm_breathing_v1", "easy", "slow"),
                                      ("NEUTRAL", "standard_v1", "medium", "normal"),
                                      ("CALM", "standard_v1", "hard", "normal"),
                                      ("HAPPY", "standard_v1", "hard", "normal")]:
            self.call("POST", "/sessions/%s/checkin" % c, {"emotion": emo, "source": "APP", "timestamp": "2026-02-%02dT00:00:00Z" % (10 + ["SCARED","SAD","NEUTRAL","CALM","HAPPY"].index(emo))})
            st, b = self.call("GET", "/sessions/%s/next-game" % c)
            j = json.loads(b)
            self.assertEqual((st, j["game"], j["difficulty"], j["pace"]), (200, game, diff, pace))

    def test_insights_summary_endpoint_falls_back_without_config(self):
        for k in ("MINDY_LLM_PROVIDER", "MINDY_LLM_API_KEY"):
            os.environ.pop(k, None)
        st, body = self.call("POST", "/insights/summary", {"signals": {"band": "mixed"}})
        self.assertEqual(st, 200)
        self.assertEqual(json.loads(body)["source"], "fallback")

    def test_insights_summary_endpoint_rejects_missing_signals(self):
        st, body = self.call("POST", "/insights/summary", {"nope": True})
        self.assertEqual(st, 400)

    def test_insights_summary_endpoint_returns_llm_text_when_mocked(self):
        with mock.patch.object(insight_summary, "generate_summary",
                                return_value={"source": "llm", "text": "A calm note."}):
            st, body = self.call("POST", "/insights/summary", {"signals": {"band": "settled"}})
        self.assertEqual(st, 200)
        self.assertEqual(json.loads(body), {"source": "llm", "text": "A calm note."})

    def test_insights_summary_never_receives_a_child_id_in_the_path(self):
        # The endpoint is deliberately NOT scoped under /sessions/<child>/...;
        # this just documents that choice stays true.
        st, _ = self.call("POST", "/insights/P-SOMECHILD/summary", {"signals": {}})
        self.assertEqual(st, 404)


if __name__ == "__main__":
    unittest.main()
