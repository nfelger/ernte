extends Control
## DebugOverlay — in-game developer tools panel.
##
## Toggled via the "⚙ Debug" button in the action bar. Slides up from the
## bottom. Contains all the runtime-tweak tools needed for rapid balancing
## iteration without restarting the game.
##
## Deliberately not behind a compile flag — it should always be accessible
## during prototype development.

var _crop_ids: Array[String] = []
var _event_ids: Array[String] = []

var _crop_drop: OptionButton
var _field_drop: OptionButton
var _event_drop: OptionButton
var _seed_field: LineEdit

func _ready() -> void:
	_build_ui()

func toggle_visible() -> void:
	if visible:
		hide()
	else:
		_refresh_dropdowns()
		show()

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	# Dark backdrop — tap outside panel to dismiss.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.68)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			hide()
	)
	add_child(backdrop)

	# Slide-up panel covering bottom 70% of screen.
	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.25
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.09, 0.09, 0.08, 0.98)
	panel_sb.corner_radius_top_left = 10
	panel_sb.corner_radius_top_right = 10
	panel.add_theme_stylebox_override("panel", panel_sb)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)

	var mc := MarginContainer.new()
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", 14)
	mc.add_theme_constant_override("margin_right", 14)
	mc.add_theme_constant_override("margin_top", 12)
	mc.add_theme_constant_override("margin_bottom", 14)
	outer.add_child(mc)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	mc.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = "⚙  Debug-Panel"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var close_btn := _btn("✕", func(): hide())
	title_row.add_child(close_btn)

	vbox.add_child(HSeparator.new())

	# Section: Zeit
	vbox.add_child(_section("Zeit"))
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	vbox.add_child(time_row)
	time_row.add_child(_wide_btn("+ Monat", func(): TurnManager.advance_month()))
	time_row.add_child(_wide_btn("+ Jahr (12 Mo.)", func(): TurnManager.advance_year()))

	vbox.add_child(HSeparator.new())

	# Section: Ressourcen
	vbox.add_child(_section("Ressourcen"))
	vbox.add_child(_resource_row("Kapital",   func(v): GameState.modify_capital(v),      5000.0, "€"))
	vbox.add_child(_resource_row("Boden",     func(v): GameState.modify_land_health(v),  10.0,   ""))
	vbox.add_child(_resource_row("Ruf",       func(v): GameState.modify_reputation(v),   10.0,   ""))

	vbox.add_child(HSeparator.new())

	# Section: Feld bepflanzen (debug plant without season/cost restrictions)
	vbox.add_child(_section("Feld bepflanzen (debug)"))
	var plant_row := HBoxContainer.new()
	plant_row.add_theme_constant_override("separation", 6)
	vbox.add_child(plant_row)

	_field_drop = OptionButton.new()
	_field_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_row.add_child(_field_drop)

	_crop_drop = OptionButton.new()
	_crop_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plant_row.add_child(_crop_drop)

	plant_row.add_child(_btn("OK", func():
		var fid: int = _field_drop.get_selected_id()
		if _crop_ids.is_empty() or _crop_drop.selected < 0:
			return
		var cid: String = _crop_ids[_crop_drop.selected]
		GameState.set_field_crop(fid, cid)
	))

	vbox.add_child(HSeparator.new())

	# Section: Ereignis erzwingen
	vbox.add_child(_section("Ereignis erzwingen"))
	var event_row := HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 6)
	vbox.add_child(event_row)

	_event_drop = OptionButton.new()
	_event_drop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_row.add_child(_event_drop)

	event_row.add_child(_btn("Auslösen", func():
		if _event_ids.is_empty() or _event_drop.selected < 0:
			return
		TurnManager.force_event(_event_ids[_event_drop.selected])
	))

	vbox.add_child(HSeparator.new())

	# Section: RNG-Seed
	vbox.add_child(_section("RNG-Seed (leer = random)"))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 6)
	vbox.add_child(seed_row)

	_seed_field = LineEdit.new()
	_seed_field.placeholder_text = "z. B. 42"
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_field)
	seed_row.add_child(_btn("Setzen", func():
		var t: String = _seed_field.text.strip_edges()
		if t.is_valid_int():
			seed(int(t))
		else:
			randomize()
	))

	vbox.add_child(HSeparator.new())

	# Section: Sonstiges
	vbox.add_child(_section("Sonstiges"))
	var misc_row := HBoxContainer.new()
	misc_row.add_theme_constant_override("separation", 8)
	vbox.add_child(misc_row)

	misc_row.add_child(_wide_btn("Daten neu laden", func():
		DataLoader.reload_content()
		_refresh_dropdowns()
	))
	var reset_btn := _wide_btn("Spiel zurücksetzen", func():
		GameState.reset_to_start()
		_refresh_dropdowns()
		hide()
	)
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	misc_row.add_child(reset_btn)

# ── Dropdown refresh ──────────────────────────────────────────────────────────

func _refresh_dropdowns() -> void:
	# Crops
	_crop_ids = []
	_crop_drop.clear()
	for crop_id: String in GameState.crops_data:
		var crop: Dictionary = GameState.crops_data[crop_id]
		_crop_drop.add_item(crop.get("name", crop_id))
		_crop_ids.append(crop_id)

	# Fields
	_field_drop.clear()
	for i in range(GameState.fields.size()):
		var field: Dictionary = GameState.fields[i]
		_field_drop.add_item(field.get("name", "Feld %d" % i), i)

	# Events
	_event_ids = []
	_event_drop.clear()
	for event: Dictionary in GameState.event_deck + GameState.event_discard:
		var eid: String = event.get("id", "?")
		_event_drop.add_item(event.get("title", eid))
		_event_ids.append(eid)

# ── Widget helpers ────────────────────────────────────────────────────────────

func _btn(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(callback)
	return b

func _wide_btn(label: String, callback: Callable) -> Button:
	var b := _btn(label, callback)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

func _section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.58))
	return lbl

func _resource_row(label_text: String, callback: Callable, amount: float, unit: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(64, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var minus := _btn("−%.0f%s" % [amount, unit], func(): callback.call(-amount))
	minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(minus)

	var plus := _btn("+%.0f%s" % [amount, unit], func(): callback.call(amount))
	plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(plus)

	return row
