# TODO — Ernte Prototype

Prioritized next steps. Work top-to-bottom. Re-prioritize after each playtest.

---

## P0 — Make the loop actually work

- [ ] **Harvest revenue feedback** — show a clear per-field harvest result (yield kg + price + revenue) as a modal or in the event panel. Currently just shows total EUR.
- [ ] **Sell action** — implement a basic market screen or inline sell panel. Crops harvested should go into an inventory; sell separately at market prices.
- [ ] **Month-end summary** — brief summary of what happened this month (events, health changes, price moves) before the turn advances. Prevents "what just happened?" confusion.
- [ ] **Game over / end-of-run screen** — when year 10 ends, show a summary: total capital earned, peak land health, notable events. No narrative yet, just numbers.

---

## P1 — Playtest-critical mechanics

- [ ] **Land health effects on yield** — currently applied via `health_mod` in `do_harvest()`. Verify the numbers feel meaningful in play. Likely needs tuning.
- [ ] **Price display** — show current market prices per crop somewhere. Players need to see price trends to make informed planting decisions.
- [ ] **Seasonal crop filtering** — already checked in `can_plant()` but the Plant overlay should make it obvious which crops are valid *this* season vs. why others are greyed out.
- [ ] **Field notes display** — the `notes` field on each field exists in data. Surface it somehow (tooltip? expanded field view on tap?).
- [ ] **Clover/ley handling** — `clover_ley` has `land_health_bonus` in JSON but RulesEngine doesn't read it yet. Wire it up so ley actually restores land health when it matures.

---

## P2 — Iteration quality

- [ ] **Debug panel: set month/year directly** — typing a target month is faster than clicking "+ Monat" 8 times.
- [ ] **Hot-reload JSON** — "Daten neu laden" works for crops and events. Extend to also hot-reload starting_farm field definitions (useful for tweaking field sizes mid-session).
- [ ] **Price chart or sparkline** — even a 6-month price history per crop would help players understand market dynamics.
- [ ] **Event history** — log the last 5-6 events somewhere accessible. Currently the event panel only shows the most recent one.
- [ ] **Fallow penalty** — consider adding a small reputation drain for leaving all 6 fields fallow too long. Test whether this creates interesting pressure.

---

## P3 — Content expansion

- [ ] **More crops** — potatoes, maize, sunflowers. Each needs a distinct tradeoff (input cost, yield timing, price volatility).
- [ ] **More events** — target 25-30 total. Each event should ideally reveal something about farm life or the district. Keep the tone.
- [ ] **Seasonal event filtering** — `trigger_seasons` exists in the data but TurnManager currently ignores it. Wire it up so late-frost events don't fire in August.
- [ ] **Weather system** — multi-month drought or wet-spring conditions that persist. Currently events are one-shot.

---

## P4 — Architecture / technical

- [ ] **Input handling** — currently using `Button.pressed` signals everywhere. Consider whether gesture input (swipe to next month) would improve mobile feel.
- [ ] **Accessibility** — minimum font size audit. Check legibility on a physical phone screen at arm's length.
- [ ] **Web export automation** — add a shell script or Makefile target for one-command export + local serve.
- [ ] **Save state** — `ResourceSaver` + JSON dump of `GameState` would let testers resume sessions. Low priority until sessions last >15 minutes.
- [ ] **Unit tests** — `RulesEngine` functions are pure enough to test without UI. A few test cases for `do_harvest()`, `can_plant()`, `update_market_prices()` would catch regressions during balancing.

---

## Backlog (out of scope for current prototype)

- Identity / farm history system
- Workforce and labour mechanics
- Tech tree / equipment upgrades
- Narrative ending / farm handoff
- Localization (English/German toggle)
- Ambient sound design
- Any backend or persistence service
