# Stock Tracker — design docs

**Start here:** [SPEC.md](SPEC.md) is the living, normative specification.
Change requirements there first, then reconcile design, TODOs, code, and tests.
[HANDOFF.md](HANDOFF.md) records session state and [TODO.md](TODO.md) is the
execution checklist.

Specification and design **approved** (2026-10-10). Implementation follows
[TODO.md](TODO.md).

| Document | What it covers |
| --- | --- |
| [SPEC.md](SPEC.md) | Normative requirements, stable IDs, acceptance criteria, change/reconciliation workflow |
| [HANDOFF.md](HANDOFF.md) | Locked decisions, pickup instructions, next step |
| [TODO.md](TODO.md) | Ordered implementation phases and acceptance gates |
| [architecture.md](architecture.md) | Targets, dependencies, ports/adapters, runtime flows |
| [import-design.md](import-design.md) | Brokerage-agnostic contract and Schwab/E*TRADE adapters |
| [domain-and-data.md](domain-and-data.md) | Domain types, capabilities, calculations, persistence |
| [ui-design.md](ui-design.md) | Screenshot-derived iPhone information architecture and states |
| [carplay.md](carplay.md) | Category limits, A+B (glance then templates) |
| [implementation-phases.md](implementation-phases.md) | Phase rationale; TODO is authoritative |
| [open-questions.md](open-questions.md) | Unlocked leftovers only |

The local source CSVs and screenshots are private planning inputs. Do not commit
them. **Not started:** Xcode project, Swift packages, app implementation.
