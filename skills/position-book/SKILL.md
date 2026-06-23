---
name: position-book
description: Maintain the current position book — open/closed holdings per instrument-leg, aggregated from trades, with exposure and correlation analysis across the book. The risk-and-state view that sits between trades and theses.
triggers:
  - "show my book"
  - "what's my exposure"
  - "current positions"
  - "update my position in"
  - "am I over-concentrated"
  - "what's my net exposure to"
writes_pages:
  - "positions/*"
---

# position-book — current state + exposure

A `position` page is the rolled-up state of one instrument-leg: net quantity,
average price, account, status, and hedges. Trades (`journal/`) are the
events; positions are the running balance. This skill keeps positions current
and answers exposure/concentration/correlation questions across the whole
book — feeding `trade_outcome` and `risk_call` calibration.

## When to invoke

- "Show my book" / "current positions" / "what's my exposure to <sector>"
- After a `trade-journal` entry that opens, adds to, trims, or closes a leg —
  update the corresponding position page
- "Am I over-concentrated?" / "what's correlated in my book?"

## Position frontmatter

```yaml
---
type: position
instrument: nvda
net_qty: 200
avg_price: 170.10
account: fno-margin       # held_in edge
status: open              # open | closed
opened_at: 2026-06-23
hedges: [sox-puts]        # hedges edge — what offsets this leg
---
```

## Maintaining the book

- On each new trade for an instrument, recompute `net_qty` + `avg_price` and
  update the position page (don't create a second one for the same leg).
- When `net_qty` hits 0, set `status: closed` and prompt for `trade-postmortem`.

## Exposure analysis

Use the knowledge graph — this is where it earns its keep:

```bash
gbrain query "open positions"
gbrain think "net exposure to <sector>"          # walks in_sector edges
gbrain think "what in my book is correlated"     # walks correlated_with edges
gbrain think "unhedged downside if <catalyst> goes bad"  # catalyst_for + hedges
```

## After updating

- If a sector/theme exposure exceeds the operator's stated limit, raise a
  `risk_flag` take and surface it in the next `premarket-brief`.
- Map second-order exposure: a position can be exposed to a catalyst via a
  `supplies`/`competes_with` neighbor, not just directly. Report those.
- Keep positions and the broker as separate truths — if they diverge, flag the
  reconciliation gap rather than silently trusting the brain.
