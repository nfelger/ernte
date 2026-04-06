# CLAUDE.md — AI coding guidance for Ernte

This file tells AI assistants how to work in this codebase. Read it before making changes.

---

## What this project is

A mobile-web-first Godot 4.x prototype. Turn-based monthly decisions on a German family farm. The primary goal is **rapid design iteration**, not production quality. Every architectural choice reflects that.

The prototype answers one question: does the monthly decision loop create emergent farm stories?

---

## Architectural intent

### Singletons as the backbone
Four autoloaded singletons handle all game logic:
- `GameState` — data only, no logic, emits signals
- `RulesEngine` — stateless rules; reads/writes via GameState methods
- `DataLoader` — I/O only; populates GameState from JSON
- `TurnManager` — sequencing only; calls the others in order

**Do not collapse these.** The separation makes each piece testable and independently readable.

### UI reads, never writes
`MainScreen` and `DebugOverlay` call `RulesEngine` / `TurnManager` for actions and read `GameState` for display. They never mutate `GameState` directly. This is the single most important rule: if you find yourself writing `GameState.capital = ...` inside a UI script, stop.

### Code-driven UI
All UI is built in GDScript (`main_screen.gd`), not in `.tscn` files. This is intentional: it makes layout changes readable in diffs, avoids merge conflicts on binary-ish scene files, and keeps the prototype moveable. Do not switch to editor-built scenes unless the UI grows complex enough to warrant it (it probably won't for a prototype).

### Data-driven content
Crops, events, and the starting farm come from `data/*.json`. RulesEngine and TurnManager read these via GameState — they never hardcode crop names or event texts. Adding a crop must not require a code change.

---

## Coding conventions

- **GDScript only.** No C#.
- **Typed where practical.** Use `: String`, `: float`, `: Dictionary` etc. for function signatures. Untyped locals in short functions are fine.
- **Small focused scripts.** Each script does one thing. `GameState` holds state. `RulesEngine` applies rules. Don't add UI logic to `RulesEngine`.
- **Signal-driven UI updates.** Connect to `GameState.state_changed` to refresh display. Don't poll in `_process()`.
- **No `_process()` or `_physics_process()`** unless an animation genuinely requires per-frame updates. Everything is turn-based; use signals.
- **Comments where choices matter.** Explain *why*, not *what*. "# MOUSE_FILTER_IGNORE so clicks reach the Button below" is useful. "# increment counter" is not.
- **German UI text, English code.** Labels, events, and crop names in German. Variable names, function names, comments in English.

---

## Iteration philosophy

This is a prototype. Optimize for:
1. **Speed of change** — a designer should be able to add a crop in 2 minutes
2. **Clarity** — another person should be able to understand any file in 5 minutes
3. **Correctness** — the game should not crash; rules should produce sensible output

Do NOT optimize for:
- Generality or extensibility beyond what's needed now
- Performance (this is a 2D UI game targeting mobile web; it will be fine)
- Polish or production architecture

---

## Things to preserve

- The singleton autoload order in `project.godot`: `GameState → RulesEngine → DataLoader → TurnManager`. Later singletons depend on earlier ones.
- `MOUSE_FILTER_IGNORE` on containers/labels inside Button-based field cards. This is required for touch to work.
- The Compatibility renderer setting. Forward+ breaks mobile web performance.
- Portrait primary layout (480×854). All UI decisions cascade from this.
- The event tone: dry, factual, slightly absurd. Read `data/events.json` before writing new events.

---

## Things intentionally deferred

These are out of scope for the current prototype. Do not add them unless the brief changes:
- Save/load system
- Identity / farm history system  
- Workforce or hiring mechanics
- Tech tree or upgrades
- Ending or handoff narrative
- Backend / server of any kind
- Polished art or animations
- Localization infrastructure
- Sound

---

## How to add things safely

### New crop
Edit `data/crops.json`. No code changes. Test via Debug panel → "Feld bepflanzen".

### New event
Edit `data/events.json`. No code changes. Test via Debug panel → "Ereignis erzwingen".

### New event effect type
1. Add handling in `TurnManager._apply_event()`.
2. Add the corresponding method in `GameState` if it's a new resource.
3. Update the JSON schema comment in `README.md`.

### New resource track
1. Add variable + `modify_X()` + signal to `GameState`.
2. Add display row in `MainScreen._build_resources()`.
3. Add +/- row in `DebugOverlay._build_ui()`.
4. Wire effects in `TurnManager._apply_event()`.

### New game rule
Add it to `RulesEngine`. If it's a monthly effect, call it from `process_month_end()`. If seasonal, from `process_season_transition()`. Keep constants at the top of `rules_engine.gd` so they're easy to tune.

### New UI screen
Create a new scene + script pair in `scenes/ui/` + `scripts/ui/`. Load it from `main_screen.gd` as needed. Do not add navigation state to `GameState` — that's UI concern.

---

## Known fragilities

- `DataLoader` uses `FileAccess.open()` with `res://` paths. This works in editor and in exported Web builds (Godot PCKs the files), but will silently fail if paths are wrong. Check console for `DataLoader:` errors on startup.
- Field card mouse events rely on `MOUSE_FILTER_IGNORE` on all children. If you add a new Control inside a field card, set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on it.
- `TurnManager.advance_year()` calls `advance_month()` 12 times in a loop. This is fine for debug, but it fires all signals synchronously — UI will redraw 12 times. Acceptable for a debug tool.
