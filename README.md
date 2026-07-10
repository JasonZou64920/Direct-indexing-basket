# Direct Index Basket

Build, weight, and backtest a reduced-stock basket that tracks a target equity index — direct indexing packaged as a single Claude skill. Default target is the S&P 500 (proxy `SPY`); default basket is 75 names. Runs out of the box on Yahoo Finance — no paid market-data connector required — and can be pointed at LSEG Refinitiv, Polygon, or any other connected market-data MCP when available.

## Install (one step)

**Cowork** — download [`direct-index-basket.skill`](./direct-index-basket.skill) from this repo and open it. Cowork prompts you to save it as an installed skill.

**Claude Code** — clone the repo and run:

```bash
./install.sh
```

`install.sh` copies `skills/direct-index-basket/SKILL.md` into `~/.claude/skills/direct-index-basket/` (override with `CLAUDE_SKILLS_DIR`).

## What it does

Every run produces three artifacts against a fixed institutional-style dashboard frame:

| Artifact | Purpose |
|---|---|
| `DirectIndexBasket_<BENCH>_<N>n_<DATE>.jsx` | Interactive React dashboard — Summary / Full Detail toggle, KPI strip, performance chart, rolling correlation, cumulative active return, sector-exposure grouped bar, holdings table, tracking + beat diagnostics, methodology, analyst summary, risks. |
| `direct_index_basket_<BENCH>_<N>n_<DATE>.json` | Canonical `DATA` payload the dashboard reads. |
| `direct_index_basket_<BENCH>_<N>n_<DATE>.xlsx` | Five-sheet workbook — Holdings, Sector Exposure, Size Sensitivity, KPIs & Stats, Meta. |

## Workflow

1. **Resolve inputs** — target index, basket size, rebalance frequency, backtest horizon, weighting method, optional constraints, data source.
2. **Build universe** — pull benchmark constituents, drop illiquid / short-history names.
3. **Construct basket** — default is stratified sampling by GICS sector plus tracking-error refinement; also supports representative sampling, correlation maximization, constrained TE minimization, hybrid.
4. **Assign weights** — constrained market-cap by default, capped per name and renormalized to sector targets. Records active tilt per holding.
5. **Backtest** — cumulative performance rebased to 100, rolling 60-day correlation, cumulative active return, annualized tracking error, beta, R², volatility, drawdown, up-/down-capture.
6. **Diagnostics** — full-period and rolling correlation stats, tracking-error decomposition, basket-size sensitivity (chosen size plus ≥2 alternates).
7. **Beat diagnostics** — monthly and rolling 12-month beat rates, up- / down-market beat rates, average annualized excess return, best / worst month. Reported as a diagnostic; the basket is designed to track, not beat.
8. **Populate & deliver** — inject `DATA` into the fixed JSX frame, write the JSON payload, build the Excel workbook, present the three files.

## Data sources

Priority: user-named source → default `yfinance` → error. Specify a source at run time with e.g. `data_source: lseg`.

| Value | Backing | Notes |
|---|---|---|
| `yfinance` **(default)** | Python `yfinance` library | Free; adequate for research and prototyping. Install with `pip install yfinance --break-system-packages`. |
| `lseg` / `refinitiv` | LSEG Refinitiv Data MCP | Preferred when connected — higher-quality institutional prices, sectors, and constituent history. |
| `polygon` | Polygon.io MCP | Alternate institutional feed when connected. |
| `web` | Web search | Metadata only (constituent lists, sector tags). Last-resort fallback — never derive prices from scrapes. |

The resolved source is written to `basket.data_source`, shown in the dashboard header, and included in the Excel Meta sheet.

## Example prompts

```
Build a direct-indexing basket for the S&P 500 with 50 names.
Track the S&P 500 with fewer stocks.
80-name basket to replicate SPY, quarterly rebalance, data_source: polygon.
Reduced basket that tracks NDX with 40 names over a 3-year horizon.
Direct index the S&P 500 — compare tracking quality at 50, 75, and 100 names.
```

## Repo layout

```
direct-index-basket/
├── README.md
├── LICENSE                              MIT © 2026 Jason Zou
├── DISCLAIMER.md
├── CHANGELOG.md
├── install.sh                           one-command install to ~/.claude/skills
├── .gitignore
├── skills/
│   └── direct-index-basket/
│       └── SKILL.md                     the skill (self-contained; embeds the JSX frame)
└── direct-index-basket.skill            zipped bundle for one-click Cowork install
```

## Architecture

The dashboard is a **fixed JSX frame embedded inside `SKILL.md`**. Every run copies that block verbatim to the output `.jsx` file and replaces only the `DATA = { ... }` object literal at the top. Layout, theme, chart configuration, and component code are stable across runs — this keeps presentation consistent, cuts per-run token cost, and makes the data layer independently auditable.

To modify the frame, edit the JSX block in `skills/direct-index-basket/SKILL.md` and rebuild the bundle:

```bash
rm -rf .build && mkdir -p .build/direct-index-basket
cp skills/direct-index-basket/SKILL.md .build/direct-index-basket/SKILL.md
(cd .build && zip -r ../direct-index-basket.skill direct-index-basket)
rm -rf .build
```

## Verification

The embedded frame is covered by a jsdom smoke test (React 18 + `createRoot` + real event dispatch). See the `jsdom` verification note in the repo's development guide for the exact harness. Current pass rate: **all 16 assertions** (toggle behavior, KPI rendering, Beat Diagnostics stats grid, Data Source fact in header).

## License

MIT © 2026 Jason Zou. See [`LICENSE`](./LICENSE).

## Disclaimer

Research support only. **Not investment, legal, or tax advice.** Backtested tracking is historical and hypothetical, excludes trading costs, taxes, and slippage, and may not persist out of sample. See [`DISCLAIMER.md`](./DISCLAIMER.md) for the full statement.
