# Handoff — pick up here

**Repo:** `/Volumes/extssd/dev/macapps/stock-tracker`  
**Branch:** `phase-3-persistence-import`  
**Status:** Phases 0–6 complete. Live quotes (extended hours), reconstructed
history charts with HIST-005 gap rules. `swift test`: 35. Next: Phase 7 car
glance.  
**Approval:** Krishna approved the living specification and design (2026-10-10).

## Resume order

1. Read [SPEC.md](SPEC.md). It is normative.
2. Read [TODO.md](TODO.md) — start Phase 7 (iPhone car glance).
3. Use focused docs: [architecture.md](architecture.md), [ui-design.md](ui-design.md),
   [carplay.md](carplay.md).

## Implemented through Phase 6

- Phases 3–5 import, UI, Yahoo-style quotes with extended hours.
- Intraday (5m) + daily history providers; bar cache in SwiftData.
- `HistoryReconstruction` + `GetHistoricalValue` for portfolio/account scopes.
- Overview and Account Detail charts with range picker, scrub, reconstructed /
  estimated disclosure.
- Missing bars: carry across non-sessions; gap on missing trading days (`HIST-005`).

## Build notes

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

## What happens next

1. Phase 7: large-type iPhone car-glance surface from shared overview use case.
2. Do not block on CarPlay entitlement.

## Session rules

- Do not re-ask confirmed requirements.
- Do not create commits unless Krishna asks.
- Do not begin adjacent/deferred features.
- No raw brokerage rows, balances, or screenshots in tests/logs/git history.
