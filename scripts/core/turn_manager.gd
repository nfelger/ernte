extends Node
## TurnManager — orchestrates turn flow.
##
## One "turn" = one month. Call advance_month() to progress the game.
## All end-of-month effects, season transitions, and event draws happen here
## in a defined order. UI listens to signals; it never drives turn logic.

# ── Signals ──────────────────────────────────────────────────────────────────

signal turn_started(year: int, month: int)
signal turn_ended(year: int, month: int)
signal season_changed(new_season: String)
signal year_changed(new_year: int)
signal game_over(reason: String)

# ── Event chance tuning ───────────────────────────────────────────────────────

## Base probability of drawing an event each month.
const EVENT_BASE_CHANCE: float = 0.35
## Extra probability during active farming seasons.
const EVENT_ACTIVE_SEASON_BONUS: float = 0.15

# ── State ─────────────────────────────────────────────────────────────────────

var _previous_season: String = ""

func _ready() -> void:
	_previous_season = GameState.get_current_season()

# ── Public API ────────────────────────────────────────────────────────────────

func advance_month() -> void:
	## Progress one month. Applies end-of-month logic, then updates time,
	## then checks for season change, then draws event, then updates prices.
	turn_ended.emit(GameState.current_year, GameState.current_month)

	# 1. End-of-month field processing (growth ticks, fallow recovery).
	RulesEngine.process_month_end()

	# 2. Advance calendar.
	GameState.current_month += 1
	if GameState.current_month > 12:
		GameState.current_month = 1
		GameState.current_year += 1
		year_changed.emit(GameState.current_year)

		if GameState.current_year > GameState.max_years:
			game_over.emit("prototype_end")
			# Don't return — still refresh UI.

	# 3. Season transition check.
	var new_season: String = GameState.get_current_season()
	if new_season != _previous_season:
		_previous_season = new_season
		RulesEngine.process_season_transition(new_season)
		season_changed.emit(new_season)

	# 4. Maybe trigger an event.
	_maybe_trigger_event()

	# 5. Update market prices.
	RulesEngine.update_market_prices()

	# 6. Notify listeners.
	turn_started.emit(GameState.current_year, GameState.current_month)
	GameState.month_changed.emit(
		GameState.current_year,
		GameState.current_month,
		GameState.get_current_season()
	)
	GameState.state_changed.emit()

func advance_year() -> void:
	## Debug shortcut: fast-forward exactly 12 months.
	for _i: int in range(12):
		if GameState.current_year <= GameState.max_years:
			advance_month()

func force_event(event_id: String) -> void:
	## Debug: trigger a specific event regardless of probability.
	var all_events: Array = GameState.event_deck + GameState.event_discard
	for event: Dictionary in all_events:
		if event.get("id", "") == event_id:
			_apply_event(event)
			GameState.current_event = event
			GameState.event_triggered.emit(event)
			return
	push_warning("TurnManager.force_event: event '%s' not found" % event_id)

# ── Internal ──────────────────────────────────────────────────────────────────

func _maybe_trigger_event() -> void:
	var season: String = GameState.get_current_season()
	var chance: float = EVENT_BASE_CHANCE
	if season in ["Frühling", "Herbst"]:
		chance += EVENT_ACTIVE_SEASON_BONUS

	if randf() >= chance:
		GameState.current_event = {}
		return

	var event: Dictionary = DataLoader.draw_event()
	if event.is_empty():
		return

	_apply_event(event)
	GameState.current_event = event
	GameState.event_triggered.emit(event)

func _apply_event(event: Dictionary) -> void:
	## Apply the numeric effects of an event to GameState.
	## Effect keys: "capital", "land_health", "reputation".
	var effects: Dictionary = event.get("effects", {})
	if effects.has("capital"):
		GameState.modify_capital(float(effects["capital"]))
	if effects.has("land_health"):
		GameState.modify_land_health(float(effects["land_health"]))
	if effects.has("reputation"):
		GameState.modify_reputation(float(effects["reputation"]))
