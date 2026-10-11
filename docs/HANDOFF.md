# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `phase-3-persistence-import`  
**Status:** Phases 0–7 complete. Car Glance is a full-screen iPhone surface from
Settings (not CarPlay). Next: Phase 8 observed history.  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) — start Phase 8 (observed valuation snapshots).
3. Use focused docs as needed.

## Implemented through Phase 7

- Phases 3–6: import, UI, live quotes, reconstructed charts.
- `CarGlanceFeature`: large-type total, today's change, freshness, top accounts.
- Opened from Settings → Driving → Open Car Glance (fullScreenCover).
- Reuses `GetPortfolioOverview` / `RefreshMarketData`; no CarPlay entitlement.

## Build notes

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

## What happens next

1. Phase 8: persist valuation snapshots; prefer observed coverage in
   `GetHistoricalValue` without changing feature APIs.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
