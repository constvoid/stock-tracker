# iPhone UI Design

**Status:** Approved (2026-10-10)  
**Normative source:** [SPEC.md](SPEC.md)  
**Reference images:** Local files under `data/sampleui/`  
**Primary requirements:** UI-001 through UI-007, ACCT-001 through ACCT-004

## Intent

The supplied SigFig screens guide information hierarchy:

- headline portfolio value and today's change;
- performance chart with time controls;
- gainers/losers;
- expandable brokerage/account breakdown;
- dense but scannable holdings grouped by account.

They are not a branding or pixel-copy target. Stock Tracker uses native SwiftUI,
current iOS navigation, accessible semantic colors, and its own visual tokens.

## Navigation model

The root is a three-tab `TabView`:

1. **Overview**
2. **Holdings**
3. **Settings**

Overview and Holdings share a navigation destination for Account Detail.
Settings contains Import, account visibility, stale-account resolution, and
data freshness. Import is not a fourth tab.

Logical hierarchy:

```text
Overview
  ├── Performance detail (optional full-screen chart later)
  ├── Portfolio holding detail (later)
  └── Brokerage → Account Detail

Holdings
  ├── Portfolio holding detail (later)
  └── Account Detail

Settings
  ├── Import Files → Import Preview → Import Result
  ├── Account Visibility
  └── Stale Account Resolution
```

## Shared presentation rules

### Money and change

- Use locale-aware USD formatting.
- Headline totals include cents only when useful; account/position values may
  use two decimals.
- Positive change uses an upward indicator plus text; negative uses downward;
  neutral uses a dash. Color is supplementary.
- Percentage and amount always state their period, usually "Today."
- Stale/imported prices display an as-of label; they are never presented as
  live without qualification.

### Loading and refresh

- Render cached/local portfolio data immediately.
- Pull-to-refresh requests current quotes and refreshes all visible read models.
- Keep prior values onscreen during refresh with a compact progress state.
- A quote failure produces a non-blocking freshness banner, not an empty
  portfolio.
- Import and persistence errors use explicit retry/review actions.

### Accessibility

- Support Dynamic Type without clipping financial values.
- VoiceOver reads amount, sign, percentage, period, and freshness in one useful
  phrase.
- Green/red never carries meaning alone.
- Chart exposes a textual summary and accessible values for selected points.
- Expand/collapse controls state brokerage/account name and current state.
- Minimum touch targets follow iOS guidance.

### Appearance

Use semantic system backgrounds and labels, with a restrained portfolio accent.
Gain/loss colors adapt to light/dark mode and contrast settings. Avoid copying
SigFig logos, web chrome, tiny footer links, or desktop-style tables.

## Overview tab

The Overview is a vertical scroll with four sections.

### Portfolio header

Content:

- "Portfolio Value" label;
- current value across enabled accounts;
- today's amount and percentage change;
- latest market-data timestamp/freshness;
- estimated/stale disclosure when applicable.

The header remains compact enough that the chart begins above the fold on a
standard iPhone.

### Performance

Content:

- line/area chart for all enabled accounts;
- selected range summary: start/end values and absolute/percentage change;
- range control: Day, Week, Month, YTD, 1Y, 3Y, 5Y;
- chart quality label:
  - `Reconstructed` when dates are known;
  - `Estimated` when any enabled position has unknown acquisition date.

Day uses five-minute bars. Other ranges use daily closes. Current cash is flat
in v1 and the chart disclosure links to a short explanation.

Interaction:

- drag/scrub to reveal timestamp and value;
- selected value does not replace today's gain/loss label without changing the
  period text;
- rotation is not required;
- no range zoom handles from the web screenshots in v1.

States:

- partial/missing symbol history lists the number of omitted symbols;
- no historical service displays the current total and a retry state;
- hidden accounts are excluded.

### Movers

Content:

- segmented toggle for dollar or percentage movement;
- gainers and losers ranked from enabled accounts;
- each canonical symbol appears once, aggregated across accounts;
- symbol, amount, percentage, and directional indicator;
- default period is today's move versus previous close.

Recommended compact layout: two side-by-side lists when width and Dynamic Type
allow; otherwise stacked Gainers then Losers. Do not force a two-column layout
at accessibility text sizes.

Tapping a row may open holding detail in a later slice. v1 can expose account
allocation in an accessible disclosure.

### Portfolio breakdown

Expandable hierarchy:

```text
Brokerage name                         total value
  Account display name          value, today change
  Account display name          value, today change
```

Rules:

- brokerage total includes enabled accounts only on Overview;
- disabled accounts are managed in Settings, not mixed into totals;
- stale accounts carry a visible stale badge and resolution action;
- cash-only accounts are valid rows;
- account tap opens Account Detail;
- expansion state is presentation state, not persisted financial data.

## Holdings tab

The default Holdings view is portfolio-wide and symbol-aggregated across all
enabled accounts.

### Header

- portfolio value and today's gain/loss;
- freshness/as-of;
- grouping context: "All enabled accounts";
- refresh action.

### Holdings list

Each row shows:

- display/canonical symbol;
- security name when space permits;
- total quantity across enabled accounts;
- current price;
- market value;
- today's amount and percentage change;
- average cost, either inline on wider layouts or in row detail.

Sort default: market value descending. v1 supports sorting by symbol, market
value, and today's change. Custom saved views and arbitrary column editors are
excluded.

For a symbol held in multiple accounts, the row is a single portfolio holding.
An account-allocation disclosure lists brokerage, account, quantity, value, and
average cost without merging the stored account positions.

Cash is not a ticker row in portfolio Holdings. A compact cash summary appears
after securities and can expand to account cash balances.

## Account Detail

Opened from Portfolio Breakdown, Settings, or account allocation.

Header:

- brokerage and account display name;
- enabled/hidden and stale status;
- total value, equity value, and cash;
- today's change and freshness.

Performance:

- same range component and historical use case as Overview;
- scoped to this account;
- quality/disclosure derived from its slices.

Positions:

- symbol and name;
- quantity;
- current price and market value;
- today's change;
- weighted average cost;
- unrealized gain/loss.

Tax-term section:

- shown only when every position slice has acquisition dates;
- hidden entirely with an explanatory "Tax-term data unavailable from this
  brokerage file" note when incomplete;
- never estimates unknown Schwab dates.

Cash is a separate account summary row. A cash-only account renders a useful
empty-securities state rather than appearing broken.

## Settings tab

Sections:

### Import

- primary "Import brokerage files" action;
- last import time and provider as-of time per brokerage;
- latest result summary and issue count.

### Accounts

- every imported account, including disabled and stale;
- brokerage grouping;
- enabled toggle;
- display-name override later if needed;
- stale account actions: keep, hide, or delete.

Changing visibility immediately recomputes portfolio-wide totals and does not
delete holdings.

### Data status

- quote provider and last successful refresh;
- count of stale/missing symbols;
- storage is local-only;
- raw brokerage files are not retained.

Face ID, analytics controls, and direct broker connections are deferred unless
confirmed in `SPEC.md`.

## Import flow

### File selection

Use the system file importer. The user selects one current file per brokerage;
several brokerages may be selected in the same operation.

### Import preview

Group by detected brokerage, then account. Show:

- parser/detected brokerage;
- source as-of timestamp;
- new/updated/unchanged/stale status;
- account value, cash, and position count;
- warning/error count;
- calculated-versus-reported reconciliation warning when present;
- commit eligibility.

Warnings are expandable and allow commit. An error explains that the affected
account's previous data will remain unchanged. The user confirms the eligible
accounts as a batch.

No row-level checkbox permits silently skipping an invalid holding into a
wipe/replace account update.

### Import result

Summarize:

- accounts committed;
- accounts unchanged due to errors;
- stale accounts requiring action;
- warnings retained in audit metadata;
- next action: Done or Review Accounts.

## Car glance

Car glance is an iPhone surface, not one of the main tabs. It uses very large
type and shows:

- portfolio total;
- today's amount/percentage change;
- as-of/freshness;
- at most a few account rows.

It has no chart, Movers, holdings table, file import, or settings. See
[carplay.md](carplay.md).

## Explicit exclusions from the references

The following screenshot elements are not v1 requirements:

- US market index panel;
- automated portfolio guidance;
- Summary/Performance/Fundamentals/Everything web tabs;
- custom "My View" column designer;
- Add Portfolio/broker connection flow;
- web footer/help/legal navigation;
- browser-style chart zoom navigator.

## UI state model

Every data-driven screen supports:

- loaded/fresh;
- loaded/refreshing;
- loaded/stale;
- loaded/partial market data;
- empty before first import;
- recoverable error;
- account hidden/stale where relevant.

Import additionally supports probing, parsing, preview-ready, committing,
partial account success, and result.

Feature models receive immutable Application read models. They do not derive
financial totals or inspect persistence records.

## Screenshot trace

- `IMG_4621` and `IMG_4623`: headline totals, performance chart, range controls.
- `IMG_4624` and `IMG_4625`: Movers and brokerage/account breakdown.
- `IMG_4626` and `IMG_4628`: grouped holdings, cash, totals, and daily changes.

Only hierarchy and interaction ideas are adopted; displayed names/values are
private reference data and must not enter committed fixtures.

## UI acceptance checks

- Overview presents total, today change, chart, Movers, and breakdown using
  only enabled accounts.
- Holdings aggregates duplicate symbols and retains account allocation.
- Account Detail handles securities accounts and cash-only accounts.
- Imported/stale/estimated states are never indistinguishable from fresh/live.
- Import preview prevents partial-row replacement of an account.
- Core flows remain operable with VoiceOver and large Dynamic Type.
- Both light and dark appearances maintain readable gain/loss semantics.
