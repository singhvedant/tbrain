---
name: trade-journal
description: Log a trade or trade-decision into the brain as a structured journal page. The trader's front door for "I just took (or am about to take) a position." Captures instrument, side, size, entry, stop, target, thesis, and setup so the call can be graded later.
triggers:
  - "log this trade"
  - "journal this trade"
  - "I bought"
  - "I shorted"
  - "I went long"
  - "I'm opening a position"
  - "record this entry"
  - "note this fill"
writes_pages:
  - "journal/*"
---

# trade-journal — log a trade as a gradeable page

When the operator takes a trade (or commits to one), write it to the brain as
a `trade` page under `journal/YYYY-MM/<slug>`. The point is not bookkeeping —
the broker has that. The point is capturing the **rationale at decision time**
so the call can be graded against outcome later (feeds the `trade_outcome`
calibration domain).

tbrain does NOT place orders. This skill records a decision the operator
already made or is about to make.

## When to invoke

- "Log this trade" / "journal this" / "I just went long NVDA"
- The operator describes an entry, add, trim, or exit in natural language
- After any execution the operator wants remembered with its reasoning

## Required frontmatter

Capture as much as the operator gives; never block on missing fields, but
prompt once for `stop` and `thesis` if absent (they are the gradeable core).

```yaml
---
type: trade
instrument: nvda          # links to instruments/nvda via position_in
side: long                # long | short
size: 200                 # shares/contracts/units
entry: 172.40
stop: 165.00              # invalidation — prompt if missing
target: 195.00
thesis: ai-capex-cycle-2026   # links to theses/… via thesis_for (optional)
setup: opening-range-breakout # links to setups/… via uses_setup (optional)
account: fno-margin       # links to accounts/… via held_in
opened_at: 2026-06-23T09:45:00+05:30
conviction: 0.65          # 0–1, seeds the take confidence
---
```

## Body template

```markdown
## Why
<one paragraph: the actual reason for the entry, in the operator's words>

## Invalidation
<what would prove this wrong / where the thesis breaks>

## Risk
<position size as % of book, max loss to stop, correlation to existing book>
```

## How to write it

```bash
gbrain capture --file <trade.md>
# or pipe the composed markdown:
cat trade.md | gbrain capture --stdin
```

Slug convention: `journal/YYYY-MM/<instrument>-<side>-<setup-or-tag>`, e.g.
`journal/2026-06/nvda-long-orb`.

## After writing

- The `## Why` rationale is extractable → `propose_takes` mines it into a
  gradeable take. Don't hand-write takes.
- Tell the operator the page path and remind them to run `trade-postmortem`
  when the position closes so the take resolves.
- If `thesis` was set, confirm the thesis page exists; if not, suggest
  `thesis-tracker` to create it.
- If size/correlation looks heavy versus the existing book, flag it (a
  `risk_flag` take) — query `gbrain think "current exposure to <sector>"`.
