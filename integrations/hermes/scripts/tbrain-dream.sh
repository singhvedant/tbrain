#!/usr/bin/env bash
# tbrain nightly dream cycle — for Hermes `cron create --script ... --no-agent`.
# Runs gbrain's overnight maintenance (entity sweep, citation fixes, memory
# consolidation, contradiction detection) plus an embed catch-up so the
# auto-captured inbox turns get indexed + filed. stdout is delivered verbatim
# by the --no-agent cron job; keep it short.
set -uo pipefail
GBRAIN="${TBRAIN_BIN:-gbrain}"

echo "tbrain dream cycle — $(date '+%Y-%m-%d %H:%M')"

# Index anything captured since the last run, then run the dream cycle.
"$GBRAIN" sync >/dev/null 2>&1 || true
"$GBRAIN" embed --stale >/dev/null 2>&1 || true

if "$GBRAIN" dream >/tmp/tbrain-dream.out 2>&1; then
  tail -n 3 /tmp/tbrain-dream.out
  echo "✓ dream cycle complete"
else
  echo "⚠ dream cycle hit an error — see /tmp/tbrain-dream.out"
  tail -n 5 /tmp/tbrain-dream.out
fi
