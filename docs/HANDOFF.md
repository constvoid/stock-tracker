# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `main` tracking `origin/main`  
**Status:** Phases 0–1 complete. Empty iOS app and `StockTrackerKit` modules
build; package unit tests pass. Next is Phase 2 (Domain + PortfolioMath).  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) for the ordered delivery plan — start Phase 2.
3. Use the focused documents only as needed:
   - [architecture.md](architecture.md)
   - [import-design.md](import-design.md)
   - [domain-and-data.md](domain-and-data.md)
   - [ui-design.md](ui-design.md)
   - [carplay.md](carplay.md)
4. Reconcile any requested change in `SPEC.md` first, then design, TODO, code,
   and tests. Do not treat chat history as the source of truth.

## Current design baseline

- iPhone-first, iOS 18+, local-only SwiftData.
- Read-only US stocks/ETFs plus per-account cash; no trading.
- One complete file per brokerage; each parser yields multiple accounts through
  a brokerage-agnostic contract.
- Initial adapters: Schwab and E*TRADE.
- Hybrid `PositionSlice`: exact acquisition rows or aggregate unknown-date
  positions.
- Account-level wipe/replace with warnings allowed and errors blocking that
  account; valid sibling accounts may commit.
- All accounts stored; enabled/hidden controls portfolio participation.
- Missing account from next complete brokerage file is retained as stale.
- Weighted average cost uses imported unit cost; rounding differences warn.
- Portfolio-wide duplicate symbols aggregate.
- Unknown acquisition dates hide account tax-term reporting and make charts
  estimated across the full selected range.
- Yahoo-style market data behind replaceable protocols.
- Tabs: Overview, Holdings, Settings/Import.
- Overview includes totals, chart, Movers, and brokerage/account breakdown.
- iPhone car glance first; true CarPlay templates later if entitlement allows.

## Repo layout (implemented)

- `StockTracker.xcodeproj` via `project.yml` (XcodeGen).
- `Apps/StockTracker/` composition root (`AppDependencies`, three-tab shell).
- `Packages/StockTrackerKit/` multi-target package (no CarPlay target yet).
- `Fixtures/Anonymized/` fabricated Schwab/E*TRADE CSVs for tests.
- `data/import/` and `data/sampleui/` remain local-only and gitignored.

## Build notes

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

## What happens next

1. Phase 2: Domain value types and PortfolioMath calculations with fabricated
   unit tests (`PROD-003`, `DATA-002`, `CALC-*`, `ACCT-*`).
2. Do not start Phase 3 persistence/import until Phase 2 exit criteria pass.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
