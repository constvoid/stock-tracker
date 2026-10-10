# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `phase-3-persistence-import` (Phases 3–4 work; uncommitted unless
committed in a later session)  
**Status:** Phases 0–5 complete. Live Yahoo-style quotes with extended hours,
pull-to-refresh + foreground refresh, stale-on-failure. Next: Phase 6 history.  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) — start Phase 6 (reconstructed history).
3. Use focused docs: [architecture.md](architecture.md), [ui-design.md](ui-design.md).

## Implemented through Phase 5

- Phases 3–4 import/persistence/UI.
- `YahooStyleQuoteProvider` (extended hours on), `FakeQuoteProvider`, symbol aliases.
- `RefreshMarketData` with cache/stale behavior; holdings never cleared on failure.
- Overview/Holdings refresh on pull and foreground activation (`MKT-003`).

## Build notes

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

## What happens next

1. Phase 5: Yahoo-style quotes, previous close / Movers, pull-to-refresh,
   cache freshness; network failure must not alter holdings.
2. Do not start reconstructed history (Phase 6) until Phase 5 exit criteria pass.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
