# Software Architecture

**Status:** Approved (2026-10-10)  
**Normative source:** [SPEC.md](SPEC.md)  
**Companion designs:** [import-design.md](import-design.md),
[domain-and-data.md](domain-and-data.md), [ui-design.md](ui-design.md),
[carplay.md](carplay.md)

## Architectural goals

Stock Tracker is an iOS 18+ read-only portfolio application. Its boundaries
must let the product:

- add brokerage adapters without changing portfolio logic;
- replace Yahoo-style market data without changing features;
- evolve SwiftData or add sync without leaking persistence into Domain/UI;
- share use cases across iPhone, car glance, and later CarPlay;
- add observed valuation snapshots without changing chart presentation APIs;
- test financial calculations and imports without launching the app.

`SPEC.md` owns requirements. This document explains how the system satisfies
them.

## Architectural style

Use ports-and-adapters with feature-oriented presentation modules:

```text
StockTrackerApp (composition root)
  ├── OverviewFeature
  ├── HoldingsFeature
  ├── ImportSettingsFeature
  ├── AccountDetailFeature
  ├── CarGlanceFeature
  └── CarPlayFeature (later)
          │
          ▼
      Application
      use cases + ports + read models
       │          │
       ▼          ▼
  PortfolioMath  Domain
       ▲          ▲
       │          │
  ┌────┴─────┬────┴──────┬─────────────┐
  │Importing │Persistence│ MarketData  │
  │CSV       │SwiftData  │ Yahoo-style │
  └──────────┴───────────┴─────────────┘
```

Dependencies point inward. Adapter modules implement ports owned by
Application. The app target is the only composition root.

## Xcode and Swift package layout

Prefer one local Swift package with multiple targets. This keeps module
boundaries enforceable without managing many package manifests.

```text
stock-tracker/
  StockTracker.xcodeproj
  Apps/
    StockTracker/
      StockTrackerApp.swift
      AppDependencies.swift
      AppScene.swift
  Packages/
    StockTrackerKit/
      Package.swift
      Sources/
        Domain/
        PortfolioMath/
        Application/
        Importing/
        Persistence/
        MarketData/
        DesignSystem/
        OverviewFeature/
        HoldingsFeature/
        AccountDetailFeature/
        ImportSettingsFeature/
        CarGlanceFeature/
        CarPlayFeature/          # create only in its delivery phase
      Tests/
        DomainTests/
        PortfolioMathTests/
        ApplicationTests/
        ImportingTests/
        PersistenceTests/
  Fixtures/
    Anonymized/                  # committed fabricated data only
  docs/
```

Do not copy `data/import/` or `data/sampleui/` into fixtures.

## Target responsibilities

### Domain

Pure, immutable Swift value types and invariants:

- `Brokerage`, `BrokerageAccount`, `PositionSlice`, `Position`, `CashBalance`;
- decimal `Money`, `Quantity`, `UnitCost`;
- native/canonical symbols and IDs;
- account visibility/stale state;
- source provenance and capability/quality values;
- `TimeRange`, `ValuationPoint`, quote/price-bar values.

Domain imports Foundation only for value primitives such as `Date` and
`Decimal`. It does not contain network, file, database, UI, analytics, or
CarPlay code.

### PortfolioMath

Deterministic functions over Domain values:

- weighted average cost;
- account/portfolio rollups;
- duplicate-symbol aggregation;
- daily Movers ranking;
- tax-term capability and classification;
- reconstructed intraday/daily valuation series;
- price alignment and missing-bar policy.

No I/O, global clock, locale, or mutable cache. Inject time/calendar when
classification depends on "today."

### Application

Owns ports, orchestration, read models, and use cases:

- `BrokerageImporting`;
- `PortfolioRepository`;
- `QuoteProviding`, `IntradayPriceProviding`,
  `HistoricalPriceProviding`;
- `ImportBrokerageFiles`;
- `PreviewBrokerageImports`;
- `CommitAccountImports`;
- `RefreshMarketData`;
- `GetPortfolioOverview`;
- `GetPortfolioHoldings`;
- `GetAccountDetail`;
- `GetHistoricalValue`;
- `SetAccountVisibility`;
- `ResolveStaleAccount`.

Use cases return immutable, `Sendable` read models and errors suitable for
presentation. They do not return SwiftData models or parser rows.

### Importing

Implements `BrokerageImporting` and contains:

- parser registry and content probes;
- the common brokerage-file DTOs;
- Schwab and E*TRADE adapters;
- symbol normalization candidates;
- validation and reconciliation issues;
- import preview construction.

See [import-design.md](import-design.md).

### Persistence

Implements `PortfolioRepository` with SwiftData:

- versioned schema and record/domain mapping;
- account-level transactional replacement;
- quote and price-bar cache;
- import audit records;
- account visibility/stale state;
- later, observed valuation snapshots.

No business calculations live in persistence mapping.

### MarketData

Implements the three market-data ports:

- provider-symbol resolution;
- latest/previous-close quotes;
- five-minute intraday bars;
- daily historical closes;
- retry/rate-limit/cache policy;
- conversion of provider failures to Application errors.

Yahoo-specific payloads and symbols never cross the adapter boundary.

### Feature targets

Each SwiftUI feature owns screens, `@MainActor` observable models, navigation
destinations, and accessibility behavior for one product surface. Feature
models invoke use cases injected through small interfaces. They never
instantiate adapters or query SwiftData directly.

`DesignSystem` owns semantic color, typography, spacing, value formatting, and
shared loading/error/empty components. It does not own product logic.

### StockTrackerApp

The app target:

- initializes SwiftData and adapters;
- creates Application use cases;
- injects feature dependencies;
- declares the three-tab scene;
- owns lifecycle/background refresh hooks and entitlements.

There is no global service locator. `AppDependencies` is constructed once and
passed explicitly.

## Dependency rules

```text
Domain           → Foundation
PortfolioMath    → Domain
Application      → Domain, PortfolioMath
Importing        → Domain, Application
Persistence      → Domain, Application, SwiftData
MarketData       → Domain, Application, URLSession
DesignSystem     → SwiftUI
Feature targets  → Domain, Application, DesignSystem, SwiftUI
CarPlayFeature   → Domain, Application, CarPlay
StockTrackerApp  → all active adapters/features
```

Forbidden edges:

- Domain → SwiftUI, SwiftData, CarPlay, URLSession, CSV parser;
- Application → concrete adapter;
- feature → Persistence, Importing, MarketData concrete implementation;
- adapter → feature;
- CarPlay → SwiftUI feature modules.

## Runtime data flows

### Import

```text
Settings/Import
  → ImportBrokerageFiles
  → BrokerageImporting
  → brokerage-agnostic batches
  → PreviewBrokerageImports
  → explicit user confirmation
  → CommitAccountImports
  → PortfolioRepository account transaction
  → overview/holdings refresh
```

Warnings can commit. A row error blocks only its account. One complete file per
brokerage enables stale-account detection.

### Overview and holdings

```text
Feature request
  → Application use case
  → PortfolioRepository snapshots + cached quotes
  → PortfolioMath
  → immutable read model
  → SwiftUI
```

Only enabled accounts participate in portfolio-wide read models. Account detail
can still open a hidden account from Settings.

### Quote refresh

```text
Refresh trigger
  → symbols from enabled + visible account context
  → MarketData adapter
  → repository cache
  → recompute read models
```

Failures leave holdings intact and return stale imported/cached values with
as-of/source metadata.

### Historical chart

`GetHistoricalValue` chooses intraday bars for Day and daily closes otherwise.
PortfolioMath applies known acquisition dates, estimates unknown-date aggregate
positions across the full selected range, adds flat cash, and returns quality
metadata. A later snapshot engine implements the same use-case contract.

## Concurrency and isolation

- File parsing runs off the main actor and returns `Sendable` values.
- Network clients are actors or otherwise internally synchronized.
- SwiftData access is isolated behind a model actor/repository implementation.
- Use cases are `async` and cancellation-aware.
- Feature observable state is `@MainActor`.
- Never pass SwiftData model objects across actors or into UI read models.

Account replacement and import-audit write happen in one repository
transaction. A cancellation before commit changes nothing.

## Error model

Application errors are typed and recoverable:

- import file/account/row issues;
- unsupported format/security;
- ambiguous account identity;
- market-data unavailable/stale;
- persistence transaction failure;
- cancellation.

Presentation maps typed errors to concise user actions. Diagnostics retain
issue codes and row numbers but redact financial values.

## Evolution seams

- **Broker APIs:** another `BrokerageImporting`/snapshot adapter; file path
  remains available.
- **Observed history:** add snapshot records and a historical-series strategy;
  keep `GetHistoricalValue`.
- **Cloud sync:** replace/extend `PortfolioRepository`; resolve account identity
  before enabling.
- **New quote provider:** implement market-data ports and aliases.
- **iPad:** adapt feature layout/navigation, not domain or use cases.
- **CarPlay:** add the template feature target after entitlement validation.

## Architecture acceptance checks

- Every module maps to SPEC requirement IDs in its test plan.
- A build-time dependency graph contains no forbidden edge.
- Domain/PortfolioMath tests run without Apple UI or a database.
- Importing tests run with fabricated files and an in-memory repository.
- Features render from fake use cases.
- Removing Schwab/E*TRADE/Yahoo adapters does not break Domain or feature
  compilation.
