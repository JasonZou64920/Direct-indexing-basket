# Changelog

## 0.1.0 — 2026-07-10

Initial public release.

- Fixed embedded JSX dashboard in institutional blue-toned style: header with resolved-inputs facts, KPI strip, Summary / Full Detail toggle, cumulative performance chart, rolling correlation, cumulative active return, sector-exposure grouped bar, holdings table, tracking + beat diagnostics, methodology, analyst summary, risks, disclaimer.
- Direct-indexing workflow: resolve inputs → build universe → construct basket (stratified sampling + tracking-error refinement by default) → assign constrained market-cap weights → backtest → tracking diagnostics → beat diagnostics → deliver.
- Beat diagnostics (diagnostic-only): monthly beat rate, rolling 12-month beat rate, up- / down-market beat rates, average annualized excess return, best / worst month excess.
- Per-run deliverables: `.jsx` React dashboard, `.json` canonical payload, `.xlsx` five-sheet workbook (Holdings, Sector Exposure, Size Sensitivity, KPIs & Stats, Meta).
- Default data source: Yahoo Finance via `yfinance` — no paid connector required. Optional overrides: LSEG Refinitiv, Polygon, web-search metadata. Resolved source is recorded in `basket.data_source` and shown in the dashboard header + Meta sheet.
- One-click Cowork install via `direct-index-basket.skill`. Bash installer `install.sh` for Claude Code.
