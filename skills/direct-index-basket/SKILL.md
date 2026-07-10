---
name: direct-index-basket
description: Builds and backtests a reduced-stock basket that tracks a target equity index (default S&P 500 / SPY) using direct-indexing logic — selects a materially smaller constituent set, assigns explicit weights, and evaluates tracking quality over time. Triggers on requests like "track the S&P 500 with fewer stocks", "build a direct indexing basket", "50-stock S&P 500 tracker", "80-name basket to replicate SPY", "reduced basket that tracks an index", "sampled index portfolio", "index replication with a smaller basket", or any request to replicate / track / approximate an equity index with a smaller basket, with or without a specified stock count. Produces a structured data payload that populates a fixed embedded JSX dashboard — does NOT redesign, restyle, or regenerate the dashboard frame.
---

# Direct Index Basket Builder

## Purpose

Given a target equity index and a desired (or defaulted) basket size, construct a reduced set of common-equity holdings with explicit weights that tracks the index, backtest that basket against the index, and report correlation and tracking quality. Output is a structured data payload that feeds a fixed dashboard.

This skill is **research support only** for direct-indexing workflows. It does not provide investment, tax, legal, or suitability advice, and does not execute trades. If asked for those, decline and redirect to a qualified advisor.

## Architectural Contract — Read This First

The dashboard is a **fixed JSX frame embedded in this file** under `## Embedded Dashboard Frame`. It is the canonical UI and must not be redesigned.

On every run:
1. Write the embedded JSX block **verbatim** to `outputs/DirectIndexBasket_<BENCH>_<SIZE>n_<YYYYMMDD>.jsx`.
2. Replace **only** the `DATA = { ... }` object literal at the top with the run's payload. Touch nothing else — no layout, theme, chart, or component change.
3. Write the raw payload to `outputs/direct_index_basket_<BENCH>_<SIZE>n_<YYYYMMDD>.json`.
4. Build the Excel workbook `outputs/direct_index_basket_<BENCH>_<SIZE>n_<YYYYMMDD>.xlsx` via the `xlsx` skill (five sheets — layout defined in step 8).
5. Present all three files. Do not print the JSX in chat. Do not narrate methodology unless asked — the dashboard, workbook, and embedded narrative fields are the deliverable.

This separation exists for consistency across runs, low token cost on repeat runs, and an auditable data layer. Future revisions build on this fixed-frame format; never revert to a UI-regenerating workflow.

## Output Contract — `DATA` Schema

Every run produces exactly this object. Percentages are decimals (`0.018` = 1.8%). Diff fields are `basket − benchmark`. Three time-series share aligned, equal-length arrays.

```json
{
  "as_of": "2026-05-20",
  "benchmark": { "name": "S&P 500", "ticker": "SPY", "constituent_count": 503 },
  "basket": {
    "size": 75,
    "construction_method": "Stratified sampling with tracking-error refinement",
    "weighting_method": "Constrained market-cap weighting",
    "rebalance_frequency": "Quarterly",
    "backtest_start": "2021-05-20",
    "backtest_end": "2026-05-20",
    "horizon_label": "5Y",
    "data_source": "yfinance"
  },
  "kpis": {
    "correlation": 0.991,
    "tracking_error_annualized": 0.018,
    "cumulative_return_diff": -0.012,
    "volatility_gap": 0.004,
    "max_drawdown_diff": -0.011
  },
  "stats": {
    "beta": 1.02, "r_squared": 0.982,
    "ann_return_basket": 0.143, "ann_return_benchmark": 0.145,
    "ann_vol_basket": 0.171, "ann_vol_benchmark": 0.167,
    "max_dd_basket": -0.254, "max_dd_benchmark": -0.243,
    "up_capture": 0.99, "down_capture": 1.01
  },
  "holdings": [
    {
      "ticker": "AAPL", "name": "Apple Inc.", "sector": "Information Technology",
      "weight": 0.071, "benchmark_weight": 0.069,
      "role": "Mega-cap anchor", "note": "Retained near 1:1; dominant index weight."
    }
  ],
  "sector_exposure": [
    { "sector": "Information Technology", "basket_weight": 0.312, "benchmark_weight": 0.318 }
  ],
  "performance_series": { "dates": ["YYYY-MM-DD"], "basket": [100.0], "benchmark": [100.0] },
  "rolling_correlation": { "window_days": 60, "dates": ["YYYY-MM-DD"], "values": [0.98] },
  "active_return_series": { "dates": ["YYYY-MM-DD"], "cumulative_active_return": [0.0] },
  "size_sensitivity": [
    { "size": 50, "tracking_error_annualized": 0.027, "correlation": 0.985 },
    { "size": 75, "tracking_error_annualized": 0.018, "correlation": 0.991 },
    { "size": 100, "tracking_error_annualized": 0.014, "correlation": 0.994 }
  ],
  "beat_diagnostics": {
    "monthly_beat_rate": 0.55,
    "rolling_12m_beat_rate": 0.62,
    "up_market_beat_rate": 0.58,
    "down_market_beat_rate": 0.51,
    "avg_excess_return_ann": 0.003,
    "best_month_excess": 0.021,
    "worst_month_excess": -0.018,
    "months_observed": 60
  },
  "methodology": "One paragraph, plain finance language — see Reusable Boilerplate.",
  "diagnostics_note": "One paragraph — rolling stability, up/down capture, sensitivity.",
  "risks": ["...", "..."],
  "analyst_summary": "One paragraph — verdict on tracking quality and fitness for use.",
  "disclaimers": ["Research support only. Not investment, legal, or tax advice.", "..."]
}
```

Field rules: `holdings` length equals `basket.size`; `holdings` weights sum to ~1.0; `sector_exposure` covers every benchmark sector; `size_sensitivity` includes the chosen size plus ≥2 alternates; all three series are non-empty and equal-length within each object; every `beat_diagnostics` rate is a fraction in [0, 1] and `avg_excess_return_ann`, `best_month_excess`, `worst_month_excess` are signed decimals. Never emit `null` for a computed field — compute it or omit the holding.

## Workflow

Run in order. Reuse the strings in **Reusable Boilerplate** instead of re-deriving equivalent prose.

### 1 — Resolve inputs

| Input | Default if unspecified |
|---|---|
| Target index | S&P 500 (proxy `SPY`) |
| Basket size | **75** (materially reduced; ~85% fewer names) |
| Rebalance frequency | Quarterly |
| Backtest horizon | 5 years, or longest common adjusted-close history |
| Weighting method | Constrained market-cap |
| Method preference | Interpretable / robust over optimized black-box |
| Data source | **`yfinance`** (Yahoo Finance) — no paid connector needed |

If the user gives a basket size (50, 80, any number), **use it exactly**. Accept optional constraints: sector-balance tolerance, max single-name weight, min liquidity/ADV, market-cap floor, turnover cap. Accept an optional `data_source` value — see the **Computation & data** section for the supported values and fallback order. Echo resolved inputs into `basket` (including `data_source`).

### 2 — Build eligible universe

Pull current benchmark constituents (or a realistic proxy universe). Drop names lacking continuous adjusted-close history over the backtest horizon or failing the liquidity/market-cap floor. Preserve realistic implementation logic; note universe size and material exclusions.

### 3 — Construct the basket

Default method: **stratified sampling + tracking-error refinement** — partition the benchmark by GICS sector; within each sector retain the largest names to fill that sector's target weight; fill remaining slots to minimize ex-ante tracking error / maximize return correlation under constraints. Also supported: representative sampling, sector/factor matching, market-cap down-selection, correlation maximization, constrained TE minimization, or a hybrid. Always: explain the method in practical finance language, justify why the basket should track the benchmark, and prefer interpretable construction over black-box complexity unless the user requests optimization.

### 4 — Assign weights

Weighting is explicit, never assumed equal. Default to market-cap-informed weights, capped per name and renormalized to sector targets; constrained-optimization or sector-normalized weights are alternatives. Equal weighting only if intentionally chosen and justified. For every holding record `weight`, `benchmark_weight`, `role` (its benchmark proxy function), and a one-line `note` on its contribution to tracking.

### 5 — Backtest

On daily adjusted-close returns over the horizon, compute: cumulative performance rebased to 100 (`performance_series`); rolling correlation, window default 60 trading days (`rolling_correlation`); cumulative active return = basket − benchmark (`active_return_series`); annualized tracking error; return differential; annualized volatility (both); max drawdown (both); beta and R² of basket regressed on benchmark. State the rebalance assumption, period tested, and material caveats. Never correlate price levels — always returns.

Additionally compute the **beat diagnostics** block on monthly returns aggregated from the daily series:

- `monthly_beat_rate` — fraction of calendar months in which basket monthly return exceeded index monthly return.
- `rolling_12m_beat_rate` — fraction of rolling 12-month windows in which basket 12M return exceeded the index's.
- `up_market_beat_rate` / `down_market_beat_rate` — beat rates conditional on the index month being positive / negative.
- `avg_excess_return_ann` — annualized mean of monthly excess returns.
- `best_month_excess`, `worst_month_excess` — largest positive and negative monthly excess return.
- `months_observed` — count of months used.

These are **diagnostic only**. The construction objective remains tracking the index; the beat metrics tell the user whether the tracking basket happens to have delivered excess return over this window, not whether it was designed to.

### 6 — Correlation & tracking diagnostics

Populate `stats` and `diagnostics_note`: full-period correlation, rolling mean/min/max, tracking error, up-/down-market capture, sensitivity to weighting assumptions, and sensitivity to basket size. For `size_sensitivity`, recompute TE and correlation at ≥2 alternate sizes (e.g. chosen size ±25) so the size/quality trade-off is visible.

### 7 — Basket-size logic

Follow a specified size exactly. If unspecified, use the default 75 — substantially smaller than the full index yet reasonably representative. State plainly that smaller baskets improve simplicity but typically worsen tracking quality. If the user asks, compare multiple sizes via `size_sensitivity` and the diagnostics narrative.

### 8 — Populate & deliver

Write the embedded frame verbatim to the `.jsx` output, inject `DATA`, write the JSON payload, build the Excel workbook via the `xlsx` skill using the sheet layout below, and present all three files (see Architectural Contract).

**Excel workbook layout** — file `outputs/direct_index_basket_<BENCH>_<SIZE>n_<YYYYMMDD>.xlsx`, five sheets, header rows frozen, column widths sensible for print:

| Sheet | Columns | Notes |
|---|---|---|
| **Holdings** | Ticker, Company, Sector, Basket Weight, Index Weight, Active Tilt, Benchmark Role, Note | One row per holding; totals row at bottom with Basket Weight summing to **1.0000**. Weights formatted as percent, 2 dp. Sort by Basket Weight desc. |
| **Sector Exposure** | Sector, Basket Weight, Index Weight, Delta | One row per benchmark sector; totals row. Percent, 2 dp. |
| **Size Sensitivity** | Basket Size, Tracking Error, Correlation | One row per point in `size_sensitivity`; highlight the chosen size row with a light blue fill. Percent for TE, 3 dp for correlation. |
| **KPIs & Stats** | Metric, Value | Flat two-column list of every field in `kpis`, `stats`, and `beat_diagnostics` with human-readable labels and correct formatting (percent, signed percent, ratios). |
| **Meta** | Field, Value | `as_of`, `benchmark.name`, `benchmark.ticker`, `benchmark.constituent_count`, all `basket.*` fields, plus a full-width `methodology` cell and one row per `disclaimers` entry. |

Formatting rules for the workbook: percentages stored as decimals with a percent format string (never as strings like `"1.8%"`); signed diffs use a signed percent format; the totals row on Holdings and Sector Exposure uses bold. The Holdings Basket Weight column **must** sum to exactly 1.0000 — reconcile any residual float error into the largest weight before writing.

### Computation & data

**Default: `yfinance` (Yahoo Finance).** This lets the skill run with no paid data connector. Install once per sandbox with `pip install yfinance --break-system-packages`. All computation happens in the sandbox with `pandas` / `numpy`; record `as_of` as the latest trading day actually used.

**Supported `data_source` values** — user can specify any of the below at run time; the skill uses the named source when connected, otherwise falls back down the list until it finds one that works:

| Value | Backing | Notes |
|---|---|---|
| `yfinance` **(default)** | Python `yfinance` library | Free; adequate for research and prototyping. |
| `lseg` / `refinitiv` | LSEG Refinitiv Data MCP | Preferred when connected — higher-quality institutional prices, sectors, and constituent history. |
| `polygon` | Polygon.io MCP | Alternate institutional feed when connected. |
| `web` | Web search | Metadata only (constituent lists, sector tags). Last-resort fallback; do NOT compute prices/returns from web scrapes. |

Fallback order when the user names a source that isn't available: **user-named → `yfinance` → error and stop**. Record the source actually used in `basket.data_source` so the dashboard and workbook show it.

Never fabricate prices, returns, weights, or statistics. If no price source is available at all, stop and tell the user which connector or library is needed.

## Reusable Boilerplate

Insert these standardized strings (lightly adapted to the run) instead of writing fresh prose each time:

- **`methodology`**: "Basket built by [METHOD]: the benchmark is partitioned by GICS sector, the largest names per sector are retained to match sector weight, and remaining slots are filled to minimize ex-ante tracking error. Weights are [WEIGHTING], capped per name and renormalized to sector targets. [REBALANCE] rebalance assumed; transaction costs not modeled."
- **`diagnostics_note`**: "Rolling [N]-day correlation [stays above X / dips to X] across the window. Up/down capture of [U]/[D] indicates [symmetric/asymmetric] tracking. Tracking error rises materially below ~[K] names as omitted mid-cap idiosyncratic risk is no longer diversified away."
- **`disclaimers`**: `["Research support only. Not investment, legal, or tax advice.", "Backtested results are hypothetical and exclude trading costs, taxes, and slippage."]`

## Token-Efficiency Rules

- Reuse the embedded JSX frame and its components, card layouts, chart containers, table schema, and section headers — never regenerate them.
- Return only the canonical `DATA` object; do not restate in chat what a dashboard field already carries.
- Keep `methodology`, `diagnostics_note`, `analyst_summary`, `risks` concise and information-dense; one paragraph each.
- Do not duplicate descriptions across KPI cards, the holdings table, and summary panels.
- Use the same response structure and the Reusable Boilerplate every run; prefer the modular sub-steps above over long-form re-explanation.
- Token efficiency is a design constraint for every future run, not just the first build.

## Rigor & Preservation of Function

State assumptions explicitly. Avoid false precision. Reflect real implementation: turnover, rebalance timing, liquidity. Disclose limitations — survivorship bias, data availability, approximation risk, out-of-sample drift, untaxed/uncosted backtest. Write financially literate interpretation, not generic prose.

**Preservation rule:** token optimization is strictly secondary to correctness and completeness. Never omit core analytics — weight logic, backtest diagnostics, benchmark comparison, correlation/tracking statistics, or any required `DATA` field — to save tokens. Compression comes only from removing redundancy, stabilizing the UI frame, pre-embedding the template, and shortening boilerplate, never from weakening the method. If token reduction and full function conflict, preserve function.

## Hard Rules

- Never redesign, restyle, recolor, or extend the embedded dashboard beyond replacing `DATA`.
- Never correlate price levels — always daily returns on adjusted closes.
- Never fabricate market data, weights, or statistics.
- Never recommend or execute a trade; output is research data only.
- Never claim a basket is tax-advantaged or wash-sale-safe — that is a tax/legal determination.
- If asked for investment, tax, legal, or suitability advice, decline and recommend a qualified advisor.
- The `beat_diagnostics` block is a **backward-looking diagnostic**, never an objective. Never claim the basket is designed to beat the index or imply expected outperformance.
- In the Excel workbook, the Holdings sheet Basket Weight column must sum to exactly 1.0000; reconcile floating-point residuals into the largest weight before writing.

## Minimal Disclaimer (include every run)

> Research support only. Not investment, legal, or tax advice. Backtested tracking is historical and hypothetical, excludes costs and taxes, and may not persist out of sample.

## Embedded Dashboard Frame

Write the block below verbatim to the output `.jsx` file, then replace only the `DATA` object.

```jsx
import React, { useMemo, useState } from 'react';
import {
  ResponsiveContainer, LineChart, Line, AreaChart, Area, BarChart, Bar,
  XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine,
} from 'recharts';

// ============================================================================
// DATA INJECTION POINT
// ----------------------------------------------------------------------------
// The skill replaces ONLY this object on each run. Component layout, theme,
// and chart configuration must NOT be modified.
// Schema: see SKILL.md -> Output Contract.
// ============================================================================
const DATA = {
  as_of: '2026-05-20',
  benchmark: { name: 'S&P 500', ticker: 'SPY', constituent_count: 503 },
  basket: {
    size: 75,
    construction_method: 'Stratified sampling with tracking-error refinement',
    weighting_method: 'Constrained market-cap weighting',
    rebalance_frequency: 'Quarterly',
    backtest_start: '2021-05-20',
    backtest_end: '2026-05-20',
    horizon_label: '5Y',
    data_source: 'yfinance',
  },
  kpis: {
    correlation: 0.991,
    tracking_error_annualized: 0.018,
    cumulative_return_diff: -0.012,
    volatility_gap: 0.004,
    max_drawdown_diff: -0.011,
  },
  stats: {
    beta: 1.02, r_squared: 0.982,
    ann_return_basket: 0.143, ann_return_benchmark: 0.145,
    ann_vol_basket: 0.171, ann_vol_benchmark: 0.167,
    max_dd_basket: -0.254, max_dd_benchmark: -0.243,
    up_capture: 0.99, down_capture: 1.01,
  },
  holdings: [
    { ticker: 'AAPL', name: 'Apple Inc.', sector: 'Information Technology', weight: 0.071, benchmark_weight: 0.069, role: 'Mega-cap anchor', note: 'Retained near 1:1; dominant index weight.' },
    { ticker: 'MSFT', name: 'Microsoft Corp.', sector: 'Information Technology', weight: 0.068, benchmark_weight: 0.066, role: 'Mega-cap anchor', note: 'Core enterprise-software exposure.' },
    { ticker: 'NVDA', name: 'NVIDIA Corp.', sector: 'Information Technology', weight: 0.061, benchmark_weight: 0.063, role: 'Semis / AI proxy', note: 'Carries semiconductor beta for the bloc.' },
    { ticker: 'AMZN', name: 'Amazon.com Inc.', sector: 'Consumer Discretionary', weight: 0.039, benchmark_weight: 0.038, role: 'Discretionary anchor', note: 'Represents online-retail cohort.' },
    { ticker: 'UNH', name: 'UnitedHealth Group Inc.', sector: 'Health Care', weight: 0.024, benchmark_weight: 0.023, role: 'Health Care anchor', note: 'Managed-care exposure.' },
    { ticker: 'JPM', name: 'JPMorgan Chase & Co.', sector: 'Financials', weight: 0.028, benchmark_weight: 0.026, role: 'Financials proxy', note: 'Money-center bank stand-in.' },
    { ticker: 'XOM', name: 'Exxon Mobil Corp.', sector: 'Energy', weight: 0.022, benchmark_weight: 0.021, role: 'Energy proxy', note: 'Integrated-energy representative.' },
    { ticker: 'PG', name: 'Procter & Gamble Co.', sector: 'Consumer Staples', weight: 0.019, benchmark_weight: 0.020, role: 'Staples proxy', note: 'Low-beta defensive ballast.' },
  ],
  sector_exposure: [
    { sector: 'Information Technology', basket_weight: 0.312, benchmark_weight: 0.318 },
    { sector: 'Financials', basket_weight: 0.131, benchmark_weight: 0.128 },
    { sector: 'Health Care', basket_weight: 0.108, benchmark_weight: 0.111 },
    { sector: 'Consumer Discretionary', basket_weight: 0.104, benchmark_weight: 0.101 },
    { sector: 'Communication Services', basket_weight: 0.092, benchmark_weight: 0.094 },
    { sector: 'Industrials', basket_weight: 0.081, benchmark_weight: 0.079 },
    { sector: 'Consumer Staples', basket_weight: 0.058, benchmark_weight: 0.060 },
    { sector: 'Energy', basket_weight: 0.039, benchmark_weight: 0.037 },
    { sector: 'Utilities', basket_weight: 0.026, benchmark_weight: 0.025 },
    { sector: 'Real Estate', basket_weight: 0.025, benchmark_weight: 0.024 },
    { sector: 'Materials', basket_weight: 0.024, benchmark_weight: 0.023 },
  ],
  performance_series: { dates: [], basket: [], benchmark: [] },
  rolling_correlation: { window_days: 60, dates: [], values: [] },
  active_return_series: { dates: [], cumulative_active_return: [] },
  size_sensitivity: [
    { size: 50, tracking_error_annualized: 0.027, correlation: 0.985 },
    { size: 75, tracking_error_annualized: 0.018, correlation: 0.991 },
    { size: 100, tracking_error_annualized: 0.014, correlation: 0.994 },
  ],
  beat_diagnostics: {
    monthly_beat_rate: 0.55,
    rolling_12m_beat_rate: 0.62,
    up_market_beat_rate: 0.58,
    down_market_beat_rate: 0.51,
    avg_excess_return_ann: 0.003,
    best_month_excess: 0.021,
    worst_month_excess: -0.018,
    months_observed: 60,
  },
  methodology: 'Basket built by stratified sampling: the benchmark is partitioned by GICS sector, the largest names per sector are retained to match sector weight, and remaining slots are filled to minimize ex-ante tracking error. Weights are market-cap-informed, capped per name and renormalized to sector targets. Quarterly rebalance assumed; transaction costs not modeled.',
  diagnostics_note: 'Rolling 60-day correlation stays above 0.94 across the window with no sustained breakdown. Up/down capture of 0.99/1.01 indicates symmetric tracking. Tracking error rises materially below ~60 names as omitted mid-cap idiosyncratic risk is no longer diversified away.',
  risks: [
    'Survivorship bias: the eligible universe reflects current index membership and understates drag from historically deleted names.',
    'Tracking error is backward-looking; regime shifts in rates or sector leadership can widen it out of sample.',
    'No transaction costs, taxes, or rebalance slippage are modeled; realized tracking will be modestly worse.',
    'Mega-cap concentration means the basket inherits single-name event risk more than the full index.',
  ],
  analyst_summary: 'The 75-name basket reproduces S&P 500 behavior closely: 0.99 return correlation, 1.8% annualized tracking error, and cumulative return within ~1.2% of the benchmark over five years. Sector weights are matched within ~0.6% per sector. It is a reasonable direct-indexing core; tracking quality degrades meaningfully below ~60 names.',
  disclaimers: [
    'Research support only. Not investment, legal, or tax advice.',
    'Backtested results are hypothetical and exclude trading costs, taxes, and slippage.',
  ],
};

// ============================================================================
// THEME — clean, blue-toned institutional palette
// ============================================================================
const C = {
  pageBg: '#F5F7FA', cardBg: '#FFFFFF', border: '#E2E8F0', borderLight: '#EDF2F7',
  accent: '#1D4ED8', accentMid: '#2563EB', accentLight: '#3B82F6', accentBg: '#EFF4FF',
  ink: '#0F172A', body: '#475569', muted: '#94A3B8',
  pos: '#047857', posBg: '#ECFDF5', neg: '#DC2626', negBg: '#FEF2F2',
  warn: '#B45309', warnBg: '#FFFBEB', neutralBg: '#F1F5F9',
};
const MONO = "'SF Mono', 'Fira Code', 'Consolas', monospace";
const SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";

const fmt = {
  num: (v, d = 2) => (v == null ? '—' : Number(v).toFixed(d)),
  pct: (v, d = 1) => (v == null ? '—' : (Number(v) * 100).toFixed(d) + '%'),
  spct: (v, d = 2) => {
    if (v == null) return '—';
    const n = Number(v) * 100;
    return (n >= 0 ? '+' : '') + n.toFixed(d) + '%';
  },
};

// ============================================================================
// SHARED PRIMITIVES
// ============================================================================
const Card = ({ title, subtitle, right, children }) => (
  <div style={{
    backgroundColor: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 8,
    padding: '20px 24px', marginBottom: 16, boxShadow: '0 1px 3px rgba(15,23,42,0.05)',
  }}>
    {(title || right) && (
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16, gap: 12 }}>
        <div>
          {title && <h2 style={{ fontSize: 16, fontWeight: 700, color: C.ink, margin: 0 }}>{title}</h2>}
          {subtitle && <div style={{ fontSize: 12, color: C.muted, marginTop: 3 }}>{subtitle}</div>}
        </div>
        {right}
      </div>
    )}
    {children}
  </div>
);

const Stat = ({ label, value, color }) => (
  <div>
    <div style={{ fontSize: 10, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 4 }}>{label}</div>
    <div style={{ fontSize: 15, fontWeight: 700, color: color || C.ink, fontFamily: MONO }}>{value}</div>
  </div>
);

const Fact = ({ label, value }) => (
  <div>
    <div style={{ fontSize: 10, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 3 }}>{label}</div>
    <div style={{ fontSize: 13, fontWeight: 600, color: C.ink }}>{value}</div>
  </div>
);

const EmptyChart = ({ h = 300 }) => (
  <div style={{ height: h, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: C.muted, fontStyle: 'italic' }}>
    No series data injected.
  </div>
);

const tipStyle = {
  backgroundColor: C.cardBg, border: `1px solid ${C.border}`,
  borderRadius: 4, fontSize: 12, boxShadow: '0 2px 8px rgba(15,23,42,0.08)',
};
const monthTick = (d) => (typeof d === 'string' ? d.slice(0, 7) : d);

// ============================================================================
// HEADER
// ============================================================================
const Header = ({ data }) => {
  const b = data.benchmark, k = data.basket;
  return (
    <div style={{
      backgroundColor: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 8,
      padding: '24px 28px', marginBottom: 16, boxShadow: '0 1px 3px rgba(15,23,42,0.05)',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 16 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: C.accent, textTransform: 'uppercase', letterSpacing: '0.09em', marginBottom: 6 }}>
            Direct Indexing &mdash; Index Tracking Basket
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12 }}>
            <span style={{ fontSize: 26, fontWeight: 800, color: C.ink }}>{b.name}</span>
            <span style={{
              fontSize: 11, fontWeight: 600, color: C.accent, backgroundColor: C.accentBg,
              padding: '3px 10px', borderRadius: 10, fontFamily: MONO,
              border: `1px solid ${C.accentLight}33`,
            }}>{b.ticker}</span>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.08em' }}>As Of</div>
          <div style={{ fontSize: 14, fontWeight: 700, color: C.ink, fontFamily: MONO, marginTop: 2 }}>{data.as_of}</div>
        </div>
      </div>
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 16,
        marginTop: 20, paddingTop: 18, borderTop: `1px solid ${C.borderLight}`,
      }}>
        <Fact label="Basket Size" value={`${k.size} names`} />
        <Fact label="Index Constituents" value={`${b.constituent_count}`} />
        <Fact label="Test Period" value={`${k.backtest_start} → ${k.backtest_end}`} />
        <Fact label="Rebalance" value={k.rebalance_frequency} />
        <Fact label="Weighting" value={k.weighting_method} />
        <Fact label="Construction" value={k.construction_method} />
        <Fact label="Data Source" value={k.data_source || 'yfinance'} />
      </div>
    </div>
  );
};

// ============================================================================
// KPI STRIP
// ============================================================================
const KPI_TONE = {
  good: { fg: C.pos, bg: C.posBg }, warn: { fg: C.warn, bg: C.warnBg },
  neutral: { fg: C.ink, bg: C.neutralBg },
};
const KpiCard = ({ label, value, sub, tone = 'neutral' }) => {
  const t = KPI_TONE[tone] || KPI_TONE.neutral;
  return (
    <div style={{
      backgroundColor: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 8,
      padding: '16px 18px', boxShadow: '0 1px 3px rgba(15,23,42,0.05)',
      borderTop: `3px solid ${t.fg}`,
    }}>
      <div style={{ fontSize: 10, fontWeight: 600, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 8 }}>{label}</div>
      <div style={{ fontSize: 24, fontWeight: 800, fontFamily: MONO, color: t.fg }}>{value}</div>
      <div style={{ fontSize: 10.5, color: C.muted, marginTop: 6, lineHeight: 1.4 }}>{sub}</div>
    </div>
  );
};

const KpiStrip = ({ data }) => {
  const k = data.kpis;
  const b = data.beat_diagnostics || {};
  const items = [
    { label: 'Return Correlation', value: fmt.num(k.correlation, 3), sub: 'Daily returns, basket vs index', tone: k.correlation >= 0.97 ? 'good' : 'warn' },
    { label: 'Tracking Error', value: fmt.pct(k.tracking_error_annualized, 2), sub: 'Annualized active return', tone: k.tracking_error_annualized <= 0.025 ? 'good' : 'warn' },
    { label: 'Cumulative Return Δ', value: fmt.spct(k.cumulative_return_diff), sub: 'Basket minus index, full period', tone: 'neutral' },
    { label: 'Volatility Gap', value: fmt.spct(k.volatility_gap), sub: 'Ann. vol, basket minus index', tone: 'neutral' },
    { label: 'Max Drawdown Δ', value: fmt.spct(k.max_drawdown_diff), sub: 'Basket minus index', tone: 'neutral' },
    { label: 'Monthly Beat Rate', value: fmt.pct(b.monthly_beat_rate, 1), sub: 'Months basket beat index (diagnostic)', tone: 'neutral' },
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(165px, 1fr))', gap: 14, marginBottom: 16 }}>
      {items.map((m, i) => <KpiCard key={i} {...m} />)}
    </div>
  );
};

// ============================================================================
// CHARTS
// ============================================================================
const PerformanceChart = ({ data }) => {
  const rows = useMemo(() => {
    const s = data.performance_series;
    if (!s || !s.dates || !s.dates.length) return [];
    return s.dates.map((d, i) => ({ date: d, Basket: s.basket?.[i], Index: s.benchmark?.[i] }));
  }, [data]);
  if (!rows.length) return <EmptyChart h={320} />;
  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={rows} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
        <CartesianGrid stroke={C.borderLight} strokeDasharray="3 3" />
        <XAxis dataKey="date" tickFormatter={monthTick} tick={{ fill: C.muted, fontSize: 10 }} axisLine={{ stroke: C.border }} tickLine={false} interval="preserveStartEnd" minTickGap={48} />
        <YAxis tick={{ fill: C.muted, fontSize: 11 }} axisLine={{ stroke: C.border }} tickLine={false} domain={['auto', 'auto']} width={48} />
        <Tooltip contentStyle={tipStyle} formatter={(v) => (v == null ? '—' : Number(v).toFixed(2))} isAnimationActive={false} />
        <ReferenceLine y={100} stroke={C.border} strokeDasharray="2 4" />
        <Line type="monotone" dataKey="Index" stroke={C.ink} strokeWidth={2.25} dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="Basket" stroke={C.accentMid} strokeWidth={2.25} dot={false} isAnimationActive={false} />
      </LineChart>
    </ResponsiveContainer>
  );
};

const RollingCorrChart = ({ data }) => {
  const s = data.rolling_correlation;
  const rows = useMemo(() => {
    if (!s || !s.dates || !s.dates.length) return [];
    return s.dates.map((d, i) => ({ date: d, corr: s.values?.[i] }));
  }, [s]);
  if (!rows.length) return <EmptyChart h={240} />;
  return (
    <ResponsiveContainer width="100%" height={240}>
      <LineChart data={rows} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
        <CartesianGrid stroke={C.borderLight} strokeDasharray="3 3" />
        <XAxis dataKey="date" tickFormatter={monthTick} tick={{ fill: C.muted, fontSize: 10 }} axisLine={{ stroke: C.border }} tickLine={false} interval="preserveStartEnd" minTickGap={48} />
        <YAxis tick={{ fill: C.muted, fontSize: 11 }} axisLine={{ stroke: C.border }} tickLine={false} domain={[0.7, 1]} width={44} />
        <Tooltip contentStyle={tipStyle} formatter={(v) => (v == null ? '—' : Number(v).toFixed(3))} isAnimationActive={false} />
        <ReferenceLine y={0.9} stroke={C.warn} strokeDasharray="4 4" />
        <Line type="monotone" dataKey="corr" name="Rolling ρ" stroke={C.accent} strokeWidth={2} dot={false} isAnimationActive={false} />
      </LineChart>
    </ResponsiveContainer>
  );
};

const ActiveReturnChart = ({ data }) => {
  const s = data.active_return_series;
  const rows = useMemo(() => {
    if (!s || !s.dates || !s.dates.length) return [];
    return s.dates.map((d, i) => ({ date: d, active: s.cumulative_active_return?.[i] }));
  }, [s]);
  if (!rows.length) return <EmptyChart h={240} />;
  return (
    <ResponsiveContainer width="100%" height={240}>
      <AreaChart data={rows} margin={{ top: 8, right: 16, bottom: 8, left: 8 }}>
        <defs>
          <linearGradient id="actFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={C.accentLight} stopOpacity={0.35} />
            <stop offset="100%" stopColor={C.accentLight} stopOpacity={0.02} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke={C.borderLight} strokeDasharray="3 3" />
        <XAxis dataKey="date" tickFormatter={monthTick} tick={{ fill: C.muted, fontSize: 10 }} axisLine={{ stroke: C.border }} tickLine={false} interval="preserveStartEnd" minTickGap={48} />
        <YAxis tick={{ fill: C.muted, fontSize: 11 }} axisLine={{ stroke: C.border }} tickLine={false} tickFormatter={(v) => (v * 100).toFixed(1) + '%'} width={52} />
        <Tooltip contentStyle={tipStyle} formatter={(v) => (v == null ? '—' : (v * 100).toFixed(2) + '%')} isAnimationActive={false} />
        <ReferenceLine y={0} stroke={C.ink} strokeWidth={1} />
        <Area type="monotone" dataKey="active" name="Cumulative active return" stroke={C.accentMid} strokeWidth={2} fill="url(#actFill)" isAnimationActive={false} />
      </AreaChart>
    </ResponsiveContainer>
  );
};

const SectorChart = ({ data }) => {
  const rows = useMemo(() => (data.sector_exposure || []).map((r) => ({
    sector: r.sector, Basket: (r.basket_weight || 0) * 100, Index: (r.benchmark_weight || 0) * 100,
  })), [data]);
  if (!rows.length) return <EmptyChart h={320} />;
  return (
    <ResponsiveContainer width="100%" height={Math.max(280, rows.length * 30)}>
      <BarChart data={rows} layout="vertical" margin={{ top: 4, right: 20, bottom: 4, left: 8 }} barGap={2}>
        <CartesianGrid stroke={C.borderLight} strokeDasharray="3 3" horizontal={false} />
        <XAxis type="number" tick={{ fill: C.muted, fontSize: 10 }} axisLine={{ stroke: C.border }} tickLine={false} tickFormatter={(v) => v + '%'} />
        <YAxis type="category" dataKey="sector" tick={{ fill: C.body, fontSize: 10.5 }} axisLine={{ stroke: C.border }} tickLine={false} width={148} />
        <Tooltip contentStyle={tipStyle} formatter={(v) => Number(v).toFixed(2) + '%'} isAnimationActive={false} />
        <Bar dataKey="Index" fill={C.ink} radius={[0, 2, 2, 0]} />
        <Bar dataKey="Basket" fill={C.accentMid} radius={[0, 2, 2, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
};

const ChartLegend = ({ items }) => (
  <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
    {items.map((it, i) => (
      <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ width: 10, height: 10, borderRadius: 2, backgroundColor: it.color, display: 'inline-block' }} />
        <span style={{ fontSize: 11.5, color: C.body, fontWeight: 600 }}>{it.label}</span>
      </div>
    ))}
  </div>
);

// ============================================================================
// HOLDINGS TABLE
// ============================================================================
const th = { fontSize: 10, fontWeight: 700, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.06em', padding: '8px 10px', textAlign: 'left', position: 'sticky', top: 0, backgroundColor: C.neutralBg, borderBottom: `1px solid ${C.border}` };
const td = { fontSize: 12, color: C.body, padding: '8px 10px', borderBottom: `1px solid ${C.borderLight}` };

const HoldingsTable = ({ data }) => {
  const rows = data.holdings || [];
  return (
    <div style={{ maxHeight: 440, overflowY: 'auto', border: `1px solid ${C.border}`, borderRadius: 6 }}>
      <table style={{ width: '100%', borderCollapse: 'collapse' }}>
        <thead>
          <tr>
            <th style={{ ...th, textAlign: 'left' }}>Ticker</th>
            <th style={th}>Company</th>
            <th style={th}>Sector</th>
            <th style={{ ...th, textAlign: 'right' }}>Weight</th>
            <th style={{ ...th, textAlign: 'right' }}>Index Wt</th>
            <th style={{ ...th, textAlign: 'right' }}>Active</th>
            <th style={th}>Benchmark Role</th>
            <th style={th}>Note</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((h, i) => {
            const active = (h.weight || 0) - (h.benchmark_weight || 0);
            return (
              <tr key={i}>
                <td style={{ ...td, fontFamily: MONO, fontWeight: 700, color: C.ink }}>{h.ticker}</td>
                <td style={td}>{h.name}</td>
                <td style={{ ...td, color: C.muted }}>{h.sector}</td>
                <td style={{ ...td, textAlign: 'right', fontFamily: MONO, fontWeight: 700, color: C.ink }}>{fmt.pct(h.weight, 2)}</td>
                <td style={{ ...td, textAlign: 'right', fontFamily: MONO, color: C.muted }}>{fmt.pct(h.benchmark_weight, 2)}</td>
                <td style={{ ...td, textAlign: 'right', fontFamily: MONO, color: active >= 0 ? C.pos : C.neg }}>{fmt.spct(active)}</td>
                <td style={{ ...td, color: C.body }}>{h.role}</td>
                <td style={{ ...td, color: C.muted }}>{h.note}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};

// ============================================================================
// DIAGNOSTICS
// ============================================================================
const Diagnostics = ({ data }) => {
  const s = data.stats || {};
  const ss = data.size_sensitivity || [];
  return (
    <>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(120px, 1fr))', gap: 16, marginBottom: 18 }}>
        <Stat label="Beta" value={fmt.num(s.beta)} />
        <Stat label="R²" value={fmt.num(s.r_squared, 3)} />
        <Stat label="Ann. Return — Basket" value={fmt.pct(s.ann_return_basket)} />
        <Stat label="Ann. Return — Index" value={fmt.pct(s.ann_return_benchmark)} />
        <Stat label="Ann. Vol — Basket" value={fmt.pct(s.ann_vol_basket)} />
        <Stat label="Ann. Vol — Index" value={fmt.pct(s.ann_vol_benchmark)} />
        <Stat label="Max DD — Basket" value={fmt.pct(s.max_dd_basket)} color={C.neg} />
        <Stat label="Max DD — Index" value={fmt.pct(s.max_dd_benchmark)} color={C.neg} />
        <Stat label="Up Capture" value={fmt.num(s.up_capture)} />
        <Stat label="Down Capture" value={fmt.num(s.down_capture)} />
      </div>
      {ss.length > 0 && (
        <div style={{ marginBottom: 14 }}>
          <div style={{ fontSize: 11, fontWeight: 700, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 8 }}>
            Basket-Size Sensitivity
          </div>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={{ ...th, position: 'static' }}>Basket Size</th>
                <th style={{ ...th, position: 'static', textAlign: 'right' }}>Tracking Error</th>
                <th style={{ ...th, position: 'static', textAlign: 'right' }}>Correlation</th>
              </tr>
            </thead>
            <tbody>
              {ss.map((r, i) => {
                const sel = r.size === data.basket.size;
                return (
                  <tr key={i} style={{ backgroundColor: sel ? C.accentBg : 'transparent' }}>
                    <td style={{ ...td, fontFamily: MONO, fontWeight: sel ? 700 : 500, color: C.ink }}>
                      {r.size}{sel ? '  ← selected' : ''}
                    </td>
                    <td style={{ ...td, textAlign: 'right', fontFamily: MONO }}>{fmt.pct(r.tracking_error_annualized, 2)}</td>
                    <td style={{ ...td, textAlign: 'right', fontFamily: MONO }}>{fmt.num(r.correlation, 3)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {data.diagnostics_note && (
        <div style={{ fontSize: 12.5, color: C.body, lineHeight: 1.6 }}>{data.diagnostics_note}</div>
      )}
    </>
  );
};

// ============================================================================
// BEAT DIAGNOSTICS
// ============================================================================
const BeatDiagnostics = ({ data }) => {
  const b = data.beat_diagnostics || {};
  return (
    <>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 16, marginBottom: 14 }}>
        <Stat label="Monthly Beat Rate" value={fmt.pct(b.monthly_beat_rate, 1)} />
        <Stat label="Rolling 12M Beat Rate" value={fmt.pct(b.rolling_12m_beat_rate, 1)} />
        <Stat label="Up-Market Beat Rate" value={fmt.pct(b.up_market_beat_rate, 1)} />
        <Stat label="Down-Market Beat Rate" value={fmt.pct(b.down_market_beat_rate, 1)} />
        <Stat label="Avg Excess Return (Ann.)" value={fmt.spct(b.avg_excess_return_ann)} color={(b.avg_excess_return_ann || 0) >= 0 ? C.pos : C.neg} />
        <Stat label="Best Month Excess" value={fmt.spct(b.best_month_excess)} color={C.pos} />
        <Stat label="Worst Month Excess" value={fmt.spct(b.worst_month_excess)} color={C.neg} />
        <Stat label="Months Observed" value={fmt.num(b.months_observed, 0)} />
      </div>
      <div style={{ fontSize: 11.5, color: C.muted, fontStyle: 'italic', lineHeight: 1.5 }}>
        Diagnostic only. The basket is constructed to track the index, not to beat it — these rates report incidental relative performance over the test window, not an alpha thesis.
      </div>
    </>
  );
};

// ============================================================================
// NARRATIVE PANELS
// ============================================================================
const NotePanel = ({ text }) => (
  <div style={{ fontSize: 13, color: C.body, lineHeight: 1.65 }}>{text}</div>
);

const RisksPanel = ({ items }) => (
  <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
    {(items || []).map((r, i) => (
      <div key={i} style={{ display: 'flex', gap: 8, fontSize: 12.5, color: C.body, lineHeight: 1.55 }}>
        <span style={{ color: C.warn, fontWeight: 700 }}>&bull;</span><span>{r}</span>
      </div>
    ))}
  </div>
);

const Disclaimer = ({ items }) => (
  <div style={{ backgroundColor: C.warnBg, border: `1px solid ${C.warn}33`, borderRadius: 6, padding: '12px 16px', marginBottom: 24 }}>
    <div style={{ fontSize: 10, fontWeight: 700, color: C.warn, textTransform: 'uppercase', letterSpacing: '0.08em', marginBottom: 5 }}>Important</div>
    {(items || []).map((d, i) => (
      <div key={i} style={{ fontSize: 11.5, color: C.body, lineHeight: 1.55 }}>&bull; {d}</div>
    ))}
  </div>
);

// ============================================================================
// VIEW TOGGLE — controls Summary vs. Full Detail rendering
// ============================================================================
const VIEWS = {
  summary: {
    label: 'Summary',
    blurb: 'Essentials only — header, KPIs, the performance chart, and the analyst verdict. Detailed sections are collapsed.',
  },
  full: {
    label: 'Full Detail',
    blurb: 'All sections expanded — rolling diagnostics, active return, sector exposure, holdings, methodology, and risks.',
  },
};

function ViewToggle({ view, onChange }) {
  const cfg = VIEWS[view] || VIEWS.full;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap',
      backgroundColor: C.cardBg, border: `1px solid ${C.border}`, borderRadius: 8,
      padding: '12px 16px', marginBottom: 16, boxShadow: '0 1px 3px rgba(15,23,42,0.05)',
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, flex: 1, minWidth: 220 }}>
        <span style={{ fontSize: 10, fontWeight: 700, color: C.accent, textTransform: 'uppercase', letterSpacing: '0.08em', whiteSpace: 'nowrap' }}>
          {cfg.label} view
        </span>
        <span style={{ fontSize: 12, color: C.body }}>{cfg.blurb}</span>
      </div>
      <div style={{ display: 'flex', border: `1px solid ${C.border}`, borderRadius: 6, overflow: 'hidden', flexShrink: 0 }}>
        {Object.keys(VIEWS).map((key) => {
          const on = key === view;
          return (
            <button
              key={key}
              type="button"
              aria-pressed={on}
              onClick={() => onChange(key)}
              style={{
                border: 'none', cursor: 'pointer', padding: '7px 16px', fontSize: 12, fontWeight: 700,
                fontFamily: SANS, backgroundColor: on ? C.accent : C.cardBg, color: on ? '#FFFFFF' : C.body,
              }}
            >{VIEWS[key].label}</button>
          );
        })}
      </div>
    </div>
  );
}

// ============================================================================
// MAIN EXPORT
// ============================================================================
export default function DirectIndexBasketDashboard() {
  const data = DATA;
  const [view, setView] = useState('full');
  const isFull = view === 'full';

  return (
    <div style={{ backgroundColor: C.pageBg, minHeight: '100vh', padding: '24px 16px', fontFamily: SANS, color: C.ink }}>
      <div style={{ maxWidth: 1200, margin: '0 auto' }}>
        <Header data={data} />

        <ViewToggle view={view} onChange={setView} />

        <KpiStrip data={data} />

        <Card title="Cumulative Performance" subtitle="Basket vs. index, rebased to 100 at the start of the test period"
          right={<ChartLegend items={[{ color: C.ink, label: data.benchmark.name }, { color: C.accentMid, label: 'Tracking Basket' }]} />}>
          <PerformanceChart data={data} />
        </Card>

        {isFull && (
          <>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 16 }}>
              <Card title="Rolling Correlation" subtitle={`${data.rolling_correlation?.window_days || 60}-day window of daily returns`}>
                <RollingCorrChart data={data} />
              </Card>
              <Card title="Cumulative Active Return" subtitle="Basket return minus index return, compounded">
                <ActiveReturnChart data={data} />
              </Card>
            </div>

            <Card title="Sector Exposure" subtitle="Basket weight vs. index weight by GICS sector"
              right={<ChartLegend items={[{ color: C.ink, label: 'Index' }, { color: C.accentMid, label: 'Basket' }]} />}>
              <SectorChart data={data} />
            </Card>

            <Card title="Basket Composition" subtitle={`${(data.holdings || []).length} holdings — ticker, weight, active tilt, and benchmark role`}>
              <HoldingsTable data={data} />
            </Card>

            <Card title="Tracking Diagnostics" subtitle="Risk-adjusted fit, capture ratios, and size sensitivity">
              <Diagnostics data={data} />
            </Card>

            <Card title="Beat Diagnostics" subtitle="Backward-looking excess-return metrics — reported alongside tracking, not the objective">
              <BeatDiagnostics data={data} />
            </Card>

            <Card title="Methodology" subtitle="How the basket was constructed and weighted">
              <NotePanel text={data.methodology} />
            </Card>
          </>
        )}

        <Card title="Analyst Summary" subtitle="Verdict on tracking quality and fitness for use">
          <NotePanel text={data.analyst_summary} />
        </Card>

        {isFull && (
          <Card title="Risks & Caveats" subtitle="Limitations of the construction and backtest">
            <RisksPanel items={data.risks} />
          </Card>
        )}

        <Disclaimer items={data.disclaimers} />
      </div>
    </div>
  );
}
```
