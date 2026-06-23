# tbrain — the trader's brain

tbrain is a **trading memory + synthesis layer**. It is a fork of
[gbrain](https://github.com/garrytan/gbrain): the gbrain engine is kept
byte-for-byte, and a trader **lens** is overlaid on top — the
`tbrain-trader` schema pack, a trader skill set, and trader filing rules.

> Search gives you raw pages. A brain gives you the answer.
> tbrain gives a **trader** the answer — in the operator's own context.

**tbrain is the brain, not the body.** Whatever agent runs it — Hermes,
Claude Code, Codex, Cursor — reads tbrain over MCP/CLI to support its human
trader. tbrain holds *context* (theses, positions, journal, setups,
post-mortems, instrument relationships). It does **not** place orders, route
trades, move money, or hold live market data. Live quotes/fundamentals come
from whatever market-data tool the body has; tbrain remembers and reasons.

---

## What the lens adds on top of gbrain

| Layer | gbrain | tbrain overlay |
|-------|--------|----------------|
| Engine (`src/core`) | hybrid RAG, knowledge graph, dream cycle, calibration | **unchanged** |
| Schema pack | `gbrain-base`, `gbrain-investor`, … | **`tbrain-trader`** (active pack) |
| Page types | person, company, deal, meeting… | + instrument, position, trade, thesis, setup, sector, catalyst, watchlist, postmortem, account, macro |
| Graph edges | works_at, invested_in, founded… | + position_in, hedges, correlated_with, exposes_to, catalyst_for, in_sector, supplies, competes_with, thesis_for |
| Calibration domains | deal_success, founder_evaluation… | trade_outcome, setup_edge, market_call, risk_call |
| Skills | ingest, query, enrich… | + trade-journal, thesis-tracker, trade-postmortem, premarket-brief, position-book, watchlist |

The trader pack is **self-contained**: it re-declares the base-generic types
a trader needs (person/company/meeting/note/source/…) alongside the trader
types, because the vendored engine does not yet flatten the `extends` chain
into pack-aware type inference. See the header comment in
`src/core/schema-pack/base/tbrain-trader.yaml`.

---

## Activate the trader lens

Make `tbrain-trader` the active schema pack (any one is enough):

```bash
# per repo (gbrain.yml)
schema_pack: tbrain-trader

# or env
export GBRAIN_SCHEMA_PACK=tbrain-trader

# or per-call
gbrain <cmd> --pack tbrain-trader
```

The CLI is still invoked as `gbrain` (engine name unchanged); `tbrain` is a
bin alias for the same binary.

---

## The trader loop

```
 capture  ─►  the brain                        ─►  synthesize
 ───────      ──────────────────────────────       ──────────────
 trade-journal    instruments/  theses/  setups/    premarket-brief
 thesis-tracker   positions/    catalysts/          gbrain think "…"
 watchlist        journal/      sectors/  macro/     position-book
                       │                                  │
                       ▼                                  ▼
                  dream cycle (cron)               trade-postmortem
                  enrich · dedup ·                 resolves the take ─►
                  contradiction ·                  calibration:
                  citation-fix                     trade_outcome / setup_edge /
                                                   market_call / risk_call
```

1. **Log decisions** — every trade is a `journal/` page with its rationale;
   every view is a `theses/`/`macro/` page with resolvable `key_bets[]`.
2. **Let the graph wire exposure** — instruments link by sector, supply
   chain, correlation, and hedge, so second-order risk is queryable.
3. **Brief before the session** — `premarket-brief` synthesizes open book,
   today's catalysts, thesis status, and risk flags, with citations.
4. **Close the loop** — `trade-postmortem` on every exit records outcome +
   `learned_pattern`, resolving the entry take so the operator's real edge
   gets measured instead of guessed.

The dream cycle runs all of gbrain's overnight enrichment unchanged: dedup,
contradiction detection (flags broken theses), citation repair, task prep.

---

## Honest limits

- **Not a trading system.** No execution, no backtest, no real-time ticks.
  Memory + reasoning only.
- **Synthesis ≠ truth.** It reasons over *your* notes — garbage in, garbage
  out. Verify numbers against your market-data tool before acting.
- **Edge = your data.** No proprietary research in → no advantage out.
- **Keep brain and broker as separate truths.** On divergence, flag the
  reconciliation gap; never silently trust the brain for position state.

---

For engine internals, install, deployment, and the full skill catalog, see
[`README.md`](README.md) (upstream gbrain docs, still accurate for the engine).
