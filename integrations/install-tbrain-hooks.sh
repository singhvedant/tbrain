#!/usr/bin/env bash
# install-tbrain-hooks.sh — wire tbrain's memory loop into a specific agent
# harness: pre-prompt retrieval injection, post-response capture, the nightly
# dream cycle, the trader schema pack, and the brain-first protocol.
#
# Harness-aware by design so a Hermes agent never gets Claude-Code paths and
# vice-versa. Idempotent (safe to re-run) and supports --dry-run.
#
#   ./install-tbrain-hooks.sh --harness hermes      --brain-repo ~/brain
#   ./install-tbrain-hooks.sh --harness claude-code --brain-repo ~/brain
#   ./install-tbrain-hooks.sh --harness codex       --brain-repo ~/brain
#   ./install-tbrain-hooks.sh --harness auto         # best-effort detection
#
# Flags: --no-cron (skip dream scheduling), --dry-run (print, change nothing),
#        --yes (non-interactive).
set -uo pipefail

HARNESS="auto"; BRAIN_REPO=""; NO_CRON=0; DRY=0; YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2;;
    --brain-repo) BRAIN_REPO="$2"; shift 2;;
    --no-cron) NO_CRON=1; shift;;
    --dry-run) DRY=1; shift;;
    --yes) YES=1; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/hooks"
INJECT="$HOOKS_DIR/tbrain_inject.py"
CAPTURE="$HOOKS_DIR/tbrain_capture.py"
PROTOCOL="$SCRIPT_DIR/brain-first-protocol.md"
GBRAIN="$(command -v gbrain || command -v tbrain || echo gbrain)"

log()  { echo "[tbrain-hooks] $*"; }
run()  { if [ "$DRY" = 1 ]; then echo "  DRY: $*"; else eval "$*"; fi; }

# --- harness autodetect ---------------------------------------------------
if [ "$HARNESS" = "auto" ]; then
  if [ -d "${HERMES_HOME:-$HOME/.hermes}" ]; then HARNESS="hermes"
  elif [ -d "$HOME/.claude" ]; then HARNESS="claude-code"
  elif [ -d "$HOME/.codex" ]; then HARNESS="codex"
  else log "could not autodetect harness; pass --harness <hermes|claude-code|codex>"; exit 1; fi
  log "autodetected harness: $HARNESS"
fi

chmod +x "$INJECT" "$CAPTURE" 2>/dev/null || true

# --- common: activate the trader pack ------------------------------------
log "activating tbrain-trader schema pack"
run "\"$GBRAIN\" schema use tbrain-trader || true"

# --- common: create the trader directory layout in the brain repo --------
if [ -z "$BRAIN_REPO" ]; then
  BRAIN_REPO="$("$GBRAIN" config get sync.repo_path 2>/dev/null || true)"
fi
if [ -n "$BRAIN_REPO" ]; then
  BRAIN_REPO="${BRAIN_REPO/#\~/$HOME}"
  log "trader directory layout under $BRAIN_REPO"
  run "mkdir -p \"$BRAIN_REPO\"/{instruments,sectors,accounts,theses,setups,macro,watchlists,journal,positions,catalysts,postmortems}"
else
  log "no brain repo known (pass --brain-repo) — skipping directory scaffold"
fi

# --- append the brain-first protocol to a prompt file (idempotent) -------
append_protocol() {
  local target="$1"
  if [ "$DRY" = 1 ]; then echo "  DRY: append protocol to $target"; return; fi
  mkdir -p "$(dirname "$target")"; touch "$target"
  if grep -q "TBRAIN:PROTOCOL:BEGIN" "$target" 2>/dev/null; then
    log "protocol already present in $target (skipped)"
  else
    { echo; cat "$PROTOCOL"; } >> "$target"
    log "appended brain-first protocol to $target"
  fi
}

# =========================================================================
# Per-harness wiring
# =========================================================================
case "$HARNESS" in

  claude-code)
    SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
    log "wiring Claude Code hooks into $SETTINGS"
    if [ "$DRY" = 1 ]; then
      echo "  DRY: merge UserPromptSubmit->tbrain_inject, Stop->tbrain_capture into $SETTINGS"
    else
      INJECT="$INJECT" CAPTURE="$CAPTURE" SETTINGS="$SETTINGS" python3 - <<'PY'
import json, os
p = os.environ["SETTINGS"]; os.makedirs(os.path.dirname(p), exist_ok=True)
try:
    cfg = json.load(open(p))
except Exception:
    cfg = {}
hooks = cfg.setdefault("hooks", {})
def ensure(event, cmd):
    arr = hooks.setdefault(event, [])
    for grp in arr:
        for h in grp.get("hooks", []):
            if h.get("command") == cmd:
                return False
    arr.append({"hooks": [{"type": "command", "command": cmd}]})
    return True
a = ensure("UserPromptSubmit", f'{os.environ["INJECT"]} --harness claude-code')
b = ensure("Stop",            f'{os.environ["CAPTURE"]} --harness claude-code')
json.dump(cfg, open(p, "w"), indent=2)
print(f"  UserPromptSubmit: {'added' if a else 'already present'}")
print(f"  Stop:             {'added' if b else 'already present'}")
PY
    fi
    append_protocol "${CLAUDE_MD:-$HOME/.claude/CLAUDE.md}"
    if [ "$NO_CRON" = 0 ]; then
      log "scheduling dream cycle via gbrain autopilot (Claude Code has no scheduler)"
      run "\"$GBRAIN\" autopilot --install || echo '  (autopilot unavailable — add a crontab calling: $GBRAIN dream)'"
    fi
    ;;

  hermes)
    HHOME="${HERMES_HOME:-$HOME/.hermes}"
    log "wiring Hermes hooks under $HHOME"
    # 1. gateway capture hook (agent:end)
    run "mkdir -p \"$HHOME/hooks\""
    run "cp -r \"$SCRIPT_DIR/hermes/hooks/tbrain-capture\" \"$HHOME/hooks/\""
    # 2. dream-cycle script
    run "mkdir -p \"$HHOME/scripts\""
    run "cp \"$SCRIPT_DIR/hermes/scripts/tbrain-dream.sh\" \"$HHOME/scripts/\" && chmod +x \"$HHOME/scripts/tbrain-dream.sh\""
    # 3. shell hook: pre_llm_call -> inject  (+ auto-accept for non-TTY gateway)
    if [ "$DRY" = 1 ]; then
      echo "  DRY: merge hooks.pre_llm_call -> $INJECT --harness hermes into $HHOME/config.yaml"
    else
      INJECT="$INJECT" CFG="$HHOME/config.yaml" python3 - <<'PY'
import os
try:
    import yaml
except Exception:
    print("  WARN: pyyaml unavailable; add this to ~/.hermes/config.yaml manually:")
    print("  hooks:\n    pre_llm_call:\n      - command: \"%s --harness hermes\"\n  hooks_auto_accept: true" % os.environ["INJECT"])
    raise SystemExit(0)
p = os.environ["CFG"]
try:
    cfg = yaml.safe_load(open(p)) or {}
except Exception:
    cfg = {}
cmd = f'{os.environ["INJECT"]} --harness hermes'
hooks = cfg.setdefault("hooks", {})
arr = hooks.setdefault("pre_llm_call", [])
if not any(isinstance(e, dict) and e.get("command") == cmd for e in arr):
    arr.append({"command": cmd}); added = True
else:
    added = False
cfg["hooks_auto_accept"] = True   # let the non-TTY gateway register shell hooks
yaml.safe_dump(cfg, open(p, "w"), sort_keys=False, default_flow_style=False)
print(f"  pre_llm_call hook: {'added' if added else 'already present'}; hooks_auto_accept=true")
PY
    fi
    append_protocol "$HHOME/SOUL.md"
    # 4. dream cycle via hermes cron (shell script, no LLM)
    if [ "$NO_CRON" = 0 ]; then
      if "$HHOME/../.local/bin/hermes" cron list 2>/dev/null | grep -q "tbrain-dream" \
         || hermes cron list 2>/dev/null | grep -q "tbrain-dream"; then
        log "hermes cron 'tbrain-dream' already exists (skipped)"
      else
        log "scheduling nightly dream cycle via hermes cron"
        run "hermes cron create '0 3 * * *' --name tbrain-dream --script tbrain-dream.sh --no-agent --accept-hooks || echo '  (could not create hermes cron — schedule tbrain-dream.sh manually)'"
      fi
    fi
    ;;

  codex)
    log "Codex has no pre-prompt hook — retrieval is model-driven via the protocol."
    append_protocol "${CODEX_AGENTS_MD:-${BRAIN_REPO:-$PWD}/AGENTS.md}"
    log "post-response capture: Codex has no Stop hook; rely on in-band trade-journal/signal skills + the dream cycle."
    if [ "$NO_CRON" = 0 ]; then
      log "scheduling dream cycle via gbrain autopilot"
      run "\"$GBRAIN\" autopilot --install || echo '  (autopilot unavailable — add a crontab calling: $GBRAIN dream)'"
    fi
    ;;

  *) log "unknown harness: $HARNESS"; exit 1;;
esac

log "done. harness=$HARNESS  pack=tbrain-trader  inject=$INJECT  capture=$CAPTURE"
[ "$DRY" = 1 ] && log "(dry-run — no files changed)"
exit 0
