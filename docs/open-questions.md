# Open Questions

Confirmed requirements live in [SPEC.md](SPEC.md). Do not re-ask them. When an
answer changes product behavior, update the relevant requirement there before
reconciling design and TODOs.

## Resolved blockers

- **Architecture approval (2026-10-10):** Krishna approved `SPEC.md` and the
  design documents. Implementation may proceed per [TODO.md](TODO.md).
- Import samples and UI reference images were reviewed earlier; they remain
  local-only and gitignored.
- **Market session prices (2026-10-10):** Include extended-hours prices when
  provided (`MKT-001`). Previous close stays the prior regular-session close.
- **Quote refresh (2026-10-10):** Pull-to-refresh and foreground activation only
  (`MKT-003`). No background fetch in v1.
- **Missing historical bars (2026-10-10):** Carry last close across
  non-sessions; leave a gap for missing expected trading sessions (`HIST-005`).

## Must resolve before the affected phase

### Before CarPlay implementation

- Intended distribution: personal development build, family/TestFlight, or
  eventual public App Store.
- Whether Apple grants an appropriate entitlement/category at that time.

CarPlay remains deferred and cannot block the iPhone car-glance surface.

## Non-blocking product choices

- Face ID gate at launch.
- User-editable account kind (taxable, IRA, Roth, 401k) when not present in the
  import.
- Whether to retain file import permanently after direct brokerage APIs
  (recommended and currently assumed: yes).
- Siri/Shortcuts and widgets after core features.
- Dedicated iPad navigation rather than automatic adaptive layout.

## Explicitly answered

- v1 is read-only; no trading/orders.
- USD, US stocks/ETFs, fractional shares, and cash only.
- iOS 18+.
- Local-only SwiftData; no iCloud v1.
- One complete file per brokerage, multiple accounts per file.
- Raw files discarded after import.
- Intraday Day chart defaults to five-minute bars.
- Dividends and realized gains are excluded from v1.
- Extended-hours quotes are included when available.
- Quote refresh is foreground + pull-to-refresh only.
- History carries across closed-market gaps; gaps remaining expected sessions.
