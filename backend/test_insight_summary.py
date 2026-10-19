import json
import os
import tempfile
import unittest
import unittest.mock as mock

import insight_summary as ins


SIGNALS = {
    "band": "mixed",
    "checkIns14d": 9,
    "lowShare": "4 of 9",
    "trend": {"last7": "44%", "prev7": "71%", "direction": "improving"},
}


class ConfigTests(unittest.TestCase):
    def setUp(self):
        for k in ("MINDY_LLM_PROVIDER", "MINDY_LLM_API_KEY", "MINDY_LLM_MODEL",
                  "MINDY_LLM_TIMEOUT_S"):
            os.environ.pop(k, None)

    def test_no_provider_configured_returns_none(self):
        self.assertIsNone(ins.get_llm_config())

    def test_provider_without_key_returns_none(self):
        os.environ["MINDY_LLM_PROVIDER"] = "anthropic"
        self.assertIsNone(ins.get_llm_config())

    def test_unknown_provider_returns_none(self):
        os.environ["MINDY_LLM_PROVIDER"] = "made-up"
        os.environ["MINDY_LLM_API_KEY"] = "x"
        self.assertIsNone(ins.get_llm_config())

    def test_valid_config_uses_default_model(self):
        os.environ["MINDY_LLM_PROVIDER"] = "anthropic"
        os.environ["MINDY_LLM_API_KEY"] = "sk-test"
        cfg = ins.get_llm_config()
        self.assertEqual(cfg["provider"], "anthropic")
        self.assertEqual(cfg["model"], ins._DEFAULT_MODEL["anthropic"])

    def test_explicit_model_overrides_default(self):
        os.environ["MINDY_LLM_PROVIDER"] = "openai"
        os.environ["MINDY_LLM_API_KEY"] = "sk-test"
        os.environ["MINDY_LLM_MODEL"] = "gpt-custom"
        self.assertEqual(ins.get_llm_config()["model"], "gpt-custom")


class DotenvTests(unittest.TestCase):
    def setUp(self):
        for k in ("MINDY_LLM_PROVIDER", "MINDY_LLM_API_KEY"):
            os.environ.pop(k, None)

    def test_loads_values_from_file(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, ".env")
            with open(path, "w") as f:
                f.write("# a comment\n\nMINDY_LLM_PROVIDER=anthropic\n"
                        'MINDY_LLM_API_KEY="sk-from-file"\n')
            ins.load_dotenv(path)
            self.assertEqual(os.environ["MINDY_LLM_PROVIDER"], "anthropic")
            self.assertEqual(os.environ["MINDY_LLM_API_KEY"], "sk-from-file")

    def test_never_overwrites_a_real_env_var(self):
        os.environ["MINDY_LLM_PROVIDER"] = "openai"
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, ".env")
            with open(path, "w") as f:
                f.write("MINDY_LLM_PROVIDER=anthropic\n")
            ins.load_dotenv(path)
            self.assertEqual(os.environ["MINDY_LLM_PROVIDER"], "openai")

    def test_missing_file_is_a_silent_no_op(self):
        ins.load_dotenv("/no/such/path/.env")  # must not raise


class PromptTests(unittest.TestCase):
    def test_prompt_contains_the_exact_numbers_and_the_rules(self):
        p = ins.build_prompt(SIGNALS)
        self.assertIn("44%", p)
        self.assertIn("mixed", p)
        self.assertIn("Never invent a number", p)
        self.assertIn("diagnostic", p)

    def test_prompt_is_valid_json_after_the_instructions(self):
        p = ins.build_prompt(SIGNALS)
        tail = p[p.index("{"):]
        self.assertEqual(json.loads(tail), SIGNALS)


class ValidateOutputTests(unittest.TestCase):
    def test_good_text_passes(self):
        ok, reason = ins.validate_output(
            "Things have been looking up this week. Worried check-ins fell from 71% to 44%.")
        self.assertTrue(ok)
        self.assertIsNone(reason)

    def test_empty_fails(self):
        self.assertEqual(ins.validate_output("")[0], False)
        self.assertEqual(ins.validate_output("   ")[0], False)

    def test_too_long_fails(self):
        ok, reason = ins.validate_output("x" * (ins.MAX_CHARS + 1))
        self.assertFalse(ok)
        self.assertIn("long", reason)

    def test_each_banned_term_is_caught_case_insensitively(self):
        for term in ins.BANNED_TERMS:
            text = f"Your child {term} apparently."
            ok, reason = ins.validate_output(text)
            self.assertFalse(ok, term)
            text_upper = f"Your child {term.upper()} apparently."
            self.assertFalse(ins.validate_output(text_upper)[0], term)

    def test_worried_and_sad_are_not_banned(self):
        ok, _ = ins.validate_output("Your child felt worried and sad less often this week.")
        self.assertTrue(ok)


class GenerateSummaryTests(unittest.TestCase):
    def setUp(self):
        for k in ("MINDY_LLM_PROVIDER", "MINDY_LLM_API_KEY", "MINDY_LLM_MODEL"):
            os.environ.pop(k, None)

    def test_not_configured_is_a_fallback_and_never_calls_the_network(self):
        with mock.patch.object(ins, "call_llm") as m:
            result = ins.generate_summary(SIGNALS)
        m.assert_not_called()
        self.assertEqual(result["source"], "fallback")
        self.assertIn("not configured", result["reason"])

    def test_network_failure_is_a_graceful_fallback(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "call_llm", side_effect=ins.LLMError("boom")):
            result = ins.generate_summary(SIGNALS, config=cfg)
        self.assertEqual(result, {"source": "fallback", "reason": "boom"})

    def test_model_text_with_a_banned_term_is_rejected_not_shown(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "call_llm", return_value="This looks like a disorder."):
            result = ins.generate_summary(SIGNALS, config=cfg)
        self.assertEqual(result["source"], "fallback")
        self.assertIn("disallowed term", result["reason"])

    def test_good_model_text_is_returned_trimmed(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "call_llm", return_value="  A calm, factual note.  "):
            result = ins.generate_summary(SIGNALS, config=cfg)
        self.assertEqual(result, {"source": "llm", "text": "A calm, factual note."})

    def test_never_raises_even_on_an_unexpected_exception(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "call_llm", side_effect=RuntimeError("unexpected")):
            result = ins.generate_summary(SIGNALS, config=cfg)
        self.assertEqual(result["source"], "fallback")
        self.assertIn("unexpected error", result["reason"])


class CallLlmShapeTests(unittest.TestCase):
    """Exercises the provider-specific response parsing without any real
    network access, by mocking _post_json."""

    def test_anthropic_response_shape_is_parsed(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        fake = {"content": [{"type": "text", "text": "Hello "}, {"type": "text", "text": "there."}]}
        with mock.patch.object(ins, "_post_json", return_value=fake):
            self.assertEqual(ins.call_llm("prompt", cfg), "Hello there.")

    def test_anthropic_bad_shape_raises_llm_error(self):
        cfg = {"provider": "anthropic", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "_post_json", return_value={"nope": True}):
            with self.assertRaises(ins.LLMError):
                ins.call_llm("prompt", cfg)

    def test_openai_response_shape_is_parsed(self):
        cfg = {"provider": "openai", "api_key": "x", "model": "m", "timeout_s": 1}
        fake = {"choices": [{"message": {"content": "Hi there."}}]}
        with mock.patch.object(ins, "_post_json", return_value=fake):
            self.assertEqual(ins.call_llm("prompt", cfg), "Hi there.")

    def test_openai_bad_shape_raises_llm_error(self):
        cfg = {"provider": "openai", "api_key": "x", "model": "m", "timeout_s": 1}
        with mock.patch.object(ins, "_post_json", return_value={}):
            with self.assertRaises(ins.LLMError):
                ins.call_llm("prompt", cfg)

    def test_unknown_provider_raises_llm_error(self):
        cfg = {"provider": "made-up", "api_key": "x", "model": "m", "timeout_s": 1}
        with self.assertRaises(ins.LLMError):
            ins.call_llm("prompt", cfg)


if __name__ == "__main__":
    unittest.main()
