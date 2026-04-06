extends Control
## MainScreen — the entire game UI, built programmatically.
##
## Why code-driven UI? Avoids Godot's text scene format complexity, keeps
## everything readable in one place, and makes tweaks to layout/colors
## trivial without opening the editor. For a prototype, this tradeoff is fine.
##
## Architecture: this script READS from GameState and calls TurnManager /
## RulesEngine. It never writes to GameState directly.

const DebugOverlayScene: PackedScene = preload("res://scenes/ui/debug_overlay.tscn")

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG        := Color(0.11, 0.11, 0.09)
const C_PANEL     := Color(0.17, 0.17, 0.14)
const C_PANEL_ALT := Color(0.14, 0.13, 0.11)
const C_ACCENT    := Color(0.78, 0.67, 0.38)
const C_TEXT      := Color(0.91, 0.89, 0.84)
const C_MUTED     := Color(0.52, 0.50, 0.46)

# Field status colours
const C_FALLOW   := Color(0.18, 0.16, 0.12)
const C_GROWING  := Color(0.10, 0.19, 0.10)
const C_READY    := Color(0.19, 0.19, 0.06)
const C_WITHERED := Color(0.21, 0.09, 0.07)

# ── Node refs ─────────────────────────────────────────────────────────────────

var _time_label: Label
var _capital_bar: ProgressBar
var _capital_label: Label
var _land_bar: ProgressBar
var _land_label: Label
var _rep_bar: ProgressBar
var _rep_label: Label
var _field_cards: Array = []      # Array of Panel nodes
var _event_title: Label
var _event_text: Label
var _btn_plant: Button
var _btn_harvest: Button
var _btn_sell: Button
var _debug_overlay: Control

var _selected_field: int = -1

# Crop selection overlay nodes
var _crop_overlay: ColorRect
var _crop_content: VBoxContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_refresh_all()

# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background fill
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main vertical layout
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_resources())

	var fields_panel := _build_fields()
	fields_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(fields_panel)

	root.add_child(_build_event_panel())
	root.add_child(_build_actions())

	# Crop overlay (hidden, shown on Plant)
	_build_crop_overlay()

	# Debug overlay (loaded from scene, hidden)
	_debug_overlay = DebugOverlayScene.instantiate()
	_debug_overlay.z_index = 100
	add_child(_debug_overlay)

# ── Header ────────────────────────────────────────────────────────────────────

func _build_header() -> Control:
	var panel := _panel(C_PANEL)
	panel.custom_minimum_size = Vector2(0, 46)

	_time_label = Label.new()
	_time_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 17)
	_time_label.add_theme_color_override("font_color", C_ACCENT)
	panel.add_child(_time_label)

	return panel

# ── Resource bars ─────────────────────────────────────────────────────────────

func _build_resources() -> Control:
	var panel := _panel(C_PANEL)
	panel.custom_minimum_size = Vector2(0, 88)

	var mc := _margin(panel, 10, 10, 6, 6)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	mc.add_child(vbox)

	var cap := _res_row("Kapital", Color(0.35, 0.65, 0.35))
	_capital_bar = cap[0]; _capital_label = cap[1]
	vbox.add_child(cap[2])

	var land := _res_row("Boden", Color(0.58, 0.48, 0.28))
	_land_bar = land[0]; _land_label = land[1]
	vbox.add_child(land[2])

	var rep := _res_row("Ruf", Color(0.35, 0.48, 0.72))
	_rep_bar = rep[0]; _rep_label = rep[1]
	vbox.add_child(rep[2])

	return panel

func _res_row(title: String, bar_color: Color) -> Array:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(68, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_MUTED)
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0; bar.max_value = 100.0; bar.value = 50.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 20)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.07, 0.07, 0.06)
	bg_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_sb)
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = bar_color
	fill_sb.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_sb)
	hbox.add_child(bar)

	var val := Label.new()
	val.custom_minimum_size = Vector2(72, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", C_TEXT)
	hbox.add_child(val)

	return [bar, val, hbox]

# ── Field grid ────────────────────────────────────────────────────────────────

func _build_fields() -> Control:
	var panel := _panel(Color(0.09, 0.09, 0.08))

	var mc := _margin(panel, 7, 7, 5, 5)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	mc.add_child(grid)

	_field_cards = []
	for i in range(6):
		var card := _build_field_card(i)
		grid.add_child(card)
		_field_cards.append(card)

	return panel

func _build_field_card(field_id: int) -> Button:
	var card := Button.new()
	card.flat = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 76)
	card.pressed.connect(func(): _on_field_tapped(field_id))

	# Content container — MOUSE_FILTER_IGNORE so clicks reach the Button.
	var mc := _margin(card, 6, 6, 4, 4)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 1)
	mc.add_child(vbox)

	var name_lbl  := _field_label(13, C_ACCENT)
	var crop_lbl  := _field_label(12, C_TEXT)
	var stat_lbl  := _field_label(11, C_MUTED)
	var size_lbl  := _field_label(10, C_MUTED)
	vbox.add_child(name_lbl)
	vbox.add_child(crop_lbl)
	vbox.add_child(stat_lbl)
	vbox.add_child(size_lbl)

	# Store refs via metadata for update calls.
	card.set_meta("lbl_name", name_lbl)
	card.set_meta("lbl_crop", crop_lbl)
	card.set_meta("lbl_stat", stat_lbl)
	card.set_meta("lbl_size", size_lbl)

	return card

func _field_label(size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl

# ── Event panel ───────────────────────────────────────────────────────────────

func _build_event_panel() -> Control:
	var panel := _panel(C_PANEL_ALT)
	panel.custom_minimum_size = Vector2(0, 100)

	var mc := _margin(panel, 12, 12, 8, 8)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	mc.add_child(vbox)

	_event_title = Label.new()
	_event_title.add_theme_font_size_override("font_size", 14)
	_event_title.add_theme_color_override("font_color", C_ACCENT)
	_event_title.text = "— Almanach —"
	vbox.add_child(_event_title)

	_event_text = Label.new()
	_event_text.add_theme_font_size_override("font_size", 12)
	_event_text.add_theme_color_override("font_color", C_TEXT)
	_event_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_event_text.text = "Kein Ereignis. Das Wetter ist unbemerkenswert."
	vbox.add_child(_event_text)

	return panel

# ── Action bar ────────────────────────────────────────────────────────────────

func _build_actions() -> Control:
	var panel := _panel(C_PANEL)
	panel.custom_minimum_size = Vector2(0, 118)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var mc := MarginContainer.new()
	mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mc.add_theme_constant_override("margin_left", 8)
	mc.add_theme_constant_override("margin_right", 8)
	mc.add_theme_constant_override("margin_top", 6)
	mc.add_theme_constant_override("margin_bottom", 0)
	vbox.add_child(mc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	mc.add_child(grid)

	_btn_plant   = _action_btn("Pflanzen",       Color(0.28, 0.52, 0.28))
	_btn_harvest = _action_btn("Ernten",          Color(0.58, 0.48, 0.18))
	_btn_sell    = _action_btn("Verkaufen",       Color(0.28, 0.38, 0.58))
	var btn_end  = _action_btn("Monat beenden ›", Color(0.52, 0.22, 0.22))

	_btn_plant.pressed.connect(_on_plant_pressed)
	_btn_harvest.pressed.connect(_on_harvest_pressed)
	_btn_sell.pressed.connect(_on_sell_pressed)
	btn_end.pressed.connect(TurnManager.advance_month)

	grid.add_child(_btn_plant)
	grid.add_child(_btn_harvest)
	grid.add_child(_btn_sell)
	grid.add_child(btn_end)

	# Debug toggle — small footer button.
	var dbg_btn := Button.new()
	dbg_btn.text = "⚙ Debug"
	dbg_btn.flat = true
	dbg_btn.custom_minimum_size = Vector2(0, 28)
	dbg_btn.add_theme_font_size_override("font_size", 11)
	dbg_btn.add_theme_color_override("font_color", C_MUTED)
	dbg_btn.pressed.connect(func(): _debug_overlay.toggle_visible())
	vbox.add_child(dbg_btn)

	return panel

func _action_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 14)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = color * 0.72
	normal_sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal_sb)

	var active_sb := StyleBoxFlat.new()
	active_sb.bg_color = color
	active_sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", active_sb)
	btn.add_theme_stylebox_override("pressed", active_sb)

	var dis_sb := StyleBoxFlat.new()
	dis_sb.bg_color = Color(0.18, 0.18, 0.17)
	dis_sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("disabled", dis_sb)

	return btn

# ── Crop selection overlay ────────────────────────────────────────────────────

func _build_crop_overlay() -> void:
	_crop_overlay = ColorRect.new()
	_crop_overlay.color = Color(0, 0, 0, 0.72)
	_crop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crop_overlay.z_index = 50
	_crop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_crop_overlay.visible = false
	add_child(_crop_overlay)

	# Panel covering the lower 60% of screen.
	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.35
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0; panel.offset_top = 0
	panel.offset_right = 0; panel.offset_bottom = 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.12)
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	panel.add_theme_stylebox_override("panel", sb)
	_crop_overlay.add_child(panel)

	var mc := _margin(panel, 14, 14, 12, 12)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_child(scroll)

	_crop_content = VBoxContainer.new()
	_crop_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crop_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_crop_content)

func _show_crop_overlay() -> void:
	# Clear previous crop buttons.
	for child in _crop_content.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Welche Frucht pflanzen?"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", C_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crop_content.add_child(title)

	var season := GameState.get_current_season()

	for crop_id: String in GameState.crops_data:
		var crop: Dictionary = GameState.crops_data[crop_id]
		var valid_seasons: Array = crop.get("plant_seasons", [])
		var in_season: bool = valid_seasons.is_empty() or season in valid_seasons
		var cost: float = float(crop.get("seed_cost", 0.0))
		var affordable: bool = GameState.capital >= cost

		var btn := Button.new()
		var season_tag := "" if in_season else " [falsche Saison]"
		btn.text = "%s — €%.0f Saatgut%s" % [crop.get("name", crop_id), cost, season_tag]
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = not in_season or not affordable
		btn.pressed.connect(func(): _do_plant(crop_id))
		_crop_content.add_child(btn)

		# Small description line
		var desc := Label.new()
		desc.text = crop.get("description", "")
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", C_MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_crop_content.add_child(desc)

	var cancel := Button.new()
	cancel.text = "Abbrechen"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(func(): _crop_overlay.visible = false)
	_crop_content.add_child(cancel)

	_crop_overlay.visible = true

func _do_plant(crop_id: String) -> void:
	_crop_overlay.visible = false
	if RulesEngine.do_plant(_selected_field, crop_id):
		pass  # State change triggers _refresh_all via signal.

# ── Signal connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	GameState.state_changed.connect(_refresh_all)
	GameState.event_triggered.connect(_on_event_triggered)

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	_update_header()
	_update_resources()
	_update_fields()
	_update_action_buttons()

func _update_header() -> void:
	_time_label.text = "%s %d  ·  %s" % [
		GameState.get_month_name(),
		GameState.get_display_year(),
		GameState.get_current_season()
	]

func _update_resources() -> void:
	_capital_bar.max_value = 200000.0
	_capital_bar.value = minf(GameState.capital, 200000.0)
	_capital_label.text = _fmt_money(GameState.capital)

	_land_bar.value = GameState.land_health
	_land_label.text = "%d / 100" % int(GameState.land_health)

	_rep_bar.value = GameState.reputation
	_rep_label.text = "%d / 100" % int(GameState.reputation)

func _update_fields() -> void:
	for i in range(_field_cards.size()):
		_update_field_card(i)

func _update_field_card(field_id: int) -> void:
	var card: Button = _field_cards[field_id]
	var field: Dictionary = GameState.get_field(field_id)
	if field.is_empty():
		return

	var name_lbl: Label = card.get_meta("lbl_name")
	var crop_lbl: Label = card.get_meta("lbl_crop")
	var stat_lbl: Label = card.get_meta("lbl_stat")
	var size_lbl: Label = card.get_meta("lbl_size")

	name_lbl.text = field.get("name", "Feld %d" % (field_id + 1))
	size_lbl.text = "%.1f ha" % field.get("size_ha", 0.0)

	var crop_id: String = field.get("planted_crop", "")
	var status: String = field.get("status", "fallow")

	if crop_id == "":
		crop_lbl.text = "Brache"
		crop_lbl.add_theme_color_override("font_color", C_MUTED)
	else:
		var crop: Dictionary = GameState.crops_data.get(crop_id, {})
		crop_lbl.text = crop.get("name", crop_id)
		crop_lbl.add_theme_color_override("font_color", C_TEXT)

	var stat_text: String; var stat_color: Color
	match status:
		"fallow":
			stat_text = "Brache"; stat_color = C_MUTED
		"planted":
			stat_text = "Gesät"; stat_color = Color(0.6, 0.8, 0.5)
		"growing":
			stat_text = "Wächst (%d Mo.)" % field.get("months_grown", 0)
			stat_color = Color(0.5, 0.78, 0.38)
		"ready":
			stat_text = "Erntereif ✓"; stat_color = Color(0.9, 0.82, 0.2)
		"withered":
			stat_text = "Verkümmert"; stat_color = Color(0.8, 0.32, 0.22)
		_:
			stat_text = status; stat_color = C_MUTED
	stat_lbl.text = stat_text
	stat_lbl.add_theme_color_override("font_color", stat_color)

	_style_field_card(card, status, field_id == _selected_field)

func _style_field_card(card: Button, status: String, selected: bool) -> void:
	var bg: Color
	match status:
		"fallow":                bg = C_FALLOW
		"planted", "growing":   bg = C_GROWING
		"ready":                 bg = C_READY
		"withered":              bg = C_WITHERED
		_:                       bg = C_PANEL

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	if selected:
		sb.border_color = C_ACCENT
		sb.set_border_width_all(2)

	card.add_theme_stylebox_override("normal", sb)
	var hover_sb: StyleBoxFlat = sb.duplicate()
	hover_sb.bg_color = bg.lightened(0.08)
	card.add_theme_stylebox_override("hover", hover_sb)
	card.add_theme_stylebox_override("pressed", hover_sb)
	card.add_theme_stylebox_override("focus", sb)

func _update_action_buttons() -> void:
	var field: Dictionary = GameState.get_field(_selected_field)
	var status: String = field.get("status", "") if not field.is_empty() else ""

	_btn_plant.disabled   = field.is_empty() or status != "fallow"
	_btn_harvest.disabled = field.is_empty() or status != "ready"
	_btn_sell.disabled    = true   # Placeholder; wire up market screen later.

# ── Action handlers ───────────────────────────────────────────────────────────

func _on_field_tapped(field_id: int) -> void:
	_selected_field = field_id if _selected_field != field_id else -1
	_update_fields()
	_update_action_buttons()

func _on_plant_pressed() -> void:
	if _selected_field < 0:
		return
	_show_crop_overlay()

func _on_harvest_pressed() -> void:
	if _selected_field < 0:
		return
	var field_name: String = GameState.get_field(_selected_field).get("name", "Feld")
	var revenue: float = RulesEngine.do_harvest(_selected_field)
	if revenue > 0.0:
		_event_title.text = "Ernte eingebracht"
		_event_text.text = "%s: %.0f EUR Erlös." % [field_name, revenue]

func _on_sell_pressed() -> void:
	_event_title.text = "Markt"
	_event_text.text = "Direktverkauf — noch nicht implementiert. Kommt bald."

func _on_event_triggered(event_data: Dictionary) -> void:
	_event_title.text = event_data.get("title", "Ereignis")
	_event_text.text  = event_data.get("text", "")

# ── Helpers ───────────────────────────────────────────────────────────────────

func _panel(color: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	p.add_theme_stylebox_override("panel", sb)
	return p

func _margin(parent: Control, l: int, r: int, t: int, b: int) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", l)
	mc.add_theme_constant_override("margin_right", r)
	mc.add_theme_constant_override("margin_top", t)
	mc.add_theme_constant_override("margin_bottom", b)
	parent.add_child(mc)
	return mc

func _fmt_money(amount: float) -> String:
	if amount >= 1000000.0:
		return "€%.1fM" % (amount / 1000000.0)
	if amount >= 1000.0:
		return "€%.1fk" % (amount / 1000.0)
	return "€%.0f" % amount
