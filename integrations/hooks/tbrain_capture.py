#!/usr/bin/env python3
"""tbrain capture hook — after the agent responds, drop the exchange into
tbrain's inbox so the dream cycle can extract signals (trades, theses,
entities) and file them. The cheap, non-LLM backstop to in-band skills like
trade-journal / signal-detector.

Harness-aware stdin shapes:
  --harness hermes        Hermes shell hook on `post_llm_call`, OR fed the
                          gateway `agent:end` context. Reads message/response
                          from top-level or extra.
  --harness claude-code   Claude Code `Stop` hook. Reads the last user +
                          assistant text if present; otherwise reads a
                          transcript_path JSONL and takes the last turn.
  --harness codex|generic {"message"|"prompt", "response"}

Env knobs:
  TBRAIN_BIN                 CLI binary (default: gbrain)
  TBRAIN_HARNESS            default --harness value
  TBRAIN_CAPTURE_MINCHARS   skip turns shorter than this (default: 200) — keeps
                            operational chatter out of the brain
  TBRAIN_CAPTURE_TIMEOUT    seconds for the capture call (default: 30)

Fail-open: any error → capture nothing, never block the turn.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import subprocess
import sys

GBRAIN = os.environ.get("TBRAIN_BIN", "gbrain")
MINCHARS = int(os.environ.get("TBRAIN_CAPTURE_MINCHARS", "200"))
TIMEOUT = int(os.environ.get("TBRAIN_CAPTURE_TIMEOUT", "30"))


def read_payload() -> dict:
    try:
        return json.load(sys.stdin) or {}
    except Exception:
        return {}


def _from_transcript(path: str):
    """Claude Code Stop hook hands a transcript_path (JSONL). Pull the last
    user message + last assistant message."""
    user, asst = "", ""
    try:
        with open(os.path.expanduser(path), "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    ev = json.loads(line)
                except Exception:
                    continue
                role = ev.get("role") or (ev.get("message") or {}).get("role")
                content = ev.get("content")
                if content is None:
                    content = (ev.get("message") or {}).get("content")
                text = _flatten(content)
                if role == "user" and text:
                    user = text
                elif role == "assistant" and text:
                    asst = text
    except Exception:
        pass
    return user, asst


def _flatten(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if isinstance(b, dict) and b.get("type") in (None, "text"):
                parts.append(str(b.get("text") or ""))
        return " ".join(p for p in parts if p)
    return ""


def extract(harness: str, p: dict):
    extra = p.get("extra") or {}
    if harness == "claude-code":
        tp = p.get("transcript_path")
        if tp:
            return _from_transcript(tp)
        return (p.get("prompt") or "").strip(), \
               (p.get("response") or p.get("last_assistant_message") or "").strip()
    # hermes / codex / generic — accept top-level or extra
    user = (p.get("message") or p.get("prompt") or extra.get("user_message") or "").strip()
    resp = (p.get("response") or extra.get("response") or p.get("assistant") or "").strip()
    return user, resp


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--harness", default=os.environ.get("TBRAIN_HARNESS", "generic"))
    args = ap.parse_args()
    user, resp = extract(args.harness, read_payload())
    if len((user + resp).strip()) < MINCHARS:
        return
    ts = datetime.datetime.now().isoformat(timespec="seconds")
    doc = (
        "---\n"
        "type: note\n"
        f"source: {args.harness}-conversation\n"
        f"captured_at: {ts}\n"
        "triage: tbrain-auto-capture\n"
        "---\n\n"
        "## User\n" + user + "\n\n"
        "## Assistant\n" + resp + "\n"
    )
    try:
        subprocess.run([GBRAIN, "capture", "--stdin"], input=doc, text=True,
                       capture_output=True, timeout=TIMEOUT)
    except Exception:
        pass


if __name__ == "__main__":
    main()
