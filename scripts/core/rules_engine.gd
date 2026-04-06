extends Node
## RulesEngine — all game rules in one place.
##
## Intentionally flat and explicit. Do not split into strategy objects unless
## rule count grows dramatically (>~200 lines per domain). The priority is
## that a designer can read this file and immediately understand what changes
## to expect from any tweak. Clarity over elegance.

# ── Tuning constants (tweak freely) ──────────────────────────────────────────

## Land health regenerated per fallow field per month, scaled by field count.
const FALLOW_REGEN_PER_FIELD: float = 1.5
## Land health lost per growing field per month, scaled by field count.
const GROWING_DRAIN_PER_FIELD: float = 0.8
## Global land health boost on Spring arrival.
const SPRING_ARRIVAL_BONUS: float = 3.0
## Price random walk magnitude per month (fraction of current price).
const PRICE_WALK_MAX: float = 0.08
## Price is clamped to [base * MIN_FACTOR, base * MAX_FACTOR].
const PRICE_MIN_FACTOR: float = 0.50
const PRICE_MAX_FACTOR: float = 1.60

# ── Monthly processing ────────────────────────────────────────────────────────

func process_month_end() -> void:
	## Called by TurnManager at the end of each month, before time advances.
	_process_fields()

func _process_fields() -> void:
	var n_fields: int = GameState.fields.size()
	if n_fields == 0:
		return

	for i in range(n_fields):
		var field: Dictionary = GameState.fields[i]
		var crop_id: String = field.get("planted_crop", "")

		if crop_id == "":
			# Fallow: partial land-health recovery.
			var regen: float = FALLOW_REGEN_PER_FIELD * field.get("health_modifier", 1.0)
			GameState.modify_land_health(regen / n_fields)
		else:
			# Growing: advance counter, drain health, check readiness.
			field["months_grown"] = field.get("months_grown", 0) + 1
			GameState.modify_land_health(-GROWING_DRAIN_PER_FIELD / n_fields)

			var crop: Dictionary = GameState.crops_data.get(crop_id, {})
			var grow_months: int = int(crop.get("grow_months", 3))
			if field.get("months_grown", 0) >= grow_months:
				field["status"] = "ready"
			elif field["status"] == "planted":
				field["status"] = "growing"

			GameState.fields[i] = field

# ── Seasonal transitions ──────────────────────────────────────────────────────

func process_season_transition(new_season: String) -> void:
	## Called by TurnManager when the season changes.
	match new_season:
		"Frühling":
			# Spring thaw: small global land health boost.
			GameState.modify_land_health(SPRING_ARRIVAL_BONUS)
		"Winter":
			# Winter arrival: non-hardy crops that weren't harvested wither.
			for i in range(GameState.fields.size()):
				var field: Dictionary = GameState.fields[i]
				var crop_id: String = field.get("planted_crop", "")
				if crop_id == "":
					continue
				var crop: Dictionary = GameState.crops_data.get(crop_id, {})
				if not crop.get("winter_hardy", false):
					field["planted_crop"] = ""
					field["status"] = "withered"
					field["months_grown"] = 0
					GameState.fields[i] = field
					push_warning("RulesEngine: %s withered in field %d (winter)" % [crop_id, i])

# ── Planting ──────────────────────────────────────────────────────────────────

func can_plant(field_id: int, crop_id: String) -> Dictionary:
	## Returns {ok: bool, reason: String}. Check before calling do_plant().
	var field: Dictionary = GameState.get_field(field_id)
	if field.is_empty():
		return {"ok": false, "reason": "Ungültiges Feld"}

	if field.get("planted_crop", "") != "":
		return {"ok": false, "reason": "Feld ist bereits bepflanzt"}

	var crop: Dictionary = GameState.crops_data.get(crop_id, {})
	if crop.is_empty():
		return {"ok": false, "reason": "Unbekannte Frucht: " + crop_id}

	var season: String = GameState.get_current_season()
	var valid_seasons: Array = crop.get("plant_seasons", [])
	if valid_seasons.size() > 0 and not season in valid_seasons:
		return {"ok": false, "reason": "%s kann jetzt nicht gepflanzt werden (%s)" % [crop.get("name", crop_id), season]}

	var cost: float = float(crop.get("seed_cost", 0.0))
	if GameState.capital < cost:
		return {"ok": false, "reason": "Nicht genug Kapital (€%.0f benötigt)" % cost}

	return {"ok": true, "reason": ""}

func do_plant(field_id: int, crop_id: String) -> bool:
	## Returns true on success.
	var check: Dictionary = can_plant(field_id, crop_id)
	if not check["ok"]:
		push_warning("RulesEngine.do_plant: " + check["reason"])
		return false

	var crop: Dictionary = GameState.crops_data.get(crop_id, {})
	GameState.modify_capital(-float(crop.get("seed_cost", 0.0)))
	GameState.set_field_crop(field_id, crop_id)
	return true

# ── Harvesting ────────────────────────────────────────────────────────────────

func can_harvest(field_id: int) -> Dictionary:
	## Returns {ok: bool, reason: String}.
	var field: Dictionary = GameState.get_field(field_id)
	if field.is_empty():
		return {"ok": false, "reason": "Ungültiges Feld"}

	match field.get("status", "fallow"):
		"fallow":
			return {"ok": false, "reason": "Kein Anbau auf diesem Feld"}
		"planted", "growing":
			return {"ok": false, "reason": "Ernte noch nicht bereit"}
		"withered":
			return {"ok": false, "reason": "Frucht ist verkümmert"}

	return {"ok": true, "reason": ""}

func do_harvest(field_id: int) -> float:
	## Executes harvest. Returns revenue in EUR, or 0.0 on failure.
	var check: Dictionary = can_harvest(field_id)
	if not check["ok"]:
		push_warning("RulesEngine.do_harvest: " + check["reason"])
		return 0.0

	var field: Dictionary = GameState.get_field(field_id)
	var crop_id: String = field.get("planted_crop", "")
	var crop: Dictionary = GameState.crops_data.get(crop_id, {})

	# Yield calculation
	var yield_per_ha: float = float(crop.get("base_yield_kg_per_ha", 5000.0))
	var size_ha: float = field.get("size_ha", 1.0)
	var health_mod: float = clampf(GameState.land_health / 100.0, 0.25, 1.25)
	var field_mod: float = field.get("health_modifier", 1.0)
	var total_yield_kg: float = yield_per_ha * size_ha * health_mod * field_mod

	# Revenue
	var price_per_kg: float = GameState.market_prices.get(crop_id, float(crop.get("base_price", 0.20)))
	var revenue: float = total_yield_kg * price_per_kg

	GameState.modify_capital(revenue)
	GameState.modify_reputation(float(crop.get("reputation_on_harvest", 1.0)))
	GameState.clear_field(field_id)

	return revenue

# ── Market prices ─────────────────────────────────────────────────────────────

func update_market_prices() -> void:
	## Simple random walk. Called monthly by TurnManager.
	for crop_id: String in GameState.market_prices:
		var crop: Dictionary = GameState.crops_data.get(crop_id, {})
		var base: float = float(crop.get("base_price", 0.20))
		var current: float = GameState.market_prices[crop_id]
		var change: float = randf_range(-PRICE_WALK_MAX, PRICE_WALK_MAX)
		current = clampf(current * (1.0 + change), base * PRICE_MIN_FACTOR, base * PRICE_MAX_FACTOR)
		GameState.market_prices[crop_id] = current
