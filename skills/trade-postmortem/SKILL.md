---
name: trade-postmortem
description: Review a closed trade or resolved thesis bet against what was known at entry. Records outcome, PnL, and a one-sentence learned pattern. This is the step that closes the calibration loop — without it, edge is never measured.
triggers:
  - "post-mortem this trade"
  - "review this trade"
  - "I closed"
  - "I exited"
  - "this trade is done"
  - "the thesis played out"
  - "the bet resolved"
writes_pages:
  - "postmortems/*"
---

# trade-postmortem — close the calibration loop

When a trade closes or a thesis bet resolves, write a `postmortem` page. This
is the highest-leverage trader habit the brain enforces: it resolves the take
created at entry, populating `trade_outcome` (and `market_call` for thesis
bets) so the operator's real edge becomes measurable instead of vibes.

## When to invoke

- "I closed NVDA" / "exited the short" / "this trade is done"
- A thesis `key_bet` resolves true or false
- ALWAYS prompt for this when a `trade-journal` position is reported closed

## Frontmatter

```yaml
---
type: postmortem
trade: journal/2026-06/nvda-long-orb   # FK → the trade page (reviews edge)
thesis: ai-capex-cycle-2026            # optional, if resolving a thesis bet
bet_id: bet-1                          # optional, which key_bet resolved
resolved_outcome: true                 # did the call work? (boolean)
pnl: 4120                              # realized, account currency
pnl_R: 1.8                             # in R multiples (PnL / initial risk)
resolved_at: 2026-06-30
learned_pattern: "ORB longs into a strong tape work; I exit too early on the first pullback."
---
```

## Body — answer four questions

```markdown
## What I expected
<the entry thesis, restated from the trade page — pull it, don't reinvent>

## What happened
<price path, what actually drove it>

## Process vs luck
<was the outcome due to my edge or randomness? separate the two>

## Adjustment
<one concrete change to the setup/sizing/rules going forward>
```

## How to write

```bash
gbrain query "trade <slug>"        # pull the original entry rationale first
gbrain capture --file <postmortem.md>
```

## After writing

- The `resolved_outcome` + the FK chain resolve the entry take. Confirm with
  `gbrain query "calibration trade_outcome"` that the take graded.
- If `learned_pattern` reveals a repeatable error, update the relevant `setup`
  page (via `position-book`/`thesis-tracker`) so the playbook improves.
- Be honest about process-vs-luck — a winning trade for the wrong reason is a
  `risk_flag`, not a validation. Say so.
