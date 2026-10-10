# Domain and Data Design

**Status:** Approved (2026-10-10)  
**Normative source:** [SPEC.md](SPEC.md)  
**Import mapping:** [import-design.md](import-design.md)

## Modeling principles

- Persist source facts; derive positions, totals, tax capability, and chart
  series.
- Use `Decimal`-backed values for quantities and money.
- Preserve uncertainty instead of inventing dates or tax classifications.
- Keep broker-native identifiers separate from canonical market identity.
- Keep user-owned settings when broker snapshots replace source-owned data.
- Do not add placeholder types for deferred capabilities.

## Identity and value types

```text
BrokerageID
  stable app identifier for a brokerage namespace

AccountID
  internal UUID, never derived directly from a display label

SourceAccountKey
  brokerageID + normalized external account reference

NativeSymbol
  source spelling, for example BRK/B

CanonicalSymbol
  portfolio identity, for example BRK.B

ProviderSymbol
  quote-provider alias, for example BRK-B

Money
  amount: Decimal
  currency: USD in v1

Quantity
  shares: Decimal

UnitCost
  amountPerShare: Decimal
  currency: USD
```

Initializers reject non-finite values, unsupported currency, and invalid scale.
Formatting is presentation behavior and not stored in these values.

## Brokerage and account

```text
Brokerage
  id: BrokerageID
  displayName: String
  lastCompleteImportAt: Date?

BrokerageAccount
  id: AccountID
  brokerageID: BrokerageID
  sourceKey: SourceAccountKey
  sourceDisplayName: String
  displayNameOverride: String?
  kindHint: String?
  cash: Money
  isEnabled: Bool
  freshness: current | stale(missingSince)
  sourceAsOf: Date?
  lastImportedAt: Date
  slices: [PositionSlice]
```

Source-owned fields are replaced by import. User-owned fields
(`isEnabled`, display override) survive re-import.

Hidden accounts remain queryable from Settings and can be re-enabled. They do
not contribute to portfolio-wide read models.

## Position slices and positions

```text
PositionSlice
  id: PositionSliceID
  accountID: AccountID
  nativeSymbol: NativeSymbol
  canonicalSymbol: CanonicalSymbol
  securityName: String?
  securityKind: equity | etf
  quantity: Quantity
  unitCost: UnitCost
  acquiredAt: Date?
  basisKind: exactAcquisition | aggregatePosition
  provenance: ImportProvenance

Position (derived)
  accountID: AccountID
  canonicalSymbol: CanonicalSymbol
  displaySymbol: NativeSymbol
  slices: [PositionSlice]
  quantity: Quantity
  averageCost: Money
  costBasis: Money
  currentPrice: Money?
  marketValue: Money?
  unrealizedGain: Money?
  dayChange: Money?
  quoteFreshness: QuoteFreshness
```

`PositionSlice` replaces the earlier assumption that every source row is a
known tax lot. An exact E*TRADE acquisition row and an aggregate Schwab
position can coexist in the same model without claiming equal precision.

Derived formulas:

```text
costBasis(slice) = quantity × unitCost
positionQuantity = Σ slice.quantity
positionCostBasis = Σ costBasis(slice)
weightedAverageCost = positionCostBasis ÷ positionQuantity
marketValue = positionQuantity × currentPrice
unrealizedGain = marketValue − positionCostBasis
```

A portfolio-wide holding aggregates account positions sharing
`CanonicalSymbol` across enabled accounts. It retains account allocations for
drill-down.

## Capabilities and quality

Capability is derived rather than stored as manually maintained flags:

```text
AccountCapabilities
  taxTerm: available | unavailableMissingAcquisitionDates
  history: reconstructed | estimatedUnknownAcquisitionDates
  livePricing: available | partialMissingSymbols
```

Tax-term reporting is available only when every non-cash position slice in the
account has an acquisition date. If one is unknown, the entire account tax-term
section is hidden.

Portfolio chart quality is the least precise quality among enabled accounts:

- `reconstructed` when all slices have acquisition dates;
- `estimated` when any enabled slice has an unknown acquisition date.

The read model carries quality and disclosure text; the chart view does not
infer it.

## Quotes and bars

```text
Quote
  canonicalSymbol: CanonicalSymbol
  price: Money
  previousClose: Money?
  asOf: Date
  source: brokerImport | marketProvider
  freshness: fresh | stale

PriceBar
  canonicalSymbol: CanonicalSymbol
  timestamp: Date
  close: Money
  interval: fiveMinute | daily
  source: marketProvider
```

An imported unit price is a valid initial fallback quote. A newer market quote
supersedes it. Quote absence never removes a position; value fields become
unavailable or retain a clearly stale cached quote according to the use case.

## Portfolio read models

Application returns presentation-ready but UI-independent values:

```text
PortfolioOverview
  totalValue
  todayChangeAmount
  todayChangePercent
  chart: HistoricalSeries
  movers: Movers
  brokerages: [BrokerageBreakdown]
  asOf
  freshness

PortfolioHoldingRow
  canonical/display symbol
  quantity across enabled accounts
  current price
  market value
  day change
  average cost
  account allocations

AccountDetail
  account identity and visibility
  total/equity/cash values
  positions
  capabilities
  chart

HistoricalSeries
  range
  points: [ValuationPoint]
  quality: reconstructed | estimated
  disclosure
  asOf
```

## Historical valuation

Configured ranges:

- Day: five-minute intraday bars;
- Week, Month, YTD, 1 Year, 3 Years, 5 Years: daily closes.

For timestamp `t`:

```text
value(t) =
  Σ valueOfSlice(slice, priceAt(t))
  + currentCash

valueOfSlice =
  0                                      when acquiredAt exists and t is earlier
  quantity × priceAt(t)                  otherwise
```

Unknown acquisition dates are assumed held for the full selected range and
make the series `estimated`. Current cash is flat across v1 history. The app
does not infer past sells, transfers, dividends, or cash flows.

Missing bars use the final policy selected before chart implementation; until
then the history engine exposes missing data rather than embedding a UI rule.

Later observed snapshots:

- add `ValuationSnapshotRecord`;
- introduce a series strategy that prefers observed coverage;
- preserve `GetHistoricalValue(scope, range)` and `HistoricalSeries`.

No snapshot Domain type is required before that phase.

## Application ports

```text
BrokerageImporting
  inspect(files) async throws → [BrokerageImportBatch]

PortfolioRepository
  portfolioSnapshot() async throws → PortfolioSnapshot
  account(id) async throws → AccountSnapshot?
  replaceAccount(snapshot, audit) async throws
  markMissingAccountsStale(brokerageID, presentKeys, asOf) async throws
  setAccountEnabled(id, enabled) async throws
  deleteStaleAccount(id) async throws
  cachedQuotes(symbols) async throws → [CanonicalSymbol: Quote]
  saveQuotes(quotes) async throws
  cachedBars(request) async throws → [PriceBar]
  saveBars(bars) async throws

QuoteProviding
  quotes(symbols) async throws → [CanonicalSymbol: Quote]

IntradayPriceProviding
  bars(symbols, day) async throws → [CanonicalSymbol: [PriceBar]]

HistoricalPriceProviding
  dailyBars(symbols, range) async throws → [CanonicalSymbol: [PriceBar]]
```

The protocol names describe capabilities rather than concrete storage or
provider products.

## Persistence schema

SwiftData records are adapter-owned:

```text
BrokerageRecord
  id, normalizedName, displayName, lastCompleteImportAt

AccountRecord
  id, brokerage relation, source key, source label, display override,
  kind hint, cash amount/currency, enabled, staleSince, sourceAsOf,
  lastImportedAt

PositionSliceRecord
  id, account relation, native/canonical symbol, name, kind, quantity,
  unit cost/currency, acquiredAt, basis kind, import audit relation

QuoteRecord
  canonical/provider symbol, price, previous close, source, asOf

PriceBarRecord
  canonical/provider symbol, timestamp, interval, close, asOf

ImportAuditRecord
  brokerage, original filename, timestamps, fingerprint, parser/version,
  account/position counts, warning/error counts
```

Do not persist derived `Position`, Movers, totals, chart points, or tax-term
capability. Recompute them from records and current/cached prices.

Account replacement deletes/replaces only source-owned slices and cash in one
transaction. It preserves the account record's internal ID and user settings.

Use a versioned SwiftData schema from the first release. Migration tests use
temporary stores and fabricated values.

## Data retention and protection

- Local-only in v1; no CloudKit.
- Raw import files are not copied into storage.
- Financial values use the strongest practical app data protection.
- Import audits are metadata-only and redacted.
- Cached quotes/bars may be evicted and re-fetched; accounts/slices may not.
- Production diagnostics never contain balances or holdings with quantities.

## Deferred domain concepts

Do not add these until a confirmed SPEC requirement needs them:

- dividend/corporate-action events;
- realized gains and transaction ledger;
- options, crypto, bonds, margin, multiple currencies;
- lot disposal/FIFO;
- observed valuation snapshots;
- cloud conflict/version entities.

## Domain acceptance checks

- Decimal math reproduces fabricated expected totals and fractional shares.
- Aggregate slices never expose a fake acquisition date.
- One missing date disables tax-term reporting for its account.
- Hidden accounts are excluded from all portfolio rollups.
- Duplicate symbols aggregate at portfolio scope but remain separate by account.
- Re-import preserves visibility/internal IDs and replaces source facts.
- History quality changes to estimated when an unknown-date slice participates.
