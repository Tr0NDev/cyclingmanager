extends Panel

@onready var vbox       := $ScrollContainer/VBoxContainer
@onready var filter_row := $FilterRow


var _filter: String = "all"  # all / past / upcoming


func _ready() -> void:
	_build_filters()


func show_calendar() -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	_display()
	show()


func _build_filters() -> void:
	for child in filter_row.get_children():
		child.queue_free()

	for f in [["all", "Toutes"], ["upcoming", "À venir"], ["past", "Passées"]]:
		var btn := Button.new()
		btn.text = f[1]
		btn.flat = _filter != f[0]
		btn.connect("pressed", func(): _on_filter(f[0]))
		filter_row.add_child(btn)


func _on_filter(f: String) -> void:
	_filter = f
	_build_filters()
	_display()


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()

	if Game.race_list.is_empty():
		var lbl := Label.new()
		lbl.text = "Aucune course chargée"
		vbox.add_child(lbl)
		return

	# Trie les courses par date
	var races := Game.race_list.duplicate()
	races.sort_custom(func(a, b): return _race_days(a) < _race_days(b))

	# Filtre
	var today := _date_to_days(Game.date["year"], Game.date["month"], Game.date["day"])
	if _filter == "upcoming":
		races = races.filter(func(r): return _race_days(r) >= today)
	elif _filter == "past":
		races = races.filter(func(r): return _race_days(r) < today)

	var current_month := -1

	for race in races:
		var parts: Array = race.date_in_season.split("-")
		if parts.size() < 2:
			continue
		var race_month: int = int(parts[0])
		var race_day:   int = int(parts[1])
		var race_days:  int = _race_days(race)
		var diff:       int = race_days - today

		# Séparateur de mois
		if race_month != current_month:
			current_month = race_month
			var month_lbl := Label.new()
			month_lbl.text = _month_name(race_month).to_upper()
			month_lbl.add_theme_font_size_override("font_size", 13)
			month_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
			vbox.add_child(month_lbl)
			vbox.add_child(HSeparator.new())

		vbox.add_child(_make_race_row(race, race_day, race_month, diff))


func _make_race_row(race: Race, day: int, month: int, diff: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.15, 1.15, 1.15))
	panel.mouse_exited.connect(func():  panel.modulate = Color(1, 1, 1))
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Utils.hideall()
			$"../Race".show_race(race)
	)

	var today := _date_to_days(Game.date["year"], Game.date["month"], Game.date["day"])
	var race_days := _race_days(race)
	if race_days < today:
		panel.modulate = Color(0.7, 0.7, 0.7)
	elif diff <= 7:
		panel.modulate = Color(1.0, 0.95, 0.8)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var logo := TextureRect.new()
	var tex := race.get_logo_texture()
	if tex:
		logo.texture = tex
	logo.custom_minimum_size   = Vector2(32, 32)
	logo.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode           = TextureRect.EXPAND_FIT_WIDTH
	logo.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(logo)

	var date_lbl := Label.new()
	date_lbl.text = "%02d/%02d" % [day, month]
	date_lbl.custom_minimum_size.x = 55
	date_lbl.add_theme_font_size_override("font_size", 12)
	date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(date_lbl)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl := Label.new()
	name_lbl.text = race.name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_lbl)

	var sub_lbl := Label.new()
	var tags: Array[String] = []
	tags.append(race.category)
	tags.append(race.country)
	if race.is_cobbled():          tags.append("🪨 Pavés")
	if race.is_hilly():            tags.append("⛰️ Vallonné")
	if race.is_mountain():         tags.append("🏔️ Montagne")
	if race.has_summit_finish():   tags.append("🏁 Sommet")
	sub_lbl.text = "  ·  ".join(tags)
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(sub_lbl)

	hbox.add_child(info_vbox)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size.x = 100
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if diff < 0:
		status_lbl.text = "Terminée"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	elif diff == 0:
		status_lbl.text = "Aujourd'hui !"
		status_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	elif diff <= 7:
		status_lbl.text = "Dans %d j" % diff
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.1))
	else:
		status_lbl.text = "Dans %d j" % diff
	hbox.add_child(status_lbl)

	var winner_lbl := Label.new()
	winner_lbl.text = "🏆 %s" % race.get_last_winner()
	winner_lbl.custom_minimum_size.x = 180
	winner_lbl.add_theme_font_size_override("font_size", 11)
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	winner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(winner_lbl)

	return panel


# ── Helpers ───────────────────────────────────────────────────
func _race_days(race: Race) -> int:
	var parts: Array = race.date_in_season.split("-")
	if parts.size() < 2:
		return 0
	return _date_to_days(Game.date["year"], int(parts[0]), int(parts[1]))

func refresh() -> void:
	if visible:
		_display()

func _date_to_days(year: int, month: int, day: int) -> int:
	var days := year * 365 + day
	for m in range(1, month):
		match m:
			1,3,5,7,8,10,12: days += 31
			4,6,9,11:         days += 30
			2:                days += 29 if Game.is_leap_year(year) else 28
	return days


func _month_name(m: int) -> String:
	match m:
		1:  return "Janvier"
		2:  return "Février"
		3:  return "Mars"
		4:  return "Avril"
		5:  return "Mai"
		6:  return "Juin"
		7:  return "Juillet"
		8:  return "Août"
		9:  return "Septembre"
		10: return "Octobre"
		11: return "Novembre"
		12: return "Décembre"
	return ""
