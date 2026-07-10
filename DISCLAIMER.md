# Disclaimer

**This project is research and educational tooling — not financial, legal, or tax advice.**

## Scope

The `direct-index-basket` skill helps a user construct and backtest a reduced-stock basket intended to track a target equity index. Its outputs (the interactive React dashboard, the canonical JSON payload, and the five-sheet Excel workbook) are analytical artifacts that describe hypothetical portfolio behavior over historical windows.

## No advice, no recommendation, no solicitation

Nothing produced by this skill or contained in this repository constitutes:

- Investment advice or a recommendation to buy, sell, or hold any security.
- A solicitation, offer, or endorsement of any strategy, product, adviser, or platform.
- Legal advice concerning securities regulation, wash-sale rules, "substantially identical" determinations, or any other legal question.
- Tax advice concerning realization events, tax-loss harvesting, cost-basis treatment, or account-level tax outcomes.

Users are solely responsible for consulting qualified financial, legal, and tax professionals before making any decision informed by this tool.

## No performance representation

- Backtested results are **hypothetical**. They do not represent actual trading or actual accounts and do not reflect transaction costs, taxes, market impact, slippage, fees, or borrowing costs.
- Past correlation, tracking behavior, and beat diagnostics do not guarantee future results. Out-of-sample behavior may differ materially from the backtest window.
- Beat-rate and excess-return metrics are diagnostic. The basket is designed to **track** the index; any observed outperformance is incidental and should not be interpreted as an alpha thesis.

## Data quality

- Constituent lists, sector tags, and adjusted-price series depend on the chosen data source (`yfinance`, LSEG Refinitiv, Polygon, or web search) and inherit that source's limitations.
- The eligible universe reflects **current** index membership and may understate the historical impact of deleted names (survivorship bias).
- Weights, correlations, and diagnostics are point-in-time estimates and change with the input data window.

## No liability

The software is provided **"as is"**, without warranty of any kind, express or implied. The author and any contributors accept no liability for losses, damages, or other consequences arising from use of this repository, the skill, or any output produced by it. See [`LICENSE`](./LICENSE) for the full terms.

## Copyright

Copyright © 2026 Jason Zou. All rights reserved to the extent not granted under the MIT License in [`LICENSE`](./LICENSE).
