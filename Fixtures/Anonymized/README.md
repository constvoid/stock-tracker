# Anonymized import fixtures

Fabricated brokerage CSV files for parser and import tests. They preserve
observed schema and edge-case structure only.

**Never** copy contents from `data/import/` or `data/sampleui/` into this tree.
All account labels, suffixes, symbols, quantities, and values here are invented.

| File | Covers |
| --- | --- |
| `schwab-positions-multi-account.csv` | Three accounts (one cash-only), fractional qty, ETF, slash symbol |
| `etrade-portfolio-single-account.csv` | Account summary + dated lots, cash, total, generated-at |
