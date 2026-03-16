extends Panel

const STAR_YELLOW := "res://data/image/yellow_star.png"
const STAR_GRAY := "res://data/image/gray_star.png"
const STAR_LEFT_HALF_YELLOW := "res://data/image/left_half_yellow_star.png"
const STAR_RIGHT_HALF_GRAY := "res://data/image/right_half_gray_star.png"
const STAR_BLUE := "res://data/image/blue_star.png"
const STAR_LEFT_HALF_BLUE := "res://data/image/left_half_blue_star.png"
const STAR_RIGHT_HALF_BLUE := "res://data/image/right_half_blue_star.png"

@onready var vbox := $ScrollContainer/VBoxContainer
@onready var search_bar := $FilterRow/SearchBar
@onready var filter_input := $FilterRow/FilterInput
@onready var sort_btns := $SortRow
@onready var hide_myteam_cb := $FilterRow/Hide
@onready var fav_only_cb := $FilterRow/FavOnly

var _hide_myteam: bool = false
var _fav_only: bool = false
var _all_riders: Array  = []
var _sort_by: String = ""
var _sort_asc: bool   = false
var _filter_rules: Array = []

const SORT_FIELDS := ["cob", "hll", "mtn", "gc", "itt", "spr", "age", "note", "potential"]
const SORT_LABELS := ["COB", "HLL", "MTN", "GC",  "ITT", "SPR", "Âge", "Note", "Potentiel"]


func _ready() -> void:
	search_bar.placeholder_text  = "Rechercher un coureur..."
	filter_input.placeholder_text = "ex: cob>60 age<26 mtn>70"
	search_bar.connect("text_changed",  _on_search)
	filter_input.connect("text_changed", _on_filter_changed)
	_build_sort_buttons()
	hide_myteam_cb.connect("toggled", func(val): _hide_myteam = val; _display())
	fav_only_cb.connect("toggled", func(val): _fav_only = val; _display())


func show_transfers() -> void:
	Utils.last_panel   = Utils.current_panel
	Utils.current_panel = self
	_load_all_riders()
	_display()
	show()


func _load_all_riders() -> void:
	_all_riders.clear()
	var dir := DirAccess.open("res://data/team/")
	if dir == null:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir():
			var team := Team.load_team(folder)
			for rider in team.riders:
				_all_riders.append(rider)
		folder = dir.get_next()
	dir.list_dir_end()


func _build_sort_buttons() -> void:
	for child in sort_btns.get_children():
		child.queue_free()
	for i in SORT_FIELDS.size():
		var field: String = SORT_FIELDS[i]
		var btn := Button.new()
		var arrow := ""
		if _sort_by == field:
			arrow = " ↑" if _sort_asc else " ↓"
		btn.text = SORT_LABELS[i] + arrow
		btn.connect("pressed", func(): _on_sort_pressed(field))
		sort_btns.add_child(btn)


func _get_sort_value(rider, field: String):
	match field:
		"cob": return rider.cob
		"hll": return rider.hll
		"mtn": return rider.mtn
		"gc": return rider.gc
		"itt": return rider.itt
		"spr": return rider.spr
		"age": return rider.age()
		"salary": return rider.salary
		"note": return (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
		"potential": return (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10
	return 0


func _sort_riders(riders: Array) -> Array:
	if _sort_by == "":
		return riders
	var sorted := riders.duplicate()
	sorted.sort_custom(func(a, b):
		var va = _get_sort_value(a, _sort_by)
		var vb = _get_sort_value(b, _sort_by)
		return va < vb if _sort_asc else va > vb
	)
	return sorted


func _parse_filters(text: String) -> Array:
	var rules: Array = []
	var tokens := text.strip_edges().split(" ", false)
	for token in tokens:
		for op in [">=", "<=", ">", "<", "="]:
			if token.contains(op):
				var parts := token.split(op, false)
				if parts.size() == 2:
					rules.append({
						"field": parts[0].strip_edges().to_lower(),
						"op":    op,
						"value": int(parts[1].strip_edges())
					})
				break
	return rules


func _passes_filters(rider, rules: Array) -> bool:
	for rule in rules:
		var val: int = _get_sort_value(rider, rule.field)
		var v: int   = rule.value
		match rule.op:
			">": if not val >  v: return false
			"<": if not val <  v: return false
			">=": if not val >= v: return false
			"<=": if not val <= v: return false
			"=": if not val == v: return false
	return true


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var q: String = search_bar.text.to_lower().strip_edges()
	var riders := _all_riders.duplicate()
	if _hide_myteam:
		riders = riders.filter(func(r): return r.team != Game.myteam)

	riders = riders.filter(func(r):
		var rname: String = r.full_name().to_lower()
		var rteam: String = r.team.to_lower()
		return q == "" or rname.contains(q) or rteam.contains(q)
	)

	if _filter_rules.size() > 0:
		riders = riders.filter(func(r): return _passes_filters(r, _filter_rules))
	
	if _fav_only:
		riders = riders.filter(func(r): return r.full_name() in Game.favoris)
	
	riders = _sort_riders(riders)

	for rider in riders:
		vbox.add_child(_make_row(rider))


func _on_search(_q: String) -> void:
	_display()


func _on_filter_changed(text: String) -> void:
	_filter_rules = _parse_filters(text)
	_display()


func _on_sort_pressed(field: String) -> void:
	if _sort_by == field:
		_sort_asc = not _sort_asc
	else:
		_sort_by  = field
		_sort_asc = false
	_build_sort_buttons()
	_display()


func _make_row(rider) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.2, 1.2, 1.2))
	panel.mouse_exited.connect(func():  panel.modulate = Color(1, 1, 1))
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_rider_pressed(rider)
	)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = rider.full_name()
	name_lbl.custom_minimum_size.x = 200
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var age_lbl := Label.new()
	age_lbl.text = str(rider.age()) + " ans"
	age_lbl.custom_minimum_size.x = 60
	age_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(age_lbl)
	
	var avg_current: int = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
	var avg_max: int     = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10

	var note_col := VBoxContainer.new()
	note_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_col.custom_minimum_size.x = 100

	var note_title := Label.new()
	note_title.text = "NOTE"
	note_title.add_theme_font_size_override("font_size", 10)
	note_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_col.add_child(note_title)

	var note_stars := _stars_node_dual(avg_current, avg_max)
	note_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_col.add_child(note_stars)
	hbox.add_child(note_col)

	for stat in [["COB", rider.cob], ["HLL", rider.hll], ["MTN", rider.mtn],
				 ["GC",  rider.gc],  ["ITT", rider.itt], ["SPR", rider.spr]]:
		var lbl := Label.new()
		lbl.text = "%s:%d" % [stat[0], stat[1]]
		lbl.custom_minimum_size.x = 65
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", _stat_color(stat[1]))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)

	return panel


func _on_rider_pressed(rider) -> void:
	Utils.hideall()
	$"../Rider".show_rider(rider)


func _stat_color(value: int) -> Color:
	if value >= 85: return Color(0.2, 0.9, 0.3)
	if value >= 70: return Color(0.6, 0.85, 0.2)
	if value >= 55: return Color(0.95, 0.75, 0.1)
	if value >= 40: return Color(0.9, 0.45, 0.1)
	return Color(0.85, 0.2, 0.2)


func _stars_node_dual(value: int, max_value: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var val_float  := float(value)     / 19.0
	var max_float  := float(max_value) / 19.0

	var full_yellow := int(val_float)
	var half_yellow := 1 if (val_float - full_yellow) >= 0.25 else 0
	var full_max    := int(max_float)
	var half_max    := 1 if (max_float - full_max) >= 0.25 else 0

	var full_blue_start := full_yellow + half_yellow
	var full_blue   := maxi(full_max - full_blue_start, 0)
	var half_blue   := half_max if (full_max >= full_blue_start + full_blue) else 0
	var empty       := maxi(5 - full_yellow - half_yellow - full_blue - half_blue, 0)

	for i in full_yellow:
		hb.add_child(_star_img(STAR_YELLOW))
	if half_yellow:
		hb.add_child(_star_img(STAR_LEFT_HALF_YELLOW, 8))
		hb.add_child(_star_img(STAR_RIGHT_HALF_BLUE if full_blue > 0 or half_blue > 0 else STAR_RIGHT_HALF_GRAY, 8))
	for i in full_blue:
		hb.add_child(_star_img(STAR_BLUE))
	if half_blue:
		hb.add_child(_star_img(STAR_LEFT_HALF_BLUE, 8))
		hb.add_child(_star_img(STAR_RIGHT_HALF_GRAY, 8))
	for i in empty:
		hb.add_child(_star_img(STAR_GRAY))

	return hb


func _star_img(path: String, width: int = 16) -> TextureRect:
	var img := TextureRect.new()
	img.texture = load(path)
	img.custom_minimum_size = Vector2(width, 16)
	img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return img
