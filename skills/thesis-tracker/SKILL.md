---
name: thesis-tracker
description: Create and maintain investment/trading theses as living pages with explicit key_bets that resolve over time. The structural-conviction layer above individual trades. Feeds the market_call calibration domain.
triggers:
  - "new thesis"
  - "I think the market"
  - "my view is"
  - "I'm bullish on"
  - "I'm bearish on"
  - "track this thesis"
  - "update my thesis on"
writes_pages:
  - "theses/*"
  - "macro/*"
---

# thesis-tracker — living theses with resolvable bets

A thesis is a directional or structural view that outlives any single trade
("AI capex cycle runs through 2027", "INR bonds roll over"). Write it as a
`thesis` page (or `macro` page for regime-level views) carrying explicit
`key_bets[]` — falsifiable sub-claims that resolve later via post-mortems.
This is what feeds the `market_call` calibration domain: it measures whether
the operator's high-conviction calls are actually right.

## When to invoke

- "New thesis: …" / "my view is …" / "I'm bullish/bearish on …"
- The operator states a multi-week+ directional belief
- Updating an existing thesis as evidence arrives (append, don't overwrite)

## Frontmatter

```yaml
---
type: thesis
thesis_text: "AI datacenter capex compounds through 2027; memory + power are the bottlenecks."
instruments: [nvda, mu, vrt]   # thesis_for edges
sectors: [semiconductors, power]
market_view: bullish           # bullish | bearish | neutral | volatility
vintage: 2026-06
invalidation: "Two consecutive hyperscaler capex guide-downs."
key_bets:
  - id: bet-1
    claim: "NVDA data-center revenue grows >40% YoY in FY27."
    confidence: 0.7
  - id: bet-2
    claim: "Memory pricing stays firm through H1-2027."
    confidence: 0.55
---
```

## Body

State the reasoning, the evidence for and against, and the second-order
exposures. Link instruments/sectors by name so the graph wires `thesis_for`
and `in_sector` edges.

## How to write / update

```bash
gbrain capture --file <thesis.md>          # new
gbrain query "thesis on <topic>"           # find existing before creating
```

Before creating, ALWAYS `gbrain query` for an existing thesis on the topic —
update it rather than forking a duplicate. Append dated evidence under a
`## Updates` section.

## After writing

- Each `key_bet` becomes a `bet`-kind take. When reality resolves a bet, run
  `trade-postmortem` (or a dedicated resolution) to record `resolved_outcome`
  + `learned_pattern` against the bet's `take_id`.
- Surface contradictions: run `gbrain think "what contradicts <thesis>"` and
  note opposing evidence in the thesis body so the dream cycle's
  contradiction detector has signal.
- A trade citing this thesis (via `thesis:` frontmatter) links back
  automatically — no manual cross-linking needed.
