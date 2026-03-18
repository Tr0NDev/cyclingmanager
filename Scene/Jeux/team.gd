extends Panel

const STAR_YELLOW           := "res://data/image/yellow_star.png"
const STAR_GRAY             := "res://data/image/gray_star.png"
const STAR_LEFT_HALF_YELLOW := "res://data/image/left_half_yellow_star.png"
const STAR_RIGHT_HALF_GRAY  := "res://data/image/right_half_gray_star.png"
const STAR_BLUE             := "res://data/image/blue_star.png"
const STAR_LEFT_HALF_BLUE   := "res://data/image/left_half_blue_star.png"
const STAR_RIGHT_HALF_BLUE  := "res://data/image/right_half_blue_star.png"

@onready var scroll      := $ScrollContainer
@onready var vbox        := $ScrollContainer/VBoxContainer
@onready var logo        := $TeamLogo
@onready var teamname    := $TeamLabel
@onready var info_label  := $InfoLabel
@onready var sort_btns   := $SortRow
@onready var mercato_vbox := $Mercato/VBoxContainer

const SORT_FIELDS := ["cob", "hll", "mtn", "gc", "itt", "spr", "age", "note", "potential"]
const SORT_LABELS := ["COB", "HLL", "MTN", "GC",  "ITT", "SPR", "Âge", "Note", "Potentiel"]

var _current_riders: Array = []
var _sort_by:  String = ""
var _sort_asc: bool   = false


func _ready() -> void:
	_build_sort_buttons()


func show_team(team_folder: String) -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	var team := Team.load_team(team_folder)

	var logo_path := "res://data/team/%s/images/logo.png" % team_folder
	if ResourceLoader.exists(logo_path):
		logo.texture = load(logo_path)
	logo.expand_mode           = TextureRect.EXPAND_FIT_WIDTH
	logo.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size   = Vector2(64, 64)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	teamname.text = team.teamname

	var sponsors_str   := ", ".join(team.sponsors.keys())
	var objectives_str := ", ".join(team.objectives)

	_current_riders = team.riders
	_display()
	show()
	_display_transfers(team_folder)


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


func _on_sort_pressed(field: String) -> void:
	if _sort_by == field:
		_sort_asc = not _sort_asc
	else:
		_sort_by  = field
		_sort_asc = false
	_build_sort_buttons()
	_display()


func _get_sort_value(rider, field: String):
	match field:
		"cob":    return rider.cob
		"hll":    return rider.hll
		"mtn":    return rider.mtn
		"gc":     return rider.gc
		"itt":    return rider.itt
		"spr":    return rider.spr
		"age":    return rider.age()
		"note":      return (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
		"potential": return (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10
	return 0


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var riders := _current_riders.duplicate()
	if _sort_by != "":
		riders.sort_custom(func(a, b):
			var va = _get_sort_value(a, _sort_by)
			var vb = _get_sort_value(b, _sort_by)
			return va < vb if _sort_asc else va > vb
		)

	for rider in riders:
		vbox.add_child(_make_row(rider))


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

	var name_label := Label.new()
	name_label.text = rider.full_name()
	name_label.custom_minimum_size.x = 200
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_label)

	var age_label := Label.new()
	age_label.text = str(rider.age()) + " ans"
	age_label.custom_minimum_size.x = 60
	age_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(age_label)

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

	var form_label := Label.new()
	form_label.text = "Form:%d" % rider.form
	form_label.custom_minimum_size.x = 70
	form_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(form_label)

	var injury_label := Label.new()
	injury_label.text = "🤕 %d j" % rider.injury if rider.is_injured() else "✅"
	injury_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(injury_label)

	return panel


func _display_transfers(team_folder: String) -> void:
	for child in mercato_vbox.get_children():
		child.queue_free()

	var arrivals := []
	var departures := []

	for t in Game.transfers_log:
		if t["to"] == team_folder:
			arrivals.append(t)
		elif t["from"] == team_folder:
			departures.append(t)

	if arrivals.is_empty() and departures.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucun transfert"
		mercato_vbox.add_child(empty_lbl)
		return

	if not arrivals.is_empty():
		mercato_vbox.add_child(_section_label("ARRIVÉES"))
		for t in arrivals:
			var btn := Button.new()
			btn.text = "🟢 ← %s" % t["name"]
			btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.connect("pressed", func():
				var rider = _find_rider(t["name"])
				if rider:
					Utils.hideall()
					$"../Rider".show_rider(rider)
			)
			mercato_vbox.add_child(btn)

	if not departures.is_empty():
		mercato_vbox.add_child(_section_label("DÉPARTS"))
		for t in departures:
			var btn := Button.new()
			btn.text = "🔴 → %s" % t["name"]
			btn.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
			btn.flat = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.connect("pressed", func():
				var rider = _find_rider(t["name"])
				if rider:
					Utils.hideall()
					$"../Rider".show_rider(rider)
			)
			mercato_vbox.add_child(btn)

func _section_label(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl

func _separator() -> HSeparator:
	return HSeparator.new()

func _find_rider(full_name: String):
	for team in Game.team_list:
		var r = team.get_rider_by_name(full_name)
		if r:
			return r
	var mt := Team.load_team(Game.myteam)
	return mt.get_rider_by_name(full_name)

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


func _fmt_number(n: int) -> String:
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = s[i] + result
		count += 1
	return result
