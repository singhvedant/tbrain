# tbrain Installation Guide for AI Agents

This is **tbrain** — a trader-focused fork of gbrain. The engine/CLI is still
called `gbrain` (binary aliased as `tbrain` too); the trader identity comes
from the `tbrain-trader` schema pack activated in Step 3. Read `TBRAIN.md` at
the repo root for the trader-specific overview before or after this file —
this file covers full engine install end to end.

Read this entire file, then follow the steps. Ask the user for API keys when needed.
Target: ~30 minutes to a fully working brain.

## TL;DR — the install is NOT done until the memory loop is wired

A tbrain install that stops after `gbrain init` is just a database. The thing
that makes it *tbrain* is the **memory loop** (Step 5.5): every conversation
pulls trading memory in before the agent answers and pushes new memory back
after. **Do not skip it, do not summarize it away.** Minimum viable install:

```bash
# 0. identify harness (see table below) and set it
export TBRAIN_HARNESS=hermes            # | claude-code | codex | generic

# 1. clone (gives you integrations/ + skills/, which the binary-only install lacks)
git clone https://github.com/singhvedant/tbrain.git ~/tbrain
cd ~/tbrain && bun install && bun link
export TBRAIN_REPO="$HOME/tbrain"

# 2. brain + trader pack
gbrain init
gbrain schema use tbrain-trader

# 3. trader skills INTO YOUR HARNESS (yes, even Hermes — ADD the 6 trader skills;
#    Hermes having its own skills is NOT a reason to skip these). --workspace
#    PATH scaffolds into PATH/skills/<name>/, so ~/.hermes -> ~/.hermes/skills/.
[ "$TBRAIN_HARNESS" = hermes ] \
  && gbrain skillpack scaffold --all --workspace ~/.hermes \
  || gbrain skillpack scaffold --all --workspace .   # run from your agent workspace

# 4. THE MEMORY LOOP — inject + capture + dream cycle, wired for your harness
"$TBRAIN_REPO"/integrations/install-tbrain-hooks.sh --harness "$TBRAIN_HARNESS" --brain-repo ~/brain
```

The full guide below expands each line + API keys, search-mode cost choice, and
verification. Read it. But if you only remember one thing: **run step 4.**

## Step 0: Identify YOUR harness FIRST (DO NOT SKIP)

tbrain runs inside a *body* — the agent harness. The harness decides WHERE
config, skills, hooks, and schedules live. Using the wrong harness's paths is
the #1 install failure. Determine which one you are before touching anything:

| You are… | Tell-tale | Home dir | Prompt file | Hooks mechanism | Scheduler |
|---|---|---|---|---|---|
| **Hermes** | running under `hermes`/the Hermes gateway (WhatsApp/Telegram/etc), Python | `~/.hermes/` | `~/.hermes/SOUL.md` | `hooks:` in `~/.hermes/config.yaml` + gateway hooks in `~/.hermes/hooks/` | `hermes cron` |
| **Claude Code** | you read `CLAUDE.md` automatically | `~/.claude/` | `~/.claude/CLAUDE.md` | `hooks` in `~/.claude/settings.json` | `gbrain autopilot` / crontab |
| **Codex** | you read `AGENTS.md` | project dir | `AGENTS.md` | (no pre-prompt hook) | `gbrain autopilot` / crontab |
| **other** | — | — | `AGENTS.md` | — | `gbrain autopilot` / crontab |

Export your harness so the rest of this guide (and the installer) does the
right thing:

```bash
export TBRAIN_HARNESS=hermes        # or: claude-code | codex | generic
```

If you are NOT Claude Code, read `AGENTS.md` at the repo root now — it's the
non-Claude operating protocol. If you fetched this file by URL without cloning:
- `https://raw.githubusercontent.com/singhvedant/tbrain/main/AGENTS.md`
- `https://raw.githubusercontent.com/singhvedant/tbrain/main/llms.txt`
- `https://raw.githubusercontent.com/singhvedant/tbrain/main/llms-full.txt`

## Step 1: Install tbrain

Bun is required (the engine is a Bun + TypeScript runtime). **Clone the repo**
— the global `bun install -g` gives you the `gbrain` binary but NOT the
`integrations/` hooks + `skills/` tree that Step 5 needs, so clone is the
canonical path for a full memory-loop setup:

```bash
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
git clone https://github.com/singhvedant/tbrain.git ~/tbrain
cd ~/tbrain && bun install && bun link
export TBRAIN_REPO="$HOME/tbrain"     # used by later steps + the hook installer
```

(Binary-only quick try: `bun install -g github:singhvedant/tbrain`. Fine for
kicking the tires, but clone before wiring hooks/skills.)

Verify: `gbrain --version` should print a version number. If `gbrain` is not found,
restart the shell or add the PATH export to the shell profile.

> **If `bun install -g` aborts or `gbrain doctor` reports `schema_version: 0`** (Bun
> occasionally blocks the top-level postinstall hook on global installs, so schema
> migrations don't run automatically), the CLI prints a recovery hint pointing at
> [#218](https://github.com/singhvedant/tbrain/issues/218). Run `gbrain apply-migrations --yes`
> to recover. If that doesn't work, fall back to the deterministic install path:
>
> ```bash
> git clone https://github.com/singhvedant/tbrain.git ~/tbrain && cd ~/tbrain
> bun install && bun link
> ```

## Step 2: API Keys

Ask the user for these. gbrain defaults to the ZeroEntropy embedding + reranker stack
(as of v0.36.2.0); OpenAI/Voyage are still supported as fallbacks via `gbrain config
set embedding_model <provider:model>`.

```bash
export ZEROENTROPY_API_KEY=ze-...     # default embedding + reranker (v0.36.2.0+)
export OPENAI_API_KEY=sk-...          # fallback for vector search; also used for chat models
export ANTHROPIC_API_KEY=sk-ant-...   # optional, improves search quality via query expansion
```

Save to shell profile or `.env`. Keys are picked up by `gbrain config set` automatically
or can be stored in `~/.gbrain/config.json` (file plane). Without any embedding provider,
keyword search still works. Without Anthropic, search works but skips query expansion.

## Step 3: Create the Brain

```bash
gbrain init                           # PGLite, no server needed
gbrain doctor --json                  # verify all checks pass
```

The user's markdown files (notes, docs, brain repo) are SEPARATE from this tool repo.
Ask the user where their files are, or create a new brain repo:

```bash
mkdir -p ~/brain && cd ~/brain && git init
```

Read `~/tbrain/docs/GBRAIN_RECOMMENDED_SCHEMA.md` and set up the MECE directory
structure (people/, companies/, concepts/, etc.) inside the user's brain repo,
NOT inside ~/tbrain.

## Step 3.1: Activate the tbrain-trader schema pack (DO NOT SKIP)

This is what makes the install **tbrain** instead of plain gbrain. Without
this step the brain runs the generic `gbrain-base` pack and the trader page
types (instrument, position, trade, thesis, setup, sector, catalyst,
watchlist, postmortem, account, macro) will not be recognized.

```bash
gbrain schema use tbrain-trader      # writes ~/.gbrain/config.json schema_pack field
gbrain schema active                 # verify: should print tbrain-trader
```

This is the durable, file-plane activation — it sticks across commands and
sessions without needing an env var. (`GBRAIN_SCHEMA_PACK=tbrain-trader` also
works as a per-shell override if the user wants it scoped that way instead.)

Then set up the trader directory layout (mirrors the filing rules in
`skills/_brain-filing-rules.md`, trader section):

```bash
mkdir -p ~/brain/{instruments,sectors,accounts,theses,setups,macro,watchlists,journal,positions,catalysts,postmortems}
```

Read `TBRAIN.md` at the tool repo root for the full trader-loop overview
(trade-journal → thesis-tracker → premarket-brief → trade-postmortem) before
continuing to Step 4.

## Step 3.5: Confirm search mode with the user (DO NOT SKIP)

`gbrain init` auto-applied a default search mode (`tokenmax` unless your subagent
tier is Haiku-class or no OpenAI key is configured). The init output included the
cost matrix below preceded by `[AGENT]` markers. You must NOT silently accept the
default. Stop and ask the operator.

**Present this matrix verbatim:**

```
Per-query cost @ 10K queries/mo (typical single-user volume):

                  Haiku 4.5     Sonnet 4.6    Opus 4.7
                  ($1/M)        ($3/M)        ($5/M)
  conservative    $40/mo        $120/mo       $200/mo
  balanced        $100/mo       $300/mo       $500/mo
  tokenmax        $200/mo       $600/mo       $1,000/mo

(scales linearly: ×10 for 100K/mo, ÷10 for 1K. 25x corner-to-corner spread.
 Natural diagonal pairings — cheap/cheap → frontier/frontier — span ~4x.)
```

**Ask the operator (paraphrase if needed):**

> Your gbrain just installed with search mode `<auto-applied default>`. This is
> a one-time setup decision that controls retrieval payload size. Which mode
> do you want?
>
>   1) conservative — tight 4K budget, no LLM expansion, 10 chunks max.
>      Best for Haiku subagents, cost-sensitive setups, high-volume loops.
>
>   2) balanced — 12K budget, no expansion, 25 chunks. Sonnet-tier sweet spot.
>
>   3) tokenmax (recommended default — preserves v0.31.x retrieval shape) —
>      no budget, LLM expansion ON, 50 chunks. Best for Opus/frontier models.
>
> Cost depends on BOTH the mode AND the downstream model you run. See the
> matrix above for the 9-cell breakdown.

If the operator picks a non-default mode, run:
```bash
gbrain config set search.mode <mode>
```

If they pick tokenmax AND want to preserve the literal v0.31.x default
(limit=20 instead of tokenmax's 50), also run:
```bash
gbrain config set search.searchLimit 20
```

Verify the choice with `gbrain search modes` before continuing.

**Why this matters:** the cost spread between corners of the matrix is 25x.
An agent that silently accepts the default and starts running queries against
a user who didn't expect tokenmax-class context loads can rack up surprise
spend. Confirm before continuing.

## Step 4: Import and Index

```bash
gbrain import ~/brain/ --no-embed     # import markdown files
gbrain embed --stale                  # generate vector embeddings
gbrain query "key themes across these documents?"
```

## Step 4.5: Wire the Knowledge Graph

If the user already had a brain repo (Step 3 imported existing markdown), backfill
the typed-link graph and structured timeline. This populates the `links` and
`timeline_entries` tables that future writes will maintain automatically.

```bash
gbrain extract links --source db --dry-run | head -20    # preview
gbrain extract links --source db                         # commit
gbrain extract timeline --source db                      # dated events
gbrain stats                                             # verify links > 0
```

For brand-new empty brains, skip this step — auto-link populates the graph as the
agent writes pages going forward. There is nothing to backfill yet.

After this step:
- `gbrain graph-query <slug> --depth 2` works (relationship traversal)
- Search ranks well-connected entities higher (backlink boost)
- Every future `put_page` auto-creates typed links and reconciles stale ones

If a user has a very large brain (>10K pages), `extract --source db` is idempotent
and supports `--since YYYY-MM-DD` for incremental runs.

### Obsidian-style bare wikilinks (opt-in)

If the user imported an Obsidian or Notion vault that uses **bare** `[[note-name]]`
wikilinks — where `[[struktura]]` written in one folder means the page that lives
at `projects/struktura.md` in another — GBrain does NOT connect those by default.
Out of the box it only resolves path-qualified refs like `[[projects/struktura]]`,
so a vault full of bare links shows up as a thin, broken graph. Turn on basename
resolution so the cross-folder links connect:

```bash
gbrain config set link_resolution.global_basename true
gbrain extract links --source db          # re-run so the new edges land
```

`gbrain doctor` surfaces a `link_resolution_opportunity` hint with the exact count
("47 of 60 bare wikilinks would resolve") so you know whether it's worth enabling
before you flip it. When a bare name matches more than one page (`[[struktura]]` →
both `projects/struktura` and `archive/struktura`), GBrain emits one edge to each
rather than guessing a winner — review and prune the duplicates with
`gbrain graph-query <slug>`. The mode is also honored on the filesystem-walk path
(`gbrain extract links` with no `--source db`) and by auto-link on every future
`put_page`.

## Step 5: Load Skills (harness-aware)

The 58 skills (incl. the 6 trader skills: trade-journal, thesis-tracker,
trade-postmortem, premarket-brief, position-book, watchlist) are SKILL.md
files. Where they go depends on YOUR harness (Step 0):

`--workspace PATH` scaffolds into `PATH/skills/<name>/SKILL.md` (it appends
`skills/` itself — don't include it):

- **Hermes** — skills live in `~/.hermes/skills/`. Point `--workspace` at the
  Hermes home:
  ```bash
  gbrain skillpack scaffold --all --workspace ~/.hermes
  ```
  Even though Hermes ships its own skills, you MUST add the 6 trader skills —
  they are not in the Hermes bundle. (Manual fallback:
  `cp -r "$TBRAIN_REPO"/skills/{trade-journal,thesis-tracker,trade-postmortem,premarket-brief,position-book,watchlist} ~/.hermes/skills/`)
- **Claude Code / Codex** — scaffold into the workspace you run from:
  ```bash
  cd /path/to/agent/workspace && gbrain skillpack scaffold --all --workspace .
  ```

Scaffolded skills are first-class files. Re-running scaffold refuses to
overwrite. Read `skills/RESOLVER.md` (in your workspace or `$TBRAIN_REPO/skills/RESOLVER.md`)
— the dispatcher that maps any task to a skill. Save it to memory.

The three most important skills to adopt immediately:

1. **Signal detector** (`skills/signal-detector/SKILL.md`) — fire this on EVERY
   inbound message. It captures ideas and entities in parallel. The brain compounds.

2. **Brain-ops** (`skills/brain-ops/SKILL.md`) — brain-first lookup on every response.
   Check the brain before any external API call.

3. **Conventions** (`skills/conventions/quality.md`) — citation format, back-linking
   iron law, source attribution. These are non-negotiable quality rules.

## Step 5.5: Wire the memory loop (THE point of tbrain — DO NOT SKIP)

This is what makes tbrain *ambient*: every conversation pulls relevant trading
memory in BEFORE the agent answers, and pushes new memory back out AFTER it
responds — automatically, via your harness's hook system. One command wires
all of it for your harness (run it from the cloned repo):

```bash
"$TBRAIN_REPO"/integrations/install-tbrain-hooks.sh \
  --harness "$TBRAIN_HARNESS" --brain-repo ~/brain
# preview without changing anything: add --dry-run
```

What it does, per harness:

| | Pre-prompt retrieval (inject) | Post-response capture | Dream cycle |
|---|---|---|---|
| **Hermes** | shell hook `pre_llm_call` in `config.yaml` → `tbrain_inject.py` returns `{"context": …}` (first turn only) | gateway hook `agent:end` in `~/.hermes/hooks/tbrain-capture/` → `gbrain capture` | `hermes cron` runs `tbrain-dream.sh` nightly |
| **Claude Code** | `UserPromptSubmit` hook in `settings.json` → `tbrain_inject.py` (stdout injected) | `Stop` hook → `tbrain_capture.py` | `gbrain autopilot --install` |
| **Codex** | none (no pre-prompt hook) — the brain-first protocol makes the agent run `gbrain query` itself | in-band trade-journal/signal skills + dream cycle | `gbrain autopilot --install` |

The installer also: activates the `tbrain-trader` pack, scaffolds the trader
directory layout in `~/brain`, and appends the **brain-first protocol** to your
harness's prompt file (`~/.hermes/SOUL.md`, `~/.claude/CLAUDE.md`, or `AGENTS.md`).
It is idempotent — safe to re-run.

**Hermes note:** the installer sets `hooks_auto_accept: true` so the non-TTY
gateway can register the shell hook without an interactive consent prompt. The
retrieval hook fires only on the first turn of each task (it reads
`extra.is_first_turn`), so it does not re-inject on every tool-loop step.

**Verify the loop:**
```bash
# inject: feed a synthetic payload, expect a tbrain-context block
echo '{"extra":{"user_message":"my NVDA thesis","is_first_turn":true}}' \
  | "$TBRAIN_REPO"/integrations/hooks/tbrain_inject.py --harness hermes
# capture: a long turn lands in the brain inbox
gbrain query "auto-capture" --json | head
```

After this, you do not need to remember to use the brain — the harness does it
for you. The in-band skills (trade-journal etc.) remain the higher-quality path
for deliberate writes; the hooks are the always-on backstop.

## Step 6: Identity (optional)

Run the soul-audit skill to customize the agent's identity:

```
Read skills/soul-audit/SKILL.md and follow it.
```

This generates SOUL.md (agent identity), USER.md (user profile), ACCESS_POLICY.md
(who sees what), and HEARTBEAT.md (operational cadence) from the user's answers.

If skipped, minimal defaults are installed automatically.

## Step 7: Recurring Jobs

The **dream cycle was already scheduled by Step 5.5's installer** (Hermes →
`hermes cron`; Claude Code / Codex → `gbrain autopilot --install`). Confirm it:

```bash
# Hermes:
hermes cron list | grep tbrain-dream
# Claude Code / Codex:
gbrain autopilot status
```

The remaining jobs (set via your harness's scheduler, or `gbrain autopilot`):

- **Live sync** (every 15 min): `gbrain sync --repo ~/brain && gbrain embed --stale`
  — or `gbrain sync --watch` for a continuous loop. (This is what indexes the
  auto-captured inbox turns so they become searchable.)
- **Auto-update** (daily): `gbrain check-update --json` (tell user, never auto-install).
- **Dream cycle** (nightly): `gbrain dream` — entity sweep, citation fixes, memory
  consolidation, contradiction detection, conversation synthesis. For tbrain this
  is what files the auto-captured turns into `journal/`, `theses/`, etc. and
  resolves take/calibration state. Do not skip it. The Hermes wrapper is
  `~/.hermes/scripts/tbrain-dream.sh` (syncs + embeds + dreams in one shot).
- **Weekly**: `gbrain doctor --json && gbrain embed --stale`

**Hermes scheduling note:** `hermes cron create '<sched>' --script <name> --no-agent`
runs a shell script under `~/.hermes/scripts/` on a schedule with NO LLM call
(cheap, deterministic) — that's how `tbrain-dream.sh` is wired. Do not schedule
the dream cycle as an LLM *prompt*; it's a CLI maintenance job.

## Step 8: Integrations

Run `gbrain integrations list`. Each recipe in `~/tbrain/recipes/` is a self-contained
installer. It tells you what credentials to ask for, how to validate, and what cron
to register. Ask the user which integrations they want (email, calendar, voice, Twitter).

Verify: `gbrain integrations doctor` (after at least one is configured)

## Step 9: Verify

Read `docs/GBRAIN_VERIFY.md` and run all 7 verification checks. Check #4 (live sync
actually works) is the most important.

## Upgrade

If you installed via `bun install -g`:

```bash
gbrain upgrade                        # self-updates the binary, runs schema migrations,
                                      # and prints post-upgrade notes for the version range
```

If you installed via `git clone + bun link`:

```bash
cd ~/tbrain && git pull origin main && bun install
gbrain apply-migrations --yes         # apply schema migrations (idempotent)
gbrain post-upgrade                   # show migration notes for the version range
```

Then read `~/tbrain/skills/migrations/v<NEW_VERSION>.md` (and any intermediate
versions you skipped) and run any backfill or verification steps it lists. Skipping
this is how features ship in the binary but stay dormant in the user's brain.

**v0.32.3 search modes (one-time upgrade prompt):** if the user's brain was
created before v0.32.3, `gbrain post-upgrade` prints a banner including the
9-cell cost matrix (mode × downstream model) preceded by `[AGENT]` markers.
**Do NOT silently move past the banner.** Present the matrix to the operator
verbatim, ask which mode they want (recommended default: `tokenmax` to preserve
v0.31.x retrieval shape), then run `gbrain config set search.mode <mode>`. See
Step 3.5 above for the full ask-the-user protocol — the upgrade path uses the
same matrix and same default.

For v0.12.0+ specifically: if your brain was created before v0.12.0, run
`gbrain extract links --source db && gbrain extract timeline --source db` to
backfill the new graph layer (see Step 4.5 above).

For v0.12.2+ specifically: if your brain is Postgres- or Supabase-backed and
predates v0.12.2, the `v0_12_2` migration runs `gbrain repair-jsonb`
automatically during `gbrain post-upgrade` to fix the double-encoded JSONB
columns. PGLite brains no-op. If wiki-style imports were truncated by the old
`splitBody` bug, run `gbrain sync --full` after upgrading to rebuild
`compiled_truth` from source markdown.

## v0.42.0+ onboard surface (NEW)

`gbrain onboard` is the activation surface gbrain did not have before.
Once your brain has any content, run `gbrain onboard --check --json` to
see structured recommendations across 5 brain-health axes (orphans,
stale embeddings, entity link coverage, timeline coverage, takes count).

**On first connect (after `gbrain init`):**
```bash
gbrain onboard --check --json
```
The JSON envelope (`schema_version: 1`) carries `recommendations[]` with
`apply_policy` per item: `auto_apply` (safe to run unattended),
`prompt_required` (needs explicit user consent), or `manual_only`
(LLM-bearing, user must run themselves).

**After every `gbrain upgrade`:**
```bash
gbrain onboard --check --json
```
New versions may surface new opportunities. The post-upgrade banner
nudges the user when it runs, but agents should re-probe as a hygiene
step regardless.

**Unattended remediation (cron / autopilot):**
```bash
gbrain onboard --auto --max-usd 5
```
Refuses without `--max-usd N`. Runs auto-eligible items only. The
autopilot daemon also consults onboard recommendations on its tick — no
explicit agent action needed for the autonomous path.

**Remote / federated brain installs (MCP):**
The `run_onboard` MCP op (admin scope) lets thin-client agents probe
brain health + drive remediation over OAuth-authenticated MCP. Protected
LLM-bearing handlers (synthesize, patterns, consolidate, takes-bootstrap,
contextual_reindex_per_chunk) require the additional `run_protected_onboard`
scope — admin alone is insufficient. The MCP op returns
`skipped_missing_scope[]` listing what would have run with the right
grants.

**Privacy + consent gates:**
- `gbrain takes extract --from-pages` sends concept/atom/lore/briefing/
  writing/originals page content to your configured chat model (default
  Anthropic Haiku). Refuses to run unless `takes.bootstrap_enabled=true`
  is set in config AND `--yes` is passed. Two-gate opt-in by design.
- Autopilot's auto-apply tier for takes-bootstrap stays `manual_only`
  until v0.42.1's eval gate (do not bypass).

**Suppress nudges in CI / scripted environments:**
```bash
export GBRAIN_NO_ONBOARD_NUDGE=1
```
Init + upgrade banners auto-skip in non-TTY too.
