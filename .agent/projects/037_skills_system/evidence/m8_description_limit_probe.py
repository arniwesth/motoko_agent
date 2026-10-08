#!/usr/bin/env python3
"""Do providers accept a long tool description?

ADR-001 D4 puts the skill index in the `Skill` tool's description. If a provider
caps the length of a function description, every request fails on its models,
not only skill calls. Evidence for ADR-001 D4 / V8. Not a gate.

    python3 .agent/projects/037_skills_system/evidence/m8_description_limit_probe.py

One request per (model, description length) through OpenRouter: a single tool
whose description is filler of that length, and a one-word user message. The
answer is whether the request is accepted, and the provider's error if not.
Needs OPENROUTER_API_KEY. About 20 tiny requests; a cent or two.
"""
import json
import os
import urllib.error
import urllib.request

MODELS = [
    "openai/gpt-4o-mini",
    "anthropic/claude-haiku-4.5",
    "google/gemini-2.5-flash",
    "deepseek/deepseek-v4-flash",
    "meta/muse-spark-1.3-contributor",
]
LENGTHS = [1000, 1100, 2300, 16000]
LINE = "- skill-name: what the skill does and when to use it, in a sentence or two. "


def call(model: str, n: int):
    desc = (LINE * (n // len(LINE) + 1))[:n]
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": "Reply with the single word OK."}],
        "tools": [{"type": "function", "function": {
            "name": "Skill", "description": desc,
            "parameters": {"type": "object", "properties": {"name": {"type": "string"}}, "required": ["name"]}}}],
        "max_tokens": 16,
    }).encode()
    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions", data=body,
        headers={"Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}",
                 "Content-Type": "application/json", "X-Title": "motoko_agent"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.load(r)
    except urllib.error.HTTPError as e:
        try:
            d = json.load(e)
        except Exception:
            return f"HTTP {e.code}"
    except Exception as e:
        return f"{type(e).__name__}: {str(e)[:80]}"
    if "choices" in d:
        return "accepted"
    err = d.get("error", {})
    raw = (err.get("metadata") or {}).get("raw", "")
    return f"REJECTED: {err.get('message', '')[:70]} {str(raw)[:190]}".strip()


def main():
    for m in MODELS:
        print(m)
        for n in LENGTHS:
            print(f"  {n:>6} chars: {call(m, n)}")


if __name__ == "__main__":
    main()
