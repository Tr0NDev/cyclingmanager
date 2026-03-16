extends Panel

@onready var vbox := $ScrollContainer/VBoxContainer


func show_sponsors() -> void:
	Utils.last_panel = Utils.current_panel
	Utils.current_panel = self
	_display()
	show()


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var team := Team.load_team(Game.myteam)
	vbox.add_child(_section("SPONSORS"))

	for sponsor_name in team.sponsors.keys():
		var val              = team.sponsors[sponsor_name]
		var montant: int     = int(val[0])
		var type: String     = val[1]
		var objectif: String = val[2] if val.size() > 2 else ""
		vbox.add_child(_make_row(sponsor_name, montant, type, objectif))


func _make_row(sponsor_name: String, montant: int, type: String, objectif: String) -> PanelContainer:
	var panel := PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	panel.add_child(hbox)

	var img_path := "res://data/image/sponsor/%s.png" % sponsor_name.to_lower().replace(" ", "-")
	var logo := TextureRect.new()
	logo.custom_minimum_size = Vector2(80, 48)
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode  = TextureRect.EXPAND_FIT_WIDTH
	if ResourceLoader.exists(img_path):
		logo.texture = load(img_path)
	else:
		logo.texture = load("res://data/image/sponsor/unknown.png")
	hbox.add_child(logo)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = sponsor_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	vb.add_child(name_lbl)

	var type_lbl := Label.new()
	type_lbl.text = type
	type_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(type_lbl)

	if objectif != "":
		var obj_lbl := Label.new()
		obj_lbl.text = "🎯 " + _parse_objectif(objectif)
		obj_lbl.add_theme_font_size_override("font_size", 11)
		obj_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
		vb.add_child(obj_lbl)

	hbox.add_child(vb)

	var montant_lbl := Label.new()
	montant_lbl.text = _fmt(montant) + " €"
	montant_lbl.add_theme_font_size_override("font_size", 14)
	montant_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	montant_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(montant_lbl)

	return panel


func _parse_objectif(code: String) -> String:
	match code:
		"5-GT":    return "Top 5 Grand Tour"
		"4-star":  return "Avoir un coureur 4 étoiles"
		"3-GT":    return "Top 3 Grand Tour"
		"win-GT":  return "Gagner un Grand Tour"
		"win-mon": return "Gagner un Monument"
		_:         return code


func _section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl


func _fmt(n: int) -> String:
	var s: String = str(n)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = s[i] + result
		count += 1
	return result
