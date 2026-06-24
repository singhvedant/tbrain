"""Hermes gateway hook: capture each completed turn into tbrain.

Fires on `agent:end`, whose context carries both `message` (the user's text)
and `response` (the agent's reply). We shell out to the tbrain/gbrain CLI to
drop the exchange into the inbox for the dream cycle to triage. Non-blocking
and fail-open per Hermes gateway-hook contract.
"""
import datetime
import os
import subprocess

GBRAIN = os.environ.get("TBRAIN_BIN", "gbrain")
MINCHARS = int(os.environ.get("TBRAIN_CAPTURE_MINCHARS", "200"))
TIMEOUT = int(os.environ.get("TBRAIN_CAPTURE_TIMEOUT", "30"))


async def handle(event_type: str, context: dict):
    """Called by the Hermes gateway for the subscribed `agent:end` event."""
    user = (context.get("message") or "").strip()
    resp = (context.get("response") or "").strip()
    if len((user + resp)) < MINCHARS:
        return  # skip operational / trivial turns

    ts = datetime.datetime.now().isoformat(timespec="seconds")
    platform = context.get("platform") or "hermes"
    doc = (
        "---\n"
        "type: note\n"
        f"source: {platform}-conversation\n"
        f"captured_at: {ts}\n"
        "triage: tbrain-auto-capture\n"
        "---\n\n"
        "## User\n" + user + "\n\n"
        "## Assistant\n" + resp + "\n"
    )
    try:
        subprocess.run(
            [GBRAIN, "capture", "--stdin"],
            input=doc, text=True, capture_output=True, timeout=TIMEOUT,
        )
    except Exception:
        # Gateway hooks must never crash the agent pipeline.
        pass
