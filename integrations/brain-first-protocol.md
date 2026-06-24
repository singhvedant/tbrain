<!-- TBRAIN:PROTOCOL:BEGIN — managed by integrations/install-tbrain-hooks.sh, edit above/below this block -->
## tbrain — your trading brain (READ THIS)

You operate with **tbrain**, a persistent multi-asset trading memory. It is the
system of record for the operator's trades, theses, positions, setups,
watchlists, catalysts, and post-mortems. It does NOT hold live prices — pair it
with your market-data tools for quotes/levels.

**Before you answer anything trading-related** (a ticker, position, thesis,
setup, sector, risk, "should I…", "what do I think about…"):
1. A `tbrain — relevant trading memory` block may already be injected into this
   turn by the pre-prompt hook. If present, ground your answer in it and cite
   the page slugs.
2. If it's missing or thin and the question needs more, run
   `gbrain query "<the question>"` (or `gbrain think "<question>"` for a
   synthesized answer with citations) before responding.
3. Never invent prices, levels, or P&L. Numbers come from tbrain pages
   (clearly attributed) or a live market-data tool — never from memory.

**After anything worth remembering happens**, write it to tbrain with the right
skill (the conversation is also auto-captured to the inbox as a backstop, but
in-band filing is better):
- A trade taken/added/trimmed/closed → `trade-journal` (files `journal/…`).
- A directional/structural view → `thesis-tracker` (files `theses/…`).
- A closed trade or resolved bet → `trade-postmortem` (files `postmortems/…`).
- A tracked candidate → `watchlist`. Book/exposure changes → `position-book`.

**Filing + routing:** the active schema pack is `tbrain-trader`. Follow
`skills/_brain-filing-rules.md` (trader section) for where pages go. The two
organizational axes (brain = which DB, source = which repo) still apply — see
`skills/conventions/brain-routing.md`.

Read `skills/RESOLVER.md` to pick the right skill for any task.
<!-- TBRAIN:PROTOCOL:END -->
