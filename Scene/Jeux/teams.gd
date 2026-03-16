extends Panel

@onready var vbox      := $ScrollContainer/VBoxContainer
@onready var panelteam := $"../Team"
@onready var sort_btn  := $SortOption

var _teams: Array = []
var _sort_options := ["name", "uci", "budget", "popularity"]
var _sort_labels := ["Nom", "UCI", "Budget", "Popularité"]
var _sort_index := 0
var _sort_by := "name"


func _ready() -> void:
	sort_btn.text = "Trier : Nom"
	sort_btn.connect("pressed", _on_sort_pressed)


func _on_sort_pressed() -> void:
	_sort_index = (_sort_index + 1) % _sort_options.size()
	_sort_by    = _sort_options[_sort_index]
	sort_btn.text = "Trier : " + _sort_labels[_sort_index]
	_display()


func show_teams() -> void:
	Utils.last_panel = Utils.current_panel
	Utils.current_panel = self
	_load_teams()
	_display()
	show()


func _load_teams() -> void:
	_teams.clear()
	var dir := DirAccess.open("res://data/team/")
	if dir == null:
		push_error("TeamList: impossible d'ouvrir res://data/team/")
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir():
			_teams.append(Team.load_team(folder))
		folder = dir.get_next()
	dir.list_dir_end()


func _sort_teams() -> Array:
	var sorted := _teams.duplicate()
	sorted.sort_custom(func(a, b):
		match _sort_by:
			"uci":        return a.uci > b.uci
			"budget":     return a.budget > b.budget
			"popularity": return a.popularity > b.popularity
			_:            return a.teamname < b.teamname
	)
	return sorted


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()
	for team in _sort_teams():
		vbox.add_child(_make_row(team))


func _make_row(team: Team) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.3, 1.3, 1.3))
	panel.mouse_exited.connect(func():  panel.modulate = Color(1, 1, 1))
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_team_pressed(team.folder)
	)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var logo_path := "res://data/team/%s/images/logo.png" % team.folder
	if ResourceLoader.exists(logo_path):
		var logo := TextureRect.new()
		logo.texture = load(logo_path)
		logo.custom_minimum_size = Vector2(40, 40)
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(logo)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl := Label.new()
	name_lbl.text = team.teamname
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var info_lbl := Label.new()
	info_lbl.text = "%s  ·  %s  ·  UCI: %d pts" % [team.country, team.category, team.uci]
	info_lbl.add_theme_font_size_override("font_size", 11)
	info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(info_lbl)

	var budget_lbl := Label.new()
	budget_lbl.text = "Budget: %s €  ·  Popularité: %d  ·  Dir: %s" % [
		_fmt_number(team.budget), team.popularity, team.director
	]
	budget_lbl.add_theme_font_size_override("font_size", 11)
	budget_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(budget_lbl)

	hbox.add_child(vb)

	var stats_vb := VBoxContainer.new()
	stats_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_vb.add_theme_constant_override("separation", 2)
	stats_vb.custom_minimum_size.x = 220

	var riders_lbl := Label.new()
	riders_lbl.text = "Coureurs : %d" % team.rider_count()
	riders_lbl.add_theme_font_size_override("font_size", 11)
	riders_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_vb.add_child(riders_lbl)

	var transfer_lbl := Label.new()
	transfer_lbl.text = "Transferts : %d%%" % team.transfer_budget
	transfer_lbl.add_theme_font_size_override("font_size", 11)
	transfer_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_vb.add_child(transfer_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = "Objectifs : %s" % ", ".join(team.objectives)
	obj_lbl.add_theme_font_size_override("font_size", 11)
	obj_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	stats_vb.add_child(obj_lbl)

	hbox.add_child(stats_vb)

	return panel


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


func _on_team_pressed(team: String) -> void:
	Utils.hideall()
	panelteam.show_team(team)
	panelteam.show()
