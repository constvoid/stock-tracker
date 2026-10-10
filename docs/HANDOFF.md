# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `main` tracking `origin/main`  
**Status:** Specification and design approved. Phase 0 privacy/fixtures in
progress; no Swift/Xcode app yet until Phase 1 scaffold.  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) for the ordered delivery plan.
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

## Supplied planning inputs

- `data/import/`: one Schwab sample with three accounts (one cash-only) and one
  E*TRADE sample currently containing one account.
- `data/sampleui/`: six SigFig reference images showing hierarchy for
  performance, Movers, account breakdown, and holdings.

These files contain private financial information. They are local reference
only and are gitignored. Fabricated fixtures under `Fixtures/Anonymized/` are
required for tests.

## What happens next

1. Finish Phase 0: fabricated Schwab/E*TRADE fixtures committed safely.
2. Start Phase 1: Xcode project and `StockTrackerKit` module scaffold.
3. Continue through [TODO.md](TODO.md) phases without skipping privacy or
   module-boundary gates.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
