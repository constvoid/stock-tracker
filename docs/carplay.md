# CarPlay and Car Glance

**Status:** Approved (2026-10-10)  
**Normative source:** [SPEC.md](SPEC.md), CAR-001 and CAR-002

The locked path is A+B: iPhone **car glance** first, true **CarPlay templates**
later only if entitlement and intended distribution make it feasible.

## Constraints

CarPlay is templates only (`CPListTemplate`, `CPInformationTemplate`, `CPTabBarTemplate`). No custom SwiftUI/charts on the head unit. No import or editors.

**Finance/portfolio is not a public CarPlay category.** An entitlement is
required on-device. Public App Store distribution is therefore a material risk;
the category and entitlement must be re-checked immediately before this phase.

## A+B

- **Car glance (iPhone):** after core numbers; large type, total, day change,
  freshness, and a few accounts. No chart or import. Works on a phone mount
  regardless of entitlement.
- **CarPlay templates:** later and conditional; Summary + Accounts lists, then
  account → top holdings. Same read-only Application use cases.

Do not mis-declare an Apple category (e.g. audio) to ship finance UI.

## Module boundary

`CarGlanceFeature` is SwiftUI and may ship in the main app. `CarPlayFeature` is
a separate later target importing CarPlay, Domain, and Application. Domain and
Application never import CarPlay.

## Later CarPlay types

`CarPlaySceneDelegate` (app target) → `SummaryTemplateFactory`, `AccountsTemplateFactory`, `PositionsTemplateFactory`. Read Application use cases only. Throttle refresh.

Siri/App Intents (“portfolio worth?”) remain deferred and can use the same read
use cases independently of CarPlay.

## Safety rules

- Read-only; no import, settings, editing, authentication prompts, or trading.
- No charts or custom-drawn dense financial UI on the head unit.
- One tap should reveal the useful value; avoid deep navigation.
- Throttle refresh and show cached values immediately.
- Include as-of/stale context without distracting detail.
- Never misdeclare an Apple app category.
