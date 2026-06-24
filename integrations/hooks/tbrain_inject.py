#!/usr/bin/env python3
"""tbrain context-injection hook — pulls relevant trading memory from tbrain
and injects it into the agent's context BEFORE it answers.

Harness-aware: the same script speaks each harness's native hook protocol.

  --harness hermes        Hermes shell hook on `pre_llm_call`.
                          stdin: {"extra": {"user_message": "...",
                                            "is_first_turn": true}}
                          stdout: {"context": "<retrieved memory>"}  (or {})
  --harness claude-code   Claude Code `UserPromptSubmit` hook.
                          stdin: {"prompt": "..."}
                          stdout: plain text (Claude Code injects stdout as
                          additional context on exit 0).
  --harness codex|generic stdin: {"prompt"|"user_message": "..."}
                          stdout: plain text.

Reads nothing from any harness-specific path — it only shells out to the
tbrain/gbrain CLI, so it is identical across Hermes / Claude Code / Codex.

Env knobs:
  TBRAIN_BIN              CLI binary (default: gbrain)
  TBRAIN_HARNESS         default --harness value
  TBRAIN_INJECT_LIMIT    max results to inject (default: 5)
  TBRAIN_INJECT_TIMEOUT  seconds before giving up on the query (default: 20)
  TBRAIN_INJECT_MODE     search mode (default: conservative — cheap, tight)

Fail-open by design: any error → inject nothing, never block the turn.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

GBRAIN = os.environ.get("TBRAIN_BIN", "gbrain")
LIMIT = int(os.environ.get("TBRAIN_INJECT_LIMIT", "5"))
TIMEOUT = int(os.environ.get("TBRAIN_INJECT_TIMEOUT", "20"))
MODE = os.environ.get("TBRAIN_INJECT_MODE", "conservative")


def read_payload() -> dict:
    try:
        return json.load(sys.stdin) or {}
    except Exception:
        return {}


def extract(harness: str, p: dict):
    """Return (user_text, should_run)."""
    if harness == "hermes":
        extra = p.get("extra") or {}
        text = (extra.get("user_message") or "").strip()
        first = extra.get("is_first_turn")
        # Only inject on the first turn of a task; pre_llm_call fires on every
        # LLM call in the tool loop and we don't want to re-inject each time.
        run = bool(text) and (first is None or bool(first))
        return text, run
    if harness == "claude-code":
        return (p.get("prompt") or "").strip(), bool((p.get("prompt") or "").strip())
    # codex / generic
    extra = p.get("extra") or {}
    text = (p.get("prompt") or p.get("user_message") or extra.get("user_message") or "").strip()
    return text, bool(text)


def query(text: str) -> list:
    cmd = [GBRAIN, "query", text, "--detail", "low",
           "--limit", str(LIMIT), "--mode", MODE, "--json"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
    except Exception:
        return []
    raw = (out.stdout or "").strip()
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except Exception:
        return []
    results = data.get("results") if isinstance(data, dict) else data
    return results if isinstance(results, list) else []


def fmt(results: list) -> str:
    if not results:
        return ""
    lines = [
        "## tbrain — relevant trading memory",
        "_From your trading brain. Ground your answer in it and cite the slugs. "
        "Verify any live price/level with a market-data tool before acting._",
        "",
    ]
    for r in results:
        if not isinstance(r, dict):
            continue
        slug = r.get("slug") or r.get("page_slug") or r.get("page_id") or "?"
        snip = (r.get("compiled_truth") or r.get("snippet") or r.get("content")
                or r.get("text") or "")
        snip = " ".join(str(snip).split())
        if len(snip) > 280:
            snip = snip[:277] + "..."
        lines.append(f"- **{slug}** — {snip}" if snip else f"- **{slug}**")
    return "\n".join(lines) if len(lines) > 3 else ""


def emit(harness: str, block: str) -> None:
    if harness == "hermes":
        # Hermes expects a JSON object on stdout; {} is a clean no-op.
        print(json.dumps({"context": block}) if block else "{}")
    else:
        # Claude Code UserPromptSubmit + Codex: stdout (exit 0) is injected.
        if block:
            print(block)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--harness", default=os.environ.get("TBRAIN_HARNESS", "generic"))
    args = ap.parse_args()
    payload = read_payload()
    text, run = extract(args.harness, payload)
    if not run:
        if args.harness == "hermes":
            print("{}")
        return
    emit(args.harness, fmt(query(text)))


if __name__ == "__main__":
    main()
