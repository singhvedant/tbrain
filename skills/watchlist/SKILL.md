---
name: watchlist
description: Manage tracked candidate sets — instruments the operator is watching for a trigger but hasn't traded yet. Lightweight staging area that promotes names into theses or trades when acted on.
triggers:
  - "add to watchlist"
  - "watch this"
  - "keep an eye on"
  - "I'm watching"
  - "show my watchlist"
  - "what am I watching"
writes_pages:
  - "watchlists/*"
---

# watchlist — staged candidates with triggers

A `watchlist` page is a named set of instruments the operator is tracking for
a condition that hasn't fired yet. It is deliberately lightweight: a name on a
watchlist carries a **trigger** and a pointer to the `setup` that would make it
actionable. When the trigger fires, the name graduates to a `thesis` or a
`trade` — the watchlist is a staging area, not a graveyard.

## When to invoke

- "Add NVDA to my breakout watchlist" / "watch this name"
- "Show my watchlist" / "what am I watching for earnings this week"
- Reviewing/pruning stale watch items

## Frontmatter

```yaml
---
type: watchlist
name: breakout-candidates
instruments: [nvda, mu, smci]    # watches edges
---
```

## Body — one block per name

```markdown
## nvda
- trigger: daily close > 175 on >1.5x avg volume
- setup: opening-range-breakout
- why watching: ai-capex-cycle-2026 thesis, awaiting confirmation
- added: 2026-06-20
```

## How to write

```bash
gbrain query "watchlist <name>"        # find existing before creating
gbrain capture --file watchlist.md
```

## Lifecycle rules

- When a trigger fires and the operator acts → invoke `trade-journal` and
  remove the name from the watchlist (or mark it `promoted`).
- Prune ruthlessly. A watch item older than its catalyst window or whose
  thesis was invalidated should be removed — query
  `gbrain think "stale watchlist names"` periodically.
- Watchlist names should link to a `setup` so `premarket-brief` can tell the
  operator which watched triggers may hit today.
