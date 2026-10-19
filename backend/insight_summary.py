"""Turns the Support plan's own aggregated numbers into one short, plain
paragraph using a pretrained LLM, as a writing layer ONLY.

Important: this module invents nothing. It is never given raw sessions, a
child's name, or any identifier -- only numbers the rule engine in
lib/insights/support_plan.dart already computed (band, shares, counts). If
the key is missing, the call fails, times out, or the model's own text
fails the safety check below, the caller gets {"source": "fallback"} and
must show the rule-based text that was already on screen. This is a writing
layer over the rule engine's findings, not a new prediction, and it changes
nothing about what the rule engine decided.

Provider-agnostic: reads MINDY_LLM_PROVIDER ("anthropic" or "openai"),
MINDY_LLM_API_KEY and optionally MINDY_LLM_MODEL from the environment (or a
local .env file -- see load_dotenv below). No third-party pip package is
used; both providers are called with the standard library's urllib so the
backend keeps its "standard library only" rule.
"""
import json
import os
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

# Terms that must never appear in the written-out paragraph, because this
# project never diagnoses, labels, or claims a clinical construct. This list
# intentionally overlaps with the one checked in
# test/v26_support_plan_test.dart -- the same promise, enforced on both
# sides of the API call.
BANNED_TERMS = [
    "diagnos", "disorder", "you have", "is anxious", "is depressed",
    "adhd", "autis", "ptsd", "ocd", "bipolar", "syndrome", "psychiatric",
    "mental illness", "trauma", "clinical", "disease", "pathology",
]

MAX_CHARS = 700
_DEFAULT_MODEL = {
    "anthropic": "claude-3-5-haiku-20241022",
    "openai": "gpt-4o-mini",
}


class LLMError(Exception):
    """Any failure talking to the provider (network, auth, bad response)."""


def load_dotenv(path=None):
    """Loads KEY=VALUE lines from a .env file into os.environ, WITHOUT
    overwriting a variable that is already set in the real environment.
    Blank lines and lines starting with '#' are skipped. No dependency on
    python-dotenv; this is intentionally small."""
    path = path or os.path.join(HERE, ".env")
    if not os.path.isfile(path):
        return
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


def get_llm_config():
    """Reads the provider config from the environment. Returns None if the
    LLM layer is not configured (no provider, or no key) -- the caller must
    then skip straight to the fallback, never attempting a network call."""
    provider = (os.environ.get("MINDY_LLM_PROVIDER") or "").strip().lower()
    api_key = (os.environ.get("MINDY_LLM_API_KEY") or "").strip()
    if provider not in ("anthropic", "openai") or not api_key:
        return None
    model = (os.environ.get("MINDY_LLM_MODEL") or "").strip() or _DEFAULT_MODEL[provider]
    timeout_s = float(os.environ.get("MINDY_LLM_TIMEOUT_S") or 8)
    return {"provider": provider, "api_key": api_key, "model": model, "timeout_s": timeout_s}


_INSTRUCTIONS = (
    "You are turning a children's app's own already-computed numbers into one short "
    "note for a parent or caregiver. Rules, follow all of them:\n"
    "1. Use ONLY the numbers given below. Never invent a number, a date, or a detail "
    "not present in the JSON.\n"
    "2. Never use a diagnostic, clinical or labelling word (for example: diagnosis, "
    "disorder, anxious, depressed, ADHD, autism, trauma, syndrome, disease).\n"
    "3. Never say what caused anything. Describe only what the numbers show.\n"
    "4. Write 2 to 3 short sentences, warm and plain, that a tired parent can read in "
    "ten seconds.\n"
    "5. If the numbers are thin or mixed, say so plainly instead of overstating.\n"
    "6. Output ONLY the paragraph. No heading, no bullet points, no preamble.\n\n"
    "Numbers:\n"
)


def build_prompt(signals):
    """[signals] is a plain JSON-serialisable dict of aggregated numbers --
    see lib/services/insight_summary_service.dart for exactly what it sends.
    No child name or identifier should ever be in it; this function doesn't
    strip one out, so that check belongs to the caller building [signals]."""
    return _INSTRUCTIONS + json.dumps(signals, indent=2, sort_keys=True)


def _post_json(url, headers, payload, timeout_s):
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raise LLMError("provider returned HTTP %s" % e.code) from e
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise LLMError("could not reach the provider: %s" % e) from e
    except json.JSONDecodeError as e:
        raise LLMError("provider response was not valid JSON") from e


def call_llm(prompt, config):
    """Calls the configured provider once. Returns the raw text, or raises
    LLMError. Callers must still run the result through validate_output
    before showing it to anyone."""
    if config["provider"] == "anthropic":
        body = _post_json(
            "https://api.anthropic.com/v1/messages",
            {
                "x-api-key": config["api_key"],
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            {
                "model": config["model"],
                "max_tokens": 220,
                "messages": [{"role": "user", "content": prompt}],
            },
            config["timeout_s"],
        )
        try:
            return "".join(b.get("text", "") for b in body["content"]).strip()
        except (KeyError, TypeError) as e:
            raise LLMError("unexpected Anthropic response shape") from e

    if config["provider"] == "openai":
        body = _post_json(
            "https://api.openai.com/v1/chat/completions",
            {
                "Authorization": "Bearer %s" % config["api_key"],
                "content-type": "application/json",
            },
            {
                "model": config["model"],
                "max_tokens": 220,
                "messages": [{"role": "user", "content": prompt}],
            },
            config["timeout_s"],
        )
        try:
            return body["choices"][0]["message"]["content"].strip()
        except (KeyError, IndexError, TypeError) as e:
            raise LLMError("unexpected OpenAI response shape") from e

    raise LLMError("unknown provider %r" % config["provider"])


def validate_output(text):
    """Returns (ok, reason). Rejects anything empty, oversized, or that
    contains a banned term. This is the safety net: if the model ignores
    its instructions, the fallback is used instead of showing the text."""
    if not text or not text.strip():
        return False, "empty response"
    if len(text) > MAX_CHARS:
        return False, "response too long"
    low = text.lower()
    for term in BANNED_TERMS:
        if term in low:
            return False, "response used a disallowed term: %r" % term
    return True, None


def generate_summary(signals, config=None):
    """The one function callers should use. Never raises: any failure comes
    back as a fallback result with a reason, so the server can always
    respond 200 and let the app show its own rule-based text instead.

    Returns one of:
      {"source": "llm", "text": "..."}
      {"source": "fallback", "reason": "..."}
    """
    cfg = config if config is not None else get_llm_config()
    if cfg is None:
        return {"source": "fallback", "reason": "LLM layer not configured"}
    try:
        raw = call_llm(build_prompt(signals), cfg)
    except LLMError as e:
        return {"source": "fallback", "reason": str(e)}
    except Exception as e:  # keeps the "never raises" promise even if a
        # provider's SDK-free parsing hits a bug we didn't anticipate.
        return {"source": "fallback", "reason": "unexpected error: %s" % e}
    ok, reason = validate_output(raw)
    if not ok:
        return {"source": "fallback", "reason": reason}
    return {"source": "llm", "text": raw.strip()}
