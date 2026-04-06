extends Node
## DataLoader — reads JSON content files and populates GameState.
##
## All content lives in res://data/. Changing a JSON file and calling
## reload_content() (or the debug panel button) picks up the new data
## without restarting. Scripts never hardcode crop/event data.

const CROPS_PATH: String = "res://data/crops.json"
const EVENTS_PATH: String = "res://data/events.json"
const STARTING_FARM_PATH: String = "res://data/starting_farm.json"

func _ready() -> void:
	load_all()

func load_all() -> void:
	## Full data load. Called on startup and on game reset.
	load_starting_farm()
	load_crops()
	load_events()

# ── Internal helpers ──────────────────────────────────────────────────────────

func _load_json(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open '%s' (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("DataLoader: JSON error in '%s' at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()])
		return null

	return json.get_data()

# ── Loaders ───────────────────────────────────────────────────────────────────

func load_starting_farm() -> void:
	var data: Variant = _load_json(STARTING_FARM_PATH)
	if data == null or not data is Dictionary:
		push_error("DataLoader: starting_farm.json missing or not an object")
		return

	# Time
	var time: Dictionary = data.get("time", {})
	GameState.start_year = int(time.get("start_year", 2024))
	GameState.current_year = int(time.get("year", 1))
	GameState.current_month = int(time.get("month", 3))

	# Resources
	var res: Dictionary = data.get("resources", {})
	GameState.capital = float(res.get("capital", 50000.0))
	GameState.land_health = float(res.get("land_health", 60.0))
	GameState.reputation = float(res.get("reputation", 40.0))

	# Fields — duplicate so mutations don't touch the parsed array
	GameState.fields = (data.get("fields", []) as Array).duplicate(true)

func load_crops() -> void:
	var data: Variant = _load_json(CROPS_PATH)
	if data == null or not data is Array:
		push_error("DataLoader: crops.json missing or not an array")
		return

	GameState.crops_data = {}
	GameState.market_prices = {}
	for crop: Dictionary in data:
		var id: String = crop.get("id", "")
		if id == "":
			push_warning("DataLoader: crop entry missing 'id', skipping")
			continue
		GameState.crops_data[id] = crop
		GameState.market_prices[id] = float(crop.get("base_price", 0.20))

func load_events() -> void:
	var data: Variant = _load_json(EVENTS_PATH)
	if data == null or not data is Array:
		push_error("DataLoader: events.json missing or not an array")
		return

	GameState.event_deck = (data as Array).duplicate(true)
	GameState.event_deck.shuffle()
	GameState.event_discard = []

# ── Runtime helpers ───────────────────────────────────────────────────────────

func draw_event() -> Dictionary:
	## Pop from deck; reshuffle discard into deck when empty.
	if GameState.event_deck.is_empty():
		GameState.event_deck = GameState.event_discard.duplicate(true)
		GameState.event_deck.shuffle()
		GameState.event_discard = []

	if GameState.event_deck.is_empty():
		return {}

	var event: Dictionary = GameState.event_deck.pop_front()
	GameState.event_discard.append(event)
	return event

func reload_content() -> void:
	## Hot-reload crops and events without resetting game state.
	## Fields and resources are NOT reset — use GameState.reset_to_start() for that.
	load_crops()
	load_events()
	print("DataLoader: content reloaded from disk.")
