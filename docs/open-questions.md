# Open Questions

Confirmed requirements live in [SPEC.md](SPEC.md). Do not re-ask them. When an
answer changes product behavior, update the relevant requirement there before
reconciling design and TODOs.

## Resolved blockers

- **Architecture approval (2026-10-10):** Krishna approved `SPEC.md` and the
  design documents. Implementation may proceed per [TODO.md](TODO.md).
- Import samples and UI reference images were reviewed earlier; they remain
  local-only and gitignored.

## Must resolve before the affected phase

### Before historical chart implementation

- Missing daily/intraday bar behavior:
  - carry the last known close across a missing market bar; or
  - leave a chart gap.

Recommended: carry across market-closed gaps only, but expose true provider
data gaps. This needs a precise calendar rule in HIST requirements.

### Before market-data implementation

- Use regular-session prices only, or include extended-hours prices?
- Refresh policy beyond manual/pull-to-refresh:
  - foreground refresh only;
  - opportunistic background refresh;
  - scheduled background refresh where iOS permits.

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
