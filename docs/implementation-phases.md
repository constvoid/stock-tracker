# Implementation Phases

[TODO.md](TODO.md) is the authoritative checklist and acceptance gate. This
document explains sequencing only.

Design approved 2026-10-10. Proceed through phases in order; privacy gate first.

## 0 — Approval and privacy

Approve SPEC/design, ignore private samples before any commit, and create
fabricated structural fixtures. This gate protects financial data before tools,
tests, or git history expand.

## 1 — Module scaffold

Create the iOS 18 app and local multi-target Swift package. Establish dependency
rules and deterministic fake ports before feature code.

## 2 — Domain and calculations

Build Decimal values, hybrid position slices, account state, average cost,
rollups, duplicate-symbol aggregation, and capabilities as pure tested code.

## 3 — persistence and brokerage-file import

Add SwiftData and the brokerage-agnostic parser registry. Implement Schwab and
E*TRADE as adapters, account-level transactional replacement, preview issues,
and stale detection.

This precedes production UI so feature work consumes real use-case contracts
rather than temporary CSV parsing in views.

## 4 — local-data iPhone app

Deliver Overview, Movers, account breakdown, Holdings, Account Detail, and
Settings/Import using imported fallback prices and fake/cached data. Validate
accessibility before adding network timing.

## 5 — market data

Add Yahoo-style quotes, provider aliases, previous close, refresh, and cache
freshness. Network failure must not affect holdings.

## 6 — reconstructed history

Add intraday/daily providers and charts for D/W/M/YTD/1Y/3Y/5Y. Display
reconstructed versus estimated quality.

## 7 — iPhone car glance

Add the reliable large-type in-car surface without waiting for CarPlay
entitlement.

## 8 — observed history

Persist valuation snapshots behind the existing historical-value use case.

## 9 — CarPlay, if feasible

Re-check Apple policy and entitlement, then add read-only list/info templates.
Do not misdeclare a category or delay the iPhone product.

## Deferred

Direct broker APIs, merge-on-import, dedicated iPad design, Siri/widgets,
income/transactions, other asset classes/currencies, iCloud, and trading require
new or changed SPEC requirements.
