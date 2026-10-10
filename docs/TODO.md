# Implementation TODO

**Current state:** Specification and design approved (2026-10-10). Phase 0
privacy/fixtures next; no app code until Phase 1.

This checklist is subordinate to `SPEC.md`. When a requirement changes, edit
the specification first and reconcile this file before implementation.

## Phase 0 — approval and privacy gate

- [x] Krishna approves the living specification and software/UI/import design.
- [x] Confirm unresolved items in [open-questions.md](open-questions.md) are
  either answered or explicitly non-blocking.
- [x] Add ignore rules for `.DS_Store`, `data/import/`, and `data/sampleui/`
  **before any commit**; verify real financial files are absent from git history
  (`IMP-009`, `QUAL-002`).
- [ ] Create fabricated Schwab/E*TRADE fixtures that preserve schema and edge
  cases but contain no real names, account suffixes, symbols, quantities, or
  values (`IMP-009`).
- [ ] Commit approved planning documents only if Krishna requests it.

**Exit:** approved design, sensitive local files ignored, and test fixtures are
safe to commit.

## Phase 1 — project and module scaffold

- [ ] Create `StockTracker.xcodeproj`, iOS 18+ app target, and local
  `StockTrackerKit` Swift package (`PROD-001`, `QUAL-001`).
- [ ] Add Domain, PortfolioMath, Application, Importing, Persistence,
  MarketData, DesignSystem, OverviewFeature, HoldingsFeature,
  AccountDetailFeature, ImportSettingsFeature, and CarGlanceFeature targets.
- [ ] Encode dependency rules from [architecture.md](architecture.md); add no
  CarPlay target yet.
- [ ] Build the empty app and run empty unit-test targets in CI/local Xcode.
- [ ] Create `AppDependencies` composition root with deterministic fake ports.

**Exit:** clean build/tests with enforceable module boundaries and no real data.

## Phase 2 — Domain and PortfolioMath

- [ ] Implement decimal value/identity types and validation (`PROD-003`,
  `DATA-002`).
- [ ] Implement Brokerage, BrokerageAccount, PositionSlice, provenance,
  visibility/stale state, and capability derivation (`ACCT-*`, `IMP-003`).
- [ ] Implement weighted average cost, cash/equity/account/portfolio rollups,
  and duplicate-symbol aggregation (`CALC-001` through `CALC-003`).
- [ ] Implement tax-term capability: one unknown date disables the account
  section (`CALC-004`).
- [ ] Unit-test fractional quantities, multiple slices, cash-only accounts,
  hidden accounts, and duplicate symbols with fabricated values.

**Exit:** pure Domain/PortfolioMath tests prove all core calculations without
SwiftData, files, network, or UI.

## Phase 3 — persistence and import

- [ ] Implement versioned SwiftData records and `PortfolioRepository`
  (`DATA-001`).
- [ ] Implement account-level transactional wipe/replace that preserves
  visibility/internal identity (`IMP-004`, `IMP-005`).
- [ ] Implement content-based parser registry and brokerage-agnostic batch
  contract: one complete file per brokerage, multiple accounts per file
  (`IMP-001`, `IMP-002`).
- [ ] Implement Schwab and E*TRADE parser adapters against anonymized fixtures.
- [ ] Implement native/canonical/provider symbol mapping, including fabricated
  slash-symbol coverage (`IMP-007`).
- [ ] Implement preview issues, reconciliation warnings, blocked-account
  errors, stale-account detection, and audit metadata (`IMP-005`, `IMP-006`).
- [ ] Verify raw files are discarded and diagnostics are redacted (`IMP-008`,
  `QUAL-002`).
- [ ] Test idempotent re-import, partial account success, malformed row
  preserving prior data, hidden-state preservation, cash-only accounts, and
  missing-account stale behavior.

**Exit:** fabricated versions of both brokerage formats import safely into a
temporary store and re-import without duplication/data loss.

## Phase 4 — local-data iPhone experience

- [ ] Implement three-tab shell: Overview, Holdings, Settings (`UI-001`).
- [ ] Implement Settings/Import file selection, preview, confirmation, result,
  account visibility, and stale resolution (`UI-005`).
- [ ] Implement Overview headline, Movers, and brokerage/account breakdown
  using imported fallback prices (`UI-002`, `UI-003`).
- [ ] Implement aggregated portfolio Holdings and Account Detail, including
  average cost and cash-only state (`UI-004`).
- [ ] Apply semantic design tokens, Dynamic Type, VoiceOver, dark mode, and
  non-color gain/loss indicators (`UI-007`).
- [ ] Add previews/UI tests backed only by fake read models.

**Exit:** user imports fabricated files and navigates correct totals, holdings,
accounts, visibility, and import issues without live network data.

## Phase 5 — live market data

- [ ] Implement provider symbol aliases and Yahoo-style `QuoteProviding`
  adapter (`MKT-001`).
- [ ] Implement imported/cached/provider quote precedence and freshness.
- [ ] Add previous-close daily change and pull-to-refresh.
- [ ] Cache quotes; prove network failure never alters holdings (`MKT-002`).
- [ ] Surface stale/partial/as-of states in Overview, Holdings, and Account
  Detail.

**Exit:** fresh quotes update all read models; offline/error states preserve and
clearly qualify the latest known values.

## Phase 6 — reconstructed history

- [ ] Implement five-minute intraday and daily history adapters (`HIST-001`).
- [ ] Implement D/W/M/YTD/1Y/3Y/5Y range mapping and cache policy.
- [ ] Implement reconstructed series using acquisition dates, estimated
  full-range unknown-date slices, and flat cash (`HIST-002`, `HIST-003`).
- [ ] Implement Overview and Account charts with scrub accessibility and
  reconstructed/estimated disclosure.
- [ ] Decide and add to `SPEC.md`: missing historical bar carry-forward versus
  chart gap.

**Exit:** all ranges render deterministic series and visibly distinguish
estimated history.

## Phase 7 — iPhone car glance

- [ ] Implement large-type car-glance surface from shared overview use case
  (`CAR-001`).
- [ ] Limit content to total, today's change, freshness, and a few accounts.
- [ ] Validate low-interaction layout; no chart/import/settings.

**Exit:** glance works independently of CarPlay entitlement.

## Phase 8 — observed history

- [ ] Add versioned valuation snapshot persistence and recording strategy
  (`HIST-004`).
- [ ] Make `GetHistoricalValue` prefer observed coverage and fall back to
  reconstructed series without changing feature APIs.
- [ ] Test mixed observed/reconstructed coverage and migration.

## Phase 9 — CarPlay feasibility and adapter

- [ ] Re-check Apple's current categories/entitlement rules before coding.
- [ ] If feasible for intended distribution, add CarPlayFeature with
  list/information templates only (`CAR-002`).
- [ ] Test Summary → Accounts → Account positions in CarPlay Simulator.
- [ ] Do not misdeclare an app category or block iPhone delivery.

## Deferred until `SPEC.md` changes

- Direct brokerage APIs (must preserve file import).
- Merge-on-import policy.
- Dedicated iPad layout.
- Siri, widgets, Live Activities.
- Dividends, realized gains, transaction ledger.
- Options, crypto, bonds, margin, multi-currency.
- iCloud/CloudKit.
- Trading/order entry.

## Definition of done for every phase

- Requirement IDs are referenced in tests or acceptance notes.
- Design docs and this checklist match the implemented behavior.
- No forbidden module dependency is introduced.
- Financial calculations use Decimal and deterministic tests.
- Logs/fixtures contain no private portfolio data.
- Build, tests, and relevant accessibility checks pass.
