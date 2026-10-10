# Stock Tracker — Living Specification

**Version:** 0.2.1-draft  
**Last reconciled:** 2026-10-10  
**Owner:** Krishna  
**Status:** Approved for implementation (2026-10-10)

This is the normative product specification for Stock Tracker. Architecture,
tasks, code, and tests must conform to this file. If another document conflicts
with this one, this file wins.

## How to change this specification

1. Edit the requirement here first, retaining its stable requirement ID.
2. Change its state to `Proposed` until Krishna accepts it.
3. Add a short entry to the change log.
4. Reconcile affected artifacts:
   - `architecture.md` and `domain-and-data.md`
   - `import-design.md`, `ui-design.md`, or `carplay.md`
   - `TODO.md`
   - implementation and tests, once they exist
5. Record the reconciliation under the requirement's **Traces** line.
6. Do not mark the change `Confirmed` until design, tasks, code, and tests no
   longer contradict it.

Requirement states:

- `Confirmed` — explicitly chosen by Krishna; binding unless changed here.
- `Proposed` — design recommendation awaiting review.
- `Deferred` — intentionally outside the current delivery scope.
- `Superseded` — retained for history and points to its replacement.

When deleting behavior, mark its requirement `Superseded` rather than silently
removing the ID. New requirements receive the next ID in their section.

## Product and scope

### PROD-001 — Platforms

**State:** Confirmed  
**Requirement:** The app is iPhone-first and targets iOS 18 or newer. The same
SwiftUI presentation may adapt to iPad later without creating a separate
product architecture.

**Acceptance:** The deployment target is iOS 18+ and v1 has no iPad-only target.

**Traces:** `architecture.md`; `TODO.md`

### PROD-002 — Read-only portfolio tracker

**State:** Confirmed  
**Requirement:** The product tracks brokerage accounts, positions, cash,
portfolio value, gains/losses, and historical value. It does not place trades
or submit orders.

**Acceptance:** No order-entry or trade-execution use case exists.

**Traces:** `architecture.md`; `ui-design.md`

### PROD-003 — v1 instruments and currency

**State:** Confirmed  
**Requirement:** v1 supports US stocks, ETFs, fractional quantities, and USD
cash balances. Cash is an account balance, not a synthetic ticker.

**Acceptance:** Imported stock/ETF positions and cash contribute to account and
portfolio totals without requesting a market quote for cash.

**Traces:** `domain-and-data.md`; `import-design.md`

### PROD-004 — Income and realized activity

**State:** Confirmed  
**Requirement:** v1 ignores dividends, corporate actions, realized gains, and
transaction-ledger behavior. No unused domain types are created for them.

**Acceptance:** These concepts are absent from v1 domain and UI.

**Traces:** `domain-and-data.md`; `TODO.md`

## Accounts and holdings

### ACCT-001 — Brokerage/account hierarchy

**State:** Confirmed  
**Requirement:** Accounts belong to a brokerage. Portfolio views can show all
enabled accounts; account detail shows only that account.

**Acceptance:** The UI can expand brokerage to account and navigate to account
detail.

**Traces:** `ui-design.md`; `domain-and-data.md`

### ACCT-002 — Import all, control visibility

**State:** Confirmed  
**Requirement:** Every valid discovered account is stored. Each account has an
enabled/hidden setting; only enabled accounts contribute to portfolio totals,
charts, Movers, and portfolio-wide Holdings.

**Acceptance:** Hiding an account changes portfolio rollups without deleting its
data, and re-import preserves the visibility setting.

**Traces:** `domain-and-data.md`; `import-design.md`; `ui-design.md`

### ACCT-003 — Cash-only accounts

**State:** Proposed  
**Requirement:** A cash-only account is valid and appears in account lists and
totals even when it has no security positions.

**Acceptance:** The supplied Schwab cash-only account imports without a dummy
position or validation error.

**Traces:** `import-design.md`; parser fixture tests

### ACCT-004 — Missing account from complete export

**State:** Confirmed  
**Requirement:** If an account previously imported from a complete brokerage
file is missing from that brokerage's next file, retain it, mark it stale, and
prompt the user to hide or delete it. Do not delete it automatically.

**Acceptance:** Import preview reports the missing account and stored holdings
remain unchanged until user action.

**Traces:** `import-design.md`; `ui-design.md`

## Importing

### IMP-001 — Replaceable source boundary

**State:** Confirmed  
**Requirement:** File ingestion is isolated behind a source protocol so direct
brokerage integrations can replace or coexist with files without changing
domain, calculation, or presentation code.

**Acceptance:** Application use cases consume normalized snapshots, never CSV
rows or broker-specific DTOs.

**Traces:** `architecture.md`; `import-design.md`

### IMP-002 — Brokerage-file contract

**State:** Confirmed  
**Requirement:** The application-level import contract is brokerage-agnostic.
One source file represents one complete brokerage snapshot and yields one or
more account snapshots. An import may select one file for each brokerage.
Broker-specific parsers recognize file content and adapt their formats to this
common contract.

Initial parser adapters recognize:

- Schwab all-accounts positions CSV containing repeated account sections.
- E*TRADE portfolio CSV, treated as a brokerage file capable of yielding
  multiple accounts even though the current sample contains one account.

**Acceptance:** Parser detection is based on file content, not filename alone.
Every parser returns a collection of accounts and no Application or Domain API
assumes a broker, filename convention, or one-account file. The current samples
produce three Schwab accounts and one E*TRADE account without changing that
contract.

**Traces:** `import-design.md`; anonymized parser fixtures

### IMP-003 — Hybrid position slices

**State:** Confirmed  
**Requirement:** Normalized holdings support both:

- exact acquisition slices with an acquisition date, as provided by E*TRADE;
- aggregate position slices with unknown acquisition date, as provided by the
  current Schwab export.

Each slice retains source provenance. Unknown dates are not invented.

**Acceptance:** Both current formats normalize without treating a Schwab
aggregate as a known tax lot.

**Traces:** `domain-and-data.md`; `import-design.md`

### IMP-004 — Re-import replacement

**State:** Confirmed  
**Requirement:** A successful re-import wipes and replaces holdings and cash for
each account present in the import. Accounts outside that import remain
unchanged, subject to stale detection for complete exports.

**Acceptance:** Re-import is idempotent and cannot duplicate position slices.

**Traces:** `import-design.md`; `TODO.md`; import integration tests

### IMP-005 — Account-level commit boundary

**State:** Confirmed  
**Requirement:** Valid accounts may commit independently across a batch of
brokerage files. Warnings do not block an account. Any malformed holding row is
an error that blocks replacement of that entire account; other valid accounts
from the same or another brokerage file may still commit. Invalid rows are
never silently skipped into a replacement snapshot.

**Acceptance:** A row error leaves the prior stored version of that account
unchanged and appears in the import result.

**Traces:** `import-design.md`; import safety tests

### IMP-006 — Cost calculation and reconciliation

**State:** Confirmed  
**Requirement:** Imported cost basis is recomputed as quantity multiplied by
the broker's imported unit cost/price-paid value. Small differences from
broker-reported aggregate gain or cost are accepted and surfaced as warnings;
the app does not silently adjust unit cost to force reconciliation.

**Acceptance:** E*TRADE rounding discrepancies create warnings but do not block
import.

**Traces:** `import-design.md`; `domain-and-data.md`

### IMP-007 — Source symbols and quote symbols

**State:** Proposed  
**Requirement:** Preserve the broker-native symbol and resolve a separate
canonical market-data symbol. Broker-specific aliases, such as Schwab `BRK/B`
to Yahoo-style `BRK-B`, live in MarketData/Importing adapters rather than the
core domain identifier.

**Acceptance:** Display can retain the familiar native symbol while quotes use
the provider-compatible symbol.

**Traces:** `import-design.md`; `architecture.md`

### IMP-008 — Raw-file privacy

**State:** Confirmed  
**Requirement:** Parse security-scoped files and discard raw contents after
import. Persist only normalized portfolio data and minimal audit metadata:
provider, source timestamp, import timestamp, content fingerprint, counts, and
issue summary.

**Acceptance:** No brokerage CSV copy remains in the app sandbox after import.

**Traces:** `import-design.md`; privacy tests

### IMP-009 — Sensitive development samples

**State:** Proposed  
**Requirement:** Real files under `data/import/` and screenshots under
`data/sampleui/` are local reference material and must not be committed or
copied into logs/tests. Tests use anonymized synthetic fixtures preserving only
schema and edge cases.

**Acceptance:** Ignore rules are in place before the first project commit, and
repository history contains no real account values.

**Traces:** `TODO.md`; repository ignore rules after approval

## Portfolio calculations

### CALC-001 — Position average cost

**State:** Confirmed  
**Requirement:** Position average cost is quantity-weighted across its slices:
sum of quantity multiplied by unit cost, divided by total quantity.

**Acceptance:** Position rows show average cost and calculation tests cover
fractional quantities and multiple slices.

**Traces:** `domain-and-data.md`; PortfolioMath tests

### CALC-002 — Portfolio rollup

**State:** Confirmed  
**Requirement:** Portfolio value equals market value of positions plus cash for
enabled accounts. Account value uses the same rule.

**Acceptance:** Cash-only and mixed accounts reconcile independently and in the
portfolio total.

**Traces:** `domain-and-data.md`; PortfolioMath tests

### CALC-003 — Duplicate symbols

**State:** Confirmed  
**Requirement:** Portfolio-wide Holdings and Movers aggregate the same canonical
symbol across enabled accounts. Account detail keeps positions scoped to the
selected account.

**Acceptance:** A symbol held in two accounts has one portfolio row and
account-specific detail remains available.

**Traces:** `ui-design.md`; PortfolioMath tests

### CALC-004 — Tax-term capability

**State:** Confirmed  
**Requirement:** If any position in an account lacks acquisition dates, hide
long/short-term reporting for that account. Do not estimate or partially report
tax term.

**Acceptance:** Current Schwab accounts show no tax-term section; a fully dated
E*TRADE account may show it.

**Traces:** `domain-and-data.md`; `ui-design.md`

## Market data and history

### MKT-001 — Replaceable market data

**State:** Confirmed  
**Requirement:** Quotes, intraday bars, and daily history are protocols.
Initial implementation uses a free Yahoo-style provider and may be replaced
without changing use cases or UI. Quote prices may use extended-hours
(pre/post) when the provider supplies them; previous close remains the prior
regular-session close for day's change.

**Acceptance:** Tests run with deterministic fake providers. Extended-hours
last price is preferred over the regular print when both are present.

**Traces:** `architecture.md`; `domain-and-data.md`

### MKT-002 — Quote failure

**State:** Confirmed  
**Requirement:** Quote/network failure never deletes holdings. The app displays
the most recent cached/imported price with source and as-of metadata and marks
it stale.

**Acceptance:** Offline launch renders stored accounts and clearly stale values.

**Traces:** `domain-and-data.md`; `ui-design.md`

### MKT-003 — Quote refresh policy

**State:** Confirmed  
**Requirement:** v1 refreshes quotes on pull-to-refresh and when the app
becomes active in the foreground. No opportunistic or scheduled background
refresh is required.

**Acceptance:** Pull-to-refresh and foreground activation request provider
quotes; holdings remain intact if the request fails.

**Traces:** `ui-design.md`; `TODO.md`

### MKT-004 — Quote precedence

**State:** Confirmed  
**Requirement:** Prefer a newer market-provider quote over cached provider
quotes, then imported broker fallback prices. Imported unit prices never alter
quantity or cost basis.

**Acceptance:** After a successful refresh, Overview/Holdings/Account Detail
show provider prices; after failure they show the prior cached/imported values
as stale.

**Traces:** `import-design.md`; `domain-and-data.md`

### HIST-001 — Supported ranges

**State:** Confirmed  
**Requirement:** Portfolio and account history supports Day, Week, Month, YTD,
1 Year, 3 Years, and 5 Years. Day uses intraday bars (default five-minute
interval); longer ranges use daily closes.

**Acceptance:** The same range type drives both portfolio and account charts.

**Traces:** `domain-and-data.md`; `ui-design.md`

### HIST-002 — Reconstructed history

**State:** Confirmed  
**Requirement:** v1 reconstructs value from current position quantities and
historical prices plus flat current cash. It does not pretend to know sells,
past cash flows, or quantity changes absent from source data.

**Acceptance:** The chart discloses reconstructed/estimated status.

**Traces:** `domain-and-data.md`; `ui-design.md`

### HIST-003 — Unknown acquisition dates

**State:** Confirmed  
**Requirement:** For aggregate positions with unknown acquisition dates, assume
today's quantity existed throughout the selected range and label affected
charts `Estimated`.

**Acceptance:** Schwab history can render all configured ranges with the
estimate disclosure.

**Traces:** `domain-and-data.md`; PortfolioMath tests

### HIST-005 — Missing historical bars

**State:** Confirmed  
**Requirement:** When reconstructing series, carry the last known close across
calendar gaps that are not expected trading sessions (weekends and US market
holidays). When an expected trading session has no provider bar, leave a chart
gap (do not invent a price).

**Acceptance:** Weekend gaps are continuous; a missing weekday bar produces a
discontinuity in the series points.

**Traces:** `domain-and-data.md`; `open-questions.md`; PortfolioMath tests

### HIST-004 — Snapshot evolution

**State:** Confirmed  
**Requirement:** A later module stores daily/on-refresh valuations. The
historical-value use-case API remains stable so UI can prefer observed snapshots
without redesign.

**Acceptance:** Snapshot persistence is deferred and no placeholder domain
entities are added in v1.

**Traces:** `architecture.md`; `TODO.md`

## iPhone experience

### UI-001 — Navigation

**State:** Confirmed  
**Requirement:** Use three tabs: Overview, Holdings, and Settings/Import.
Overview and Holdings can navigate to Account Detail.

**Acceptance:** No core screen requires a browser-style footer or nested menu.

**Traces:** `ui-design.md`

### UI-002 — Overview

**State:** Confirmed  
**Requirement:** Overview includes total portfolio value, today's gain/loss,
historical chart and range selector, Movers, and expandable brokerage/account
breakdown.

**Acceptance:** Hidden accounts are excluded and stale/estimated states are
visible.

**Traces:** `ui-design.md`

### UI-003 — Movers

**State:** Confirmed  
**Requirement:** Movers shows portfolio-wide gainers and losers aggregated by
canonical symbol, with a dollar/percentage toggle and accessible positive and
negative indicators.

**Acceptance:** Meaning is not conveyed by green/red color alone.

**Traces:** `ui-design.md`; PortfolioMath tests

### UI-004 — Holdings

**State:** Confirmed  
**Requirement:** Holdings shows portfolio-wide aggregated symbols and supports
broker/account context. Account Detail shows positions, cash, total value,
current price/change, quantity, and average cost.

**Acceptance:** Duplicate symbols aggregate only at portfolio scope.

**Traces:** `ui-design.md`

### UI-005 — Import and account settings

**State:** Confirmed  
**Requirement:** Settings/Import supports selecting one complete file per
brokerage, parser detection, account-by-account preview, warnings/errors,
commit results, visibility toggles, and stale-account resolution.

**Acceptance:** No data is replaced before preview and explicit confirmation.

**Traces:** `ui-design.md`; `import-design.md`

### UI-006 — Explicit v1 exclusions

**State:** Confirmed  
**Requirement:** v1 does not include market index panels, automated guidance,
custom holdings views, or SigFig's Add Portfolio flow. The screenshots guide
information hierarchy, not branding or pixel-for-pixel copying.

**Acceptance:** These features are absent from v1 tasks.

**Traces:** `ui-design.md`; `TODO.md`

### UI-007 — Native and accessible design

**State:** Proposed  
**Requirement:** Use native SwiftUI navigation and charts, semantic colors,
Dynamic Type, VoiceOver labels, sufficient contrast, and light/dark appearance.
Positive/negative state must include text or icons in addition to color.

**Acceptance:** Core screens pass accessibility inspection at large Dynamic
Type sizes and in both appearances.

**Traces:** `ui-design.md`; UI acceptance tests

## Car experience

### CAR-001 — iPhone car glance

**State:** Confirmed  
**Requirement:** Deliver a large-type, low-interaction iPhone car-glance
surface before true CarPlay. It shows total, today's change, and a small account
summary; no charts or import.

**Acceptance:** It reuses read-only portfolio use cases.

**Traces:** `carplay.md`; `TODO.md`

### CAR-002 — CarPlay later

**State:** Confirmed  
**Requirement:** True CarPlay is a later, read-only template adapter using list
and information templates. It depends on entitlement feasibility and does not
block the iPhone product.

**Acceptance:** Domain and Application contain no CarPlay framework dependency.

**Traces:** `architecture.md`; `carplay.md`

## Persistence, privacy, and quality

### DATA-001 — Local-only storage

**State:** Confirmed  
**Requirement:** v1 stores normalized data locally with SwiftData behind a
storage protocol. No CloudKit/iCloud sync is included.

**Acceptance:** Presentation and use cases do not import SwiftData.

**Traces:** `architecture.md`; `domain-and-data.md`

### DATA-002 — Precision

**State:** Proposed  
**Requirement:** Quantities and money calculations use decimal arithmetic;
binary floating point is not used for persisted financial values.

**Acceptance:** Fractional-share and rounding tests are deterministic.

**Traces:** `domain-and-data.md`; Domain tests

### QUAL-001 — Module boundaries

**State:** Proposed  
**Requirement:** Domain is pure Swift. Importing, MarketData, Persistence,
Application/PortfolioMath, iPhone UI, car glance, and later CarPlay communicate
through explicit protocols/read models. The app target is the composition root.

**Acceptance:** UI imports no CSV parser/network client and Domain imports no
SwiftUI, SwiftData, or CarPlay.

**Traces:** `architecture.md`; dependency tests/build graph

### QUAL-002 — Logging

**State:** Proposed  
**Requirement:** Production logs and analytics never include account labels,
symbols with quantities, balances, raw CSV rows, or file contents.

**Acceptance:** Import diagnostics use issue codes and row numbers, with
redacted values where needed.

**Traces:** `import-design.md`; privacy review

## Deferred capabilities

- **DEF-001 — Direct brokerage APIs:** Deferred; implement as another snapshot
  provider while retaining file import.
- **DEF-002 — Import merge policy:** Deferred; v1 remains wipe/replace by
  account.
- **DEF-003 — iPad-specific layout:** Deferred; shared adaptive UI may work
  before dedicated design.
- **DEF-004 — Siri, widgets, and Live Activities:** Deferred.
- **DEF-005 — Dividends, realized gains, options, crypto, bonds, margin, and
  multi-currency:** Deferred.
- **DEF-006 — Observed valuation snapshots:** Deferred until after reconstructed
  history.

## Open decisions

These are not requirements until resolved:

- Personal/family distribution versus eventual public App Store distribution.
- Face ID gate.
- Regular-session-only versus extended-hours quotes.
- Refresh cadence beyond foreground/manual refresh.
- Missing historical bar policy (carry last close versus chart gap).
- Whether file import remains visible after direct broker integrations
  (recommended: yes).

## Reconciliation register

At each specification change, update this section:

- **Specification:** requirement IDs changed and state updated.
- **Design:** architecture/import/domain/UI/CarPlay docs reconciled.
- **Plan:** `TODO.md` tasks and acceptance criteria reconciled.
- **Code:** affected modules and migrations reconciled, once code exists.
- **Tests:** requirement IDs referenced by relevant test names or test-plan
  sections.

Current reconciliation:

- `0.2.1-draft` — makes the normalized import contract brokerage-agnostic:
  one complete file per brokerage, each yielding multiple accounts.
- `0.2.0-draft` — incorporates the supplied Schwab/E*TRADE samples, six SigFig
  reference screens, and all planning choices made through 2026-10-10.
- Architecture, import, domain/data, iPhone UI, CarPlay, handoff, open
  questions, and implementation TODO are reconciled to this draft.
- The companion architecture canvas is explanatory; this document remains
  normative.
- Code/tests do not exist yet.

## Change log

### 0.2.1-draft — 2026-10-10

- Replaced broker-shaped file assumptions with one common contract: one
  complete file per brokerage and multiple accounts per file.
- Retained Schwab and E*TRADE only as initial parser adapters.

### 0.2.0-draft — 2026-10-10

- Added real broker-format requirements and hybrid exact/aggregate position
  handling.
- Added account visibility, stale-account, account-level commit, and raw-file
  disposal requirements.
- Added screenshot-derived Overview, Movers, Holdings, and Import/Settings
  requirements.
- Established stable requirement IDs and the reconciliation workflow.

### 0.1.0-draft — 2026-10-09

- Recorded initial iPhone, history, import-boundary, local-storage, and
  CarPlay direction.
