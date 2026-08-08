"""OpenAI-compatible multimodal adapter used by the formal collection routes.

The four evaluated models were accessed through Moonshot or OpenRouter using an
OpenAI-compatible message format. No tools, web access, or retrieval were sent.
"""
from __future__ import annotations
import base64
import os
import time
from dataclasses import dataclass
from pathlib import Path

import httpx

# Wall-clock fallback for streaming requests that do not converge.
_STREAM_DEADLINE_S = 700

# Explicit read/write and connection timeouts used during formal collection.
_TIMEOUT = httpx.Timeout(600.0, connect=15.0)
# Retrying is handled in run_batch.py rather than inside the SDK.
_MAX_RETRIES = 0


@dataclass
class Result:
    content: str
    reasoning_content: str | None
    usage: dict
    finish_reason: str | None
    raw: object


def _usage(u) -> dict:
    """Convert an SDK usage object to a serializable dictionary."""
    if u is None:
        return {}
    if hasattr(u, "model_dump"):
        try:
            return u.model_dump()
        except Exception:
            pass
    if hasattr(u, "to_dict"):
        try:
            return u.to_dict()
        except Exception:
            pass
    return {k: getattr(v, "model_dump", lambda: v)() if hasattr(v, "model_dump") else v
            for k, v in getattr(u, "__dict__", {}).items()}


def image_data_uri(path: Path) -> str:
    b64 = base64.b64encode(Path(path).read_bytes()).decode("ascii")
    return f"data:image/png;base64,{b64}"


def build_user_content(user_text: str, image_paths: list[Path]) -> list[dict]:
    """Build multimodal user content with inline base64 images."""
    parts: list[dict] = [{"type": "text", "text": user_text}]
    for p in image_paths:
        parts.append({"type": "image_url", "image_url": {"url": image_data_uri(p)}})
    return parts


class BaseAdapter:
    def __init__(self, spec: dict, temperature: float, max_tokens: int):
        self.spec = spec
        self.model_id = spec["model_id"]
        self.temperature = temperature
        self.max_tokens = max_tokens

    def complete(self, messages: list[dict]) -> Result:  # pragma: no cover
        raise NotImplementedError


class OpenAICompatAdapter(BaseAdapter):
    """OpenAI-compatible chat-completions adapter."""

    def __init__(self, spec, temperature, max_tokens):
        super().__init__(spec, temperature, max_tokens)
        from openai import OpenAI
        key = os.environ.get(spec["key_env"])
        if not key:
            raise RuntimeError(f"Environment variable {spec['key_env']} is not set")
        base_url = os.environ.get(spec.get("base_url_env", ""), spec.get("base_url_default"))
        self.client = OpenAI(api_key=key, base_url=base_url,
                             timeout=_TIMEOUT, max_retries=_MAX_RETRIES)

    def complete(self, messages: list[dict]) -> Result:
        kw = dict(model=self.model_id, messages=messages)
        kw[self.spec.get("max_tokens_param", "max_tokens")] = self.max_tokens
        if self.spec.get("send_temperature", True):
            kw["temperature"] = self.temperature
        extra = self.spec.get("extra", {})
        if extra:
            kw["extra_body"] = extra

        # The Kimi route used streaming; the OpenRouter routes used one-shot
        # responses. Both return the same normalized Result object.
        if not self.spec.get("stream", True):
            resp = self.client.chat.completions.create(**kw)
            ch = resp.choices[0]; msg = ch.message
            return Result(
                content=msg.content or "",
                reasoning_content=(getattr(msg, "reasoning_content", None)
                                   or getattr(msg, "reasoning", None)),
                usage=_usage(getattr(resp, "usage", None)),
                finish_reason=ch.finish_reason, raw=None,
            )

        # Streaming preserves partial output if a request reaches the deadline.
        kw["stream"] = True
        kw["stream_options"] = {"include_usage": True}
        content_parts, reasoning_parts = [], []
        finish, usage_obj, truncated = None, None, False
        t0 = time.time()
        stream = self.client.chat.completions.create(**kw)
        try:
            for chunk in stream:
                if getattr(chunk, "usage", None):
                    usage_obj = chunk.usage
                if not chunk.choices:
                    continue
                ch = chunk.choices[0]
                d = ch.delta
                if getattr(d, "content", None):
                    content_parts.append(d.content)
                if getattr(d, "reasoning_content", None):
                    reasoning_parts.append(d.reasoning_content)
                if ch.finish_reason:
                    finish = ch.finish_reason
                if time.time() - t0 > _STREAM_DEADLINE_S:
                    truncated = True
                    break
        except Exception:
            if not (content_parts or reasoning_parts):
                raise
            truncated = True
        finally:
            try:
                stream.close()
            except Exception:
                pass
        if truncated and finish is None:
            finish = "timeout"
        return Result(
            content="".join(content_parts),
            reasoning_content="".join(reasoning_parts) or None,
            usage=_usage(usage_obj),
            finish_reason=finish,
            raw=None,
        )


class MockAdapter(BaseAdapter):
    """Offline adapter for pipeline smoke tests."""

    def complete(self, messages: list[dict]) -> Result:
        # Select the first visible option label in the fixture.
        user = next((m for m in messages if m["role"] == "user"), None)
        text = ""
        if user:
            text = user["content"] if isinstance(user["content"], str) else \
                next((p["text"] for p in user["content"] if p["type"] == "text"), "")
        import re
        m = re.search(r"\(([A-Za-z])\)", text)
        letter = (m.group(1).lower() if m else "a")
        n_img = 0 if not user or isinstance(user["content"], str) else \
            sum(1 for p in user["content"] if p.get("type") == "image_url")
        content = (
            "[MOCK] Working through the problem step by step using the relevant "
            f"physics principle. (saw {n_img} image(s))\n\n"
            f"ANSWER: {letter}\nCONFIDENCE: 6"
        )
        return Result(content=content, reasoning_content="[mock thinking]",
                      usage={"mock": True}, finish_reason="stop", raw={"mock": True})


_REGISTRY = {
    "openai_compat": OpenAICompatAdapter,
}


def build_adapter(spec: dict, temperature: float, max_tokens: int, mock: bool = False) -> BaseAdapter:
    if mock:
        return MockAdapter(spec, temperature, max_tokens)
    cls = _REGISTRY.get(spec["provider"])
    if cls is None:
        raise ValueError(f"Unknown provider: {spec['provider']}")
    return cls(spec, temperature, max_tokens)
