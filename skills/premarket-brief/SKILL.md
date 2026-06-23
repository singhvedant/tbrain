---
name: premarket-brief
description: Synthesize a pre-market (or pre-session) briefing from the brain — open positions, live theses, today's catalysts, watchlist names in play, and any flagged risks. Reads the brain; does not fetch live quotes.
triggers:
  - "premarket brief"
  - "morning brief"
  - "what's my day look like"
  - "brief me before the open"
  - "what should I watch today"
writes_pages:
  - "briefings/*"
---

# premarket-brief — the brain's morning desk note

Compile a tight briefing the operator reads before the session. This is a
**synthesis** task (`gbrain think`), not retrieval — pull from open positions,
active theses, dated catalysts, and the watchlist, then write the answer with
citations. tbrain holds context, not live prices; the body agent (Hermes /
Claude Code / Codex) pairs this with whatever market-data tool it has.

## When to invoke

- "Premarket brief" / "brief me" / "what's my day look like"
- Start of a trading session
- Best run as a dream-cycle cron just before the open (see cron-scheduler)

## What to assemble

1. **Open book** — `gbrain query "open positions"`: each position, its thesis,
   its stop, days held, and whether its invalidation is near.
2. **Today's catalysts** — `gbrain query "catalysts on <today>"`: earnings,
   expiries, macro prints; map each to affected instruments via `catalyst_for`.
3. **Live theses status** — `gbrain think "which active theses have new
   supporting or contradicting evidence?"`.
4. **Watchlist in play** — names whose trigger conditions (from their `setup`)
   may hit today.
5. **Risk flags** — any `risk_flag` takes: concentration, correlated bets,
   positions through a binary catalyst.

## Output format

```markdown
# Premarket — {date}

## Book ({n} open, net {long/short} bias)
- {instrument} {side} | thesis: {…} | stop {…} | ⚠ if invalidation near

## Catalysts today
- {time} {event} → affects {instruments}

## Theses
- {thesis}: {strengthened|weakened|unchanged} — {one line, cited}

## Watching
- {instrument}: trigger {…} from setup {…}

## Risk
- {flag} — {one line}
```

## How to write

```bash
gbrain think "premarket briefing" > brief.md
gbrain capture --file brief.md     # optional: keep it under briefings/YYYY-MM-DD
```

## Rules

- Cite every claim to a brain page. If the brain doesn't know something
  decision-relevant, say so explicitly ("no catalyst data for X") — gap
  honesty over false confidence.
- Do NOT invent prices, levels, or quotes. Levels come only from stored
  setups/theses or the body's market-data tool, clearly attributed.
- Keep it scannable. A brief that takes 10 minutes to read won't be read
  before the open.
