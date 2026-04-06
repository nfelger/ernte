extends Node
## GameState — central game state singleton.
##
## All mutable game data lives here. UI scenes read from here; they never
## write directly. Mutations go through GameState methods or via
## RulesEngine / TurnManager. This keeps business logic testable and the
## UI thin.

# ── Signals ──────────────────────────────────────────────────────────────────

signal state_changed
signal month_changed(year: int, month: int, season: String)
signal event_triggered(event_data: Dictionary)
signal resource_changed(resource_name: String, new_value: float)

# ── Time ──────────────────────────────────────────────────────────────────────

## Internal year counter (1 = first year of play).
var current_year: int = 1
## Month 1–12.
var current_month: int = 3
## Calendar year corresponding to internal year 1.
var start_year: int = 2024
## Prototype runs this many game-years before triggering end state.
var max_years: int = 10

# ── Resources ─────────────────────────────────────────────────────────────────

var capital: float = 50000.0
var land_health: float = 60.0   # 0–100
var reputation: float = 40.0    # 0–100

# ── Farm ──────────────────────────────────────────────────────────────────────

## Array of field Dictionaries. Shape defined in data/starting_farm.json.
var fields: Array = []

## Crop definitions keyed by crop id. Populated by DataLoader from crops.json.
var crops_data: Dictionary = {}

## Current market price (€/kg) per crop id. Updated monthly by RulesEngine.
var market_prices: Dictionary = {}

# ── Events ────────────────────────────────────────────────────────────────────

var current_event: Dictionary = {}
var event_deck: Array = []
var event_discard: Array = []

# ── Constants ─────────────────────────────────────────────────────────────────

const SEASON_MONTHS: Dictionary = {
	"Winter": [12, 1, 2],
	"Frühling": [3, 4, 5],
	"Sommer": [6, 7, 8],
	"Herbst": [9, 10, 11],
}

const MONTH_NAMES: Array = [
	"", "Januar", "Februar", "März", "April", "Mai", "Juni",
	"Juli", "August", "September", "Oktober", "November", "Dezember"
]

# ── Queries ───────────────────────────────────────────────────────────────────

func get_current_season() -> String:
	for season: String in SEASON_MONTHS:
		if current_month in SEASON_MONTHS[season]:
			return season
	return "Unbekannt"

func get_month_name() -> String:
	if current_month >= 1 and current_month <= 12:
		return MONTH_NAMES[current_month]
	return "?"

func get_display_year() -> int:
	return start_year + current_year - 1

func get_field(field_id: int) -> Dictionary:
	if field_id >= 0 and field_id < fields.size():
		return fields[field_id]
	return {}

# ── Resource mutations ────────────────────────────────────────────────────────

func modify_capital(amount: float) -> void:
	capital += amount
	capital = maxf(capital, 0.0)
	resource_changed.emit("capital", capital)
	state_changed.emit()

func modify_land_health(amount: float) -> void:
	land_health = clampf(land_health + amount, 0.0, 100.0)
	resource_changed.emit("land_health", land_health)
	state_changed.emit()

func modify_reputation(amount: float) -> void:
	reputation = clampf(reputation + amount, 0.0, 100.0)
	resource_changed.emit("reputation", reputation)
	state_changed.emit()

# ── Field mutations ───────────────────────────────────────────────────────────

func set_field_crop(field_id: int, crop_id: String) -> void:
	if field_id < 0 or field_id >= fields.size():
		return
	fields[field_id]["planted_crop"] = crop_id
	fields[field_id]["status"] = "planted"
	fields[field_id]["months_grown"] = 0
	state_changed.emit()

func clear_field(field_id: int) -> void:
	if field_id < 0 or field_id >= fields.size():
		return
	fields[field_id]["planted_crop"] = ""
	fields[field_id]["status"] = "fallow"
	fields[field_id]["months_grown"] = 0
	state_changed.emit()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func reset_to_start() -> void:
	## Reset all state to initial values from data files.
	current_year = 1
	current_month = 3
	current_event = {}
	# DataLoader re-populates fields, resources, decks.
	DataLoader.load_all()
	state_changed.emit()
