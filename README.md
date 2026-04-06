# Ernte — Prototyp

A turn-based strategic economic sim about running a family farm in present-day Germany over many years. One turn = one month. You make decisions, the land responds, things happen.

**Current scope:** 6 fields, 4 crops, 3 resource tracks, monthly events, 10-year prototype run.

---

## Running in Godot

1. Install [Godot 4.3+](https://godotengine.org/download) (standard version, not .NET).
2. Open Godot → **Import** → select this folder → open `project.godot`.
3. Press **F5** (or the Play button) to run.

The project opens directly to the main game screen. No splash screen, no menus — straight to the loop.

---

## Exporting to Web (HTML5)

### One-time setup
1. In Godot, go to **Editor → Export**.
2. Add a **Web** export preset.
3. Under **Options**, check **Extensions Support** = off (not needed).
4. Make sure the **Export Path** ends in `.html`.

### Export
```
Project → Export → Web → Export Project
```

Point the output to a folder, e.g. `exports/web/index.html`.

### Running locally (fast browser iteration)

Browsers block `res://` file loading from `file://` origins. You need a local server:

```bash
# Python 3 (simplest)
cd exports/web
python3 -m http.server 8080
# then open http://localhost:8080 in Chrome/Firefox

# Or use the Godot editor's built-in remote debug:
# Export with "Run in Browser" checked, Godot starts the server automatically.
```

**Chrome note:** Chrome requires `SharedArrayBuffer`, which needs cross-origin isolation headers. Firefox handles local files more leniently for quick testing.

For production hosting, upload the export folder to any static host (GitHub Pages, Netlify, itch.io). Set these response headers:
```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

---

## Architecture

```
GameState          — singleton: all mutable game data
RulesEngine        — singleton: planting, harvesting, price rules
DataLoader         — singleton: reads JSON content files, populates GameState
TurnManager        — singleton: orchestrates turn flow, events, season logic

scenes/main.tscn          — root scene (one Control node)
scripts/ui/main_screen.gd — builds and drives the entire game UI
scripts/ui/debug_overlay.gd — developer tools overlay
```

### Data flow

```
DataLoader (reads JSON)
    → populates GameState

Player action (button press)
    → RulesEngine.do_plant() / do_harvest()
    → mutates GameState
    → GameState.state_changed emitted
    → MainScreen._refresh_all() redraws UI

TurnManager.advance_month()
    → RulesEngine.process_month_end()
    → advances GameState time
    → maybe triggers event via DataLoader.draw_event()
    → RulesEngine.update_market_prices()
    → GameState.state_changed / month_changed emitted
```

UI scenes **only read** from GameState. They call RulesEngine / TurnManager for mutations. GameState never calls UI.

---

## Where to add content

### New crop
Add an entry to `data/crops.json`. Required fields:
```json
{
  "id": "unique_snake_case_id",
  "name": "Anzeigename",
  "description": "Kurzbeschreibung",
  "plant_seasons": ["Frühling"],
  "grow_months": 5,
  "seed_cost": 500.0,
  "base_yield_kg_per_ha": 4000.0,
  "base_price": 0.30,
  "winter_hardy": false,
  "reputation_on_harvest": 1.0
}
```
No code changes needed. Reload content via the Debug panel or restart.

### New event
Add an entry to `data/events.json`. Required fields:
```json
{
  "id": "unique_id",
  "title": "Kurztitel",
  "text": "Langer Ereignistext. Trocken, faktisch, leicht absurd.",
  "trigger_seasons": ["Frühling", "Sommer"],
  "effects": { "capital": -500, "land_health": -3 },
  "tags": ["wetter"]
}
```
`effects` keys: `capital`, `land_health`, `reputation`. All optional.

### New resource track
1. Add the variable to `GameState` with `modify_X()` and signal.
2. Add a display row in `main_screen.gd`'s `_build_resources()`.
3. Add +/- controls to `debug_overlay.gd`'s `_resource_row()` section.

### Modify starting state
Edit `data/starting_farm.json`. Change field names, sizes, health modifiers, or starting resources without touching any code.

---

## Mobile web notes

- **Portrait layout** is the primary target (480×854 logical px).
- The Godot stretch mode `canvas_items` + aspect `expand` fills any phone screen.
- Buttons are ≥46px tall to hit touch targets comfortably.
- No hover-dependent UX (nothing requires mouse hover).
- Touch input is emulated from mouse in the editor (`emulate_touch_from_mouse = true`).
- The Compatibility renderer (GL ES 3.0 / WebGL 2) is configured for best mobile web performance.

---

## Project structure

```
data/               Content files (crops, events, starting farm)
scenes/             Godot scene files (.tscn)
  ui/               UI sub-scenes (debug overlay)
scripts/
  core/             Singletons: GameState, RulesEngine, DataLoader, TurnManager
  ui/               UI scripts: main_screen, debug_overlay
assets/
  fonts/            (placeholder — add custom fonts here if needed)
```
