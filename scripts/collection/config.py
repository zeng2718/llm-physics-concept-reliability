"""Formal-study paths, prompts, model configurations, and run parameters."""
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[2]
# Protected item content is intentionally not distributed with the public repository.
# Supply local directories through these environment variables when reproducing collection.
QB_DIR = Path(os.environ.get("PHYS_QB_ITEM_DIR", BASE_DIR / "restricted_items"))
RESULTS_DIR = BASE_DIR / "results"
VARIANT_DIR = Path(os.environ.get("PHYS_QB_VARIANT_DIR", BASE_DIR / "restricted_variants"))


def _load_dotenv(path: Path) -> None:
    """Load simple KEY=VALUE entries without overriding existing variables."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


_load_dotenv(Path(__file__).resolve().parent / ".env")

# ---------------------------------------------------------------- prompts
SYSTEM_PROMPT_MAIN = (
    "You are solving a single physics multiple-choice question. Reason through it "
    "step by step, showing your full working. Then end your reply with exactly two lines:\n"
    "ANSWER: <the letter of the one option you choose>\n"
    "CONFIDENCE: <an integer from 0 to 10, where 0 = pure guess and 10 = complete certainty>\n"
    "Choose exactly one option. Write nothing after the CONFIDENCE line."
)

# Formal prompted self-review probe. The user message is assembled from the
# original item and five prior answers and reasoning records.
SYSTEM_PROMPT_PROMPTED_SELF_REVIEW = (
    "You are solving a single physics multiple-choice question. You attempted this same "
    "question several times before, in separate independent sessions, and your attempts did "
    "not all reach the same answer. Below the question you will find your own previous answers "
    "and the reasoning you gave each time.\n\n"
    "Review your previous attempts, work out why they reached different answers, and decide on "
    "your final answer. Then end your reply with exactly two lines:\n"
    "ANSWER: <the letter of the one option you choose>\n"
    "CONFIDENCE: <an integer from 0 to 10, where 0 = pure guess and 10 = complete certainty>\n"
    "Choose exactly one option. Write nothing after the CONFIDENCE line."
)

# ---------------------------------------------------------------- models
# All four formal routes used an OpenAI-compatible message format. The
# temperature parameter was not sent; the effective provider value recorded in
# the study data was 1.0.
MODELS = {
    "kimi": {
        "provider": "openai_compat",
        "display_name": "Kimi K2.6",
        "model_id": "kimi-k2.6",
        "key_env": "MOONSHOT_API_KEY",
        "base_url_env": "MOONSHOT_BASE_URL",
        "base_url_default": "https://api.moonshot.cn/v1",
        "extra": {"thinking": {"type": "enabled"}},
        "send_temperature": False,
        "effective_temperature": 1.0,
    },
    "gpt": {
        "provider": "openai_compat",
        "display_name": "GPT-5.5",
        "model_id": "openai/gpt-5.5",
        "key_env": "OPENAI_API_KEY",
        "base_url_env": "OPENAI_BASE_URL",
        "base_url_default": "https://openrouter.ai/api/v1",
        "extra": {"reasoning_effort": "xhigh"},
        "max_tokens_param": "max_tokens",
        "send_temperature": False,
        "stream": False,
        "effective_temperature": 1.0,
    },
    "claude": {
        "provider": "openai_compat",
        "display_name": "Claude Opus 4.6",
        "model_id": "anthropic/claude-opus-4.6",
        "key_env": "ANTHROPIC_API_KEY",
        "base_url_env": "ANTHROPIC_BASE_URL",
        "base_url_default": "https://openrouter.ai/api/v1",
        "extra": {"reasoning_effort": "max"},
        "max_tokens_param": "max_tokens",
        "send_temperature": False,
        "stream": False,
        "effective_temperature": 1.0,
    },
    "gemini": {
        "provider": "openai_compat",
        "display_name": "Gemini 3.1 Pro Preview",
        "model_id": "google/gemini-3.1-pro-preview",
        "key_env": "GEMINI_API_KEY",
        "base_url_env": "GEMINI_BASE_URL",
        "base_url_default": "https://openrouter.ai/api/v1",
        "extra": {"reasoning_effort": "high"},
        "max_tokens_param": "max_tokens",
        "send_temperature": False,
        "stream": False,
        "effective_temperature": 1.0,
    },
}

# ---------------------------------------------------------------- run params
RUN_DEFAULTS = {
    "temperature": 1.0,     # recorded value; not sent for any formal model route
    "n_runs": 5,
    "max_tokens": 32000,
}
