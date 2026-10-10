# stock-tracker

iPhone-first Swift portfolio tracker. Specification and design are approved;
implementation follows [docs/TODO.md](docs/TODO.md).

The living source of requirements is **[docs/SPEC.md](docs/SPEC.md)**.
Continue from [docs/HANDOFF.md](docs/HANDOFF.md). Full design index:
[docs/README.md](docs/README.md).

## Status

Phases 0–6 complete on `phase-3-persistence-import`: import, UI, live quotes
(with extended hours), and reconstructed history charts. Next: Phase 7 car
glance.

## Build

Requires Xcode (not Command Line Tools only). Regenerate the project after
editing `project.yml`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -project StockTracker.xcodeproj -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
(cd Packages/StockTrackerKit && swift test)
```

Private brokerage samples and UI references under `data/` are gitignored.
Tests use `Fixtures/Anonymized/` only.
