# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `main` tracking `origin/main`  
**Status:** Phases 0–2 complete. Domain + PortfolioMath unit tests pass (13).
Next is Phase 3 (SwiftData persistence and brokerage-file import).  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) for the ordered delivery plan — start Phase 3.
3. Use focused docs as needed: [architecture.md](architecture.md),
   [import-design.md](import-design.md), [domain-and-data.md](domain-and-data.md).
4. Reconcile any requested change in `SPEC.md` first, then design, TODO, code,
   and tests.

## Implemented so far

- Privacy gitignore; fabricated fixtures in `Fixtures/Anonymized/`.
- `StockTracker.xcodeproj` (XcodeGen) + three-tab app shell + `AppDependencies`
  fakes.
- `StockTrackerKit` modules with dependency rules; no CarPlay target.
- Domain: Money/Quantity/UnitCost, identities, hybrid `PositionSlice`, accounts.
- PortfolioMath: WAC, account/portfolio rollups, duplicate-symbol aggregation,
  tax-term/history capability derivation.

## Build notes

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

## What happens next

1. Phase 3: versioned SwiftData, account-level wipe/replace, Schwab/E*TRADE
   parsers against anonymized fixtures, stale detection, redacted diagnostics.
2. Do not start Phase 4 UI until Phase 3 exit criteria pass.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
