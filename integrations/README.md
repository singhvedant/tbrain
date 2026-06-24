# tbrain integrations — the ambient memory loop

This directory wires tbrain into an agent *body* so trading memory flows in
both directions automatically, without the agent having to remember to:

1. **Pre-prompt retrieval** — before the agent answers, relevant trading
   memory from tbrain is injected into the turn.
2. **Post-response capture** — after it answers, the exchange is dropped into
   tbrain's inbox for the nightly dream cycle to extract + file.
3. **Dream cycle** — scheduled nightly maintenance that turns raw captures
   into filed `journal/`, `theses/`, `postmortems/`, … pages and updates
   calibration.

It is **harness-aware**: the same hook scripts speak each body's native hook
protocol, so a Hermes agent never gets Claude-Code paths and vice-versa.

## Files

```
integrations/
├── install-tbrain-hooks.sh        # one-shot, idempotent, per-harness wirer
├── brain-first-protocol.md        # snippet appended to SOUL.md/CLAUDE.md/AGENTS.md
├── hooks/
│   ├── tbrain_inject.py           # pre-prompt retrieval (hermes|claude-code|codex)
│   └── tbrain_capture.py          # post-response capture (hermes|claude-code|codex)
└── hermes/
    ├── hooks/tbrain-capture/      # Hermes gateway hook (agent:end) → capture
    │   ├── HOOK.yaml
    │   └── handler.py
    └── scripts/tbrain-dream.sh    # nightly dream cycle for `hermes cron --no-agent`
```

## Quick start

```bash
./install-tbrain-hooks.sh --harness <hermes|claude-code|codex> --brain-repo ~/brain
./install-tbrain-hooks.sh --harness auto --dry-run     # detect + preview only
```

## Harness mapping

| Stage | Hermes | Claude Code | Codex |
|---|---|---|---|
| inject | shell hook `pre_llm_call` (config.yaml) | `UserPromptSubmit` (settings.json) | none — protocol-driven `gbrain query` |
| capture | gateway hook `agent:end` | `Stop` hook | in-band skills + dream cycle |
| schedule | `hermes cron` + `tbrain-dream.sh` | `gbrain autopilot` | `gbrain autopilot` |
| prompt file | `~/.hermes/SOUL.md` | `~/.claude/CLAUDE.md` | `AGENTS.md` |

## Design rules

- **Fail-open.** Any hook error → no injection / no capture, never a blocked
  turn. Hooks must never crash the agent.
- **Cheap.** Inject uses `--mode conservative` + a timeout and fires only on
  the first turn of a task (Hermes `is_first_turn`). Capture skips turns
  shorter than `TBRAIN_CAPTURE_MINCHARS` (default 200).
- **Backstop, not replacement.** The in-band skills (`trade-journal`,
  `thesis-tracker`, …) are the high-quality deliberate-write path. These hooks
  are the always-on safety net so nothing is lost.

## Env knobs

`TBRAIN_BIN` (default `gbrain`), `TBRAIN_HARNESS`, `TBRAIN_INJECT_LIMIT` (5),
`TBRAIN_INJECT_TIMEOUT` (20), `TBRAIN_INJECT_MODE` (conservative),
`TBRAIN_CAPTURE_MINCHARS` (200), `TBRAIN_CAPTURE_TIMEOUT` (30).
