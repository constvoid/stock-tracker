# Import Design

**Status:** Approved (2026-10-10)  
**Normative source:** [SPEC.md](SPEC.md)  
**Primary requirements:** IMP-001 through IMP-009, ACCT-002 through ACCT-004

## Purpose

Importing converts one complete file per brokerage into normalized account
snapshots. Application and Domain never depend on a broker name, CSV layout,
filename, or the number of accounts in a file.

Schwab and E*TRADE are the initial adapters because samples exist for them.
They do not define the common contract.

## Boundary and flow

```text
Security-scoped file URLs
  → BrokerageFileParserRegistry
  → one matching BrokerageFileParser per file
  → BrokerageImportBatch (one brokerage, many accounts)
  → ImportPreview
  → account-level validation and user confirmation
  → ReplaceAccountSnapshot use case
  → PortfolioRepository
```

The app may select several files in one operation, but accepts at most one
current file for a given brokerage in that operation. Each selected file is
treated as a complete snapshot of that brokerage.

## Common contracts

Names are architectural, not final Swift signatures.

```text
BrokerageFileParser
  probe(filePrefix) → confidence + brokerage identity
  parse(file) → BrokerageImportBatch

BrokerageImportBatch
  brokerage: BrokerageIdentity
  coverage: completeBrokerage
  source: ImportSourceMetadata
  accounts: [ImportedAccountSnapshot]
  issues: [ImportIssue]

ImportedAccountSnapshot
  sourceAccountKey: SourceAccountKey
  displayName: String
  kindHint: String?
  currency: USD
  cash: Money
  slices: [ImportedPositionSlice]
  issues: [ImportIssue]

ImportedPositionSlice
  nativeSymbol: String
  canonicalSymbolCandidate: String
  securityName: String?
  securityKind: equity | etf
  quantity: Decimal
  importedUnitPrice: Decimal?
  importedUnitCost: Decimal
  acquiredAt: Date?
  basisKind: exactAcquisition | aggregatePosition
  sourceRow: Int

ImportSourceMetadata
  originalFilename: String
  providerTimestamp: Date?
  importedAt: Date
  contentFingerprint: SHA256
  parserIdentifier: String
  parserVersion: Int

ImportIssue
  code: stable machine-readable identifier
  severity: warning | error
  scope: file | account | row
  accountKey: SourceAccountKey?
  rowNumber: Int?
  redactedMessage: String
```

No raw CSV line is allowed beyond the parser boundary.

## Account identity

Persistence owns an internal `AccountID` UUID. Imports match an existing account
with a source key composed of:

1. normalized brokerage identity;
2. parser-derived stable account reference, normally the visible masked suffix;
3. an optional broker-provided account discriminator when available.

Display labels are not identities. If an account label changes while its source
key remains stable, update the label and preserve its internal ID, visibility,
and history.

If two sections produce the same source key, parsing reports an account-level
error and commits neither ambiguous section. The preview must allow a future
manual reconciliation flow; v1 never guesses.

## Position slices

`ImportedPositionSlice` is the common representation for both source qualities:

- `exactAcquisition`: acquisition date supplied by the brokerage row. Multiple
  rows for one symbol remain separate slices.
- `aggregatePosition`: current aggregate quantity/cost with no acquisition
  date. It is not relabeled as a tax lot.

Domain preserves `basisKind`, `acquiredAt`, and source provenance. Positions
are derived by aggregating slices for `(accountID, canonicalSymbol)`.

Cost basis for each slice is `quantity × importedUnitCost`. This is deliberate:
the import does not alter unit cost to force agreement with a broker's rounded
gain/cost display.

## Symbol handling

Three symbol concepts remain separate:

- **Native symbol:** text from the brokerage; used in audit/preview.
- **Canonical domain symbol:** normalized identity used to aggregate holdings.
- **Provider symbol:** alias required by the active quote provider.

Aliases are adapter data, not special cases in portfolio math. For example,
Schwab native `BRK/B` can normalize to canonical `BRK.B`, while a Yahoo-style
provider can request `BRK-B`.

An unknown symbol does not invalidate the holding. It imports with a
`marketDataUnavailable` warning and uses its imported price until a provider
mapping exists.

## Broker adapter: Schwab positions CSV

Observed sample shape:

- Preamble contains an as-of timestamp.
- Each account begins with a single-cell account label.
- The column header is repeated for every account section.
- Security rows are followed by `Cash & Cash Investments`.
- `Positions Total` closes each account section.
- Current sample contains three accounts, including one cash-only account.
- Security rows provide aggregate quantity and cost basis, not acquisition
  dates or individual tax lots.

Mapping:

- Account label → display name and parser-derived source account key.
- `Symbol` → native symbol.
- `Description` → security name.
- `Qty (Quantity)` → quantity.
- `Price` → imported unit price.
- `Cost Basis ÷ Qty` → imported unit cost.
- `Asset Type` → equity/ETF classification.
- `Cash & Cash Investments`.`Mkt Val` → account cash.
- Missing acquisition date → `basisKind = aggregatePosition`.

The parser verifies:

- holding market value approximately equals quantity × imported unit price;
- positions total equals security market values plus cash;
- gain approximately equals market value minus displayed cost basis.

Broker cost basis participates only in reconciliation and in deriving the unit
cost when no unit-cost column exists. The persisted slice still follows
SPEC IMP-006: quantity × derived unit cost.

`Cash & Cash Investments` and `Positions Total` are structural rows, never
positions. A section containing only cash is valid.

## Broker adapter: E*TRADE portfolio CSV

Observed sample shape:

- An account-summary section precedes positions.
- A view/filter metadata section separates summary from positions.
- The positions header starts with `Symbol` and ends with `Date Acquired`.
- `CASH` and `TOTAL` close the positions section.
- A generated-at timestamp follows the data.
- The current sample contains one account, but the adapter contract returns a
  collection and must not expose one-account assumptions outside the parser.

Mapping:

- Account summary `Account` → display name and source account key.
- `Symbol` → native/canonical candidate.
- `Qty #` → quantity.
- `Last Price $` → imported unit price.
- `Price Paid $` → imported unit cost.
- `Date Acquired` → acquisition date.
- Each security row → `basisKind = exactAcquisition`.
- `CASH`.`Value $` → account cash.

If a future E*TRADE file repeats account summary/position sections, the parser
emits one `ImportedAccountSnapshot` per section. The common import API does not
change.

The parser verifies account net value against positions plus cash. Differences
between `quantity × Price Paid` and E*TRADE's displayed total gain are warnings,
not errors, because the sample demonstrates rounded unit prices.

## Detection

The registry reads only a bounded prefix for probing, then selects the parser
with the highest confidence above a fixed threshold.

Examples of structural signatures:

- Schwab: positions preamble plus repeated `Qty (Quantity)`, `Mkt Val (Market
  Value)`, and `Asset Type` headers.
- E*TRADE: `Account Summary`, `View Summary`, and the positions header ending
  in `Date Acquired`.

Filename contributes no confidence. If no parser matches or two parsers tie
above the threshold, the file receives a file-level error and is not parsed.

## Validation severity

Warnings allow the affected account to commit. Examples:

- rounded gain/cost mismatch;
- unsupported quote symbol;
- unknown acquisition date;
- missing optional description;
- broker total differs within a documented rounding tolerance.

Errors block the affected account. Examples:

- missing/duplicate source account key;
- malformed quantity or unit cost;
- negative quantity in v1, because short positions are out of scope;
- unsupported security type with non-zero value;
- duplicate structural total/cash rows;
- total mismatch beyond tolerance;
- any unparseable holding row.

File-level errors block all accounts in that file. One file's failure does not
block valid accounts from another brokerage file.

## Preview and commit semantics

Preview groups results by brokerage and account and shows:

- detected brokerage/parser;
- source timestamp and freshness;
- account name, cash, position count, and calculated value;
- warnings/errors with row references;
- new, updated, unchanged, and stale accounts;
- whether each account will commit.

After explicit confirmation, commit proceeds account by account:

1. Resolve source key to internal `AccountID`.
2. Preserve user-owned metadata: enabled/hidden state and any display override.
3. In one storage transaction, replace that account's slices and cash.
4. Record import audit metadata and issues.
5. Leave prior data untouched if the transaction fails.

An account missing from the brokerage's new complete file is marked stale after
valid accounts commit. It remains stored and retains its visibility until the
user hides or deletes it.

## Imported prices

Imported unit prices form a quote fallback with source `brokerImport` and the
file's provider timestamp. They allow immediate values before market refresh.
Yahoo-style data supersedes them when newer and marks them stale when outside
the configured freshness window.

Imported prices never change quantity or cost basis.

## Privacy and audit

The importer accesses user-selected files with security-scoped URLs, reads them
for the duration of parsing, and releases access. It does not copy raw files
into app storage.

Persisted audit information is limited to source metadata, counts, issue codes,
redacted messages, and the content fingerprint. Logs must not include account
labels, balances, symbols with quantities, or raw rows.

Local development files under `data/import/` and screenshots under
`data/sampleui/` contain private financial information. They must be ignored
before any commit. Committed tests use fabricated broker/account names,
symbols, quantities, and values.

## Test strategy

Parser fixtures mirror structure, not real values:

- Schwab: multiple accounts, cash-only account, fractional quantity, ETF,
  slash symbol, missing account on re-import, and malformed row.
- E*TRADE: account summary plus positions, exact dates, rounded cost warning,
  repeated future account sections, cash, and total.
- Registry: correct detection, unknown file, ambiguous file.
- Commit: warning succeeds, row error preserves prior account, valid sibling
  account commits, stale account retained, hidden state preserved, re-import
  idempotent.
- Privacy: raw bytes are not persisted and diagnostics are redacted.

Every test name or test-plan entry should reference the relevant SPEC
requirement ID.
