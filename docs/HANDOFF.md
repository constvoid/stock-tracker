# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `phase-3-persistence-import` (Phases 3–4 work; uncommitted unless
committed in a later session)  
**Status:** Phases 0–4 complete. Local SwiftData app with import UI and
Overview/Holdings/Account Detail on imported prices. `swift test`: 27.  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) — start Phase 5 (live market data).
3. Use focused docs: [architecture.md](architecture.md), [ui-design.md](ui-design.md).

## Implemented through Phase 4

- Import pipeline + SwiftData persistence (Phase 3).
- DesignSystem tokens, money formatting, directional change indicators.
- Read models / use cases: overview, holdings, account detail, settings,
  visibility, stale resolution.
- Three-tab shell: Overview (totals, movers placeholder, account breakdown),
  Holdings (aggregated + cash), Settings (file import preview/confirm/result,
  toggles, stale actions).
- Account Detail sheet with cash-only and tax-term gating.
- Chart UI deferred to Phase 6; Overview shows quality disclosure instead.

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
