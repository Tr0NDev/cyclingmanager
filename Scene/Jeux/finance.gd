extends Panel

@onready var vbox       := $ScrollContainer/VBoxContainer
@onready var graph_hbox := $GraphHBox


func show_finance() -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	_display()
	show()


func _display() -> void:
	for child in vbox.get_children():
		child.queue_free()

	var team := Team.load_team(Game.myteam)

	var total_salaires := 0
	for rider in team.riders:
		total_salaires += rider.salary

	var total_sponsors := 0
	for val in team.sponsors.values():
		total_sponsors += int(val[0])

	var budget_transfer: int = team.budget_transfer
	var budget_salary:   int = team.budget_salary
	var reste_salaires:  int = budget_salary - total_salaires
	var reste_transfert: int = budget_transfer

	var cout_en_cours: int = 0
	for rider_name in Game.transfer_offers.keys():
		for offer in Game.transfer_offers[rider_name]:
			if offer["team"] == Game.myteam:
				cout_en_cours += offer["salary"]
	reste_transfert -= cout_en_cours

	_draw_graph_revenus(total_sponsors, team.budget)
	_draw_graph_depenses(total_salaires, budget_transfer)

	vbox.add_child(_section("BUDGET"))
	vbox.add_child(_row("Budget total", _fmt(team.budget) + " €"))

	var sal_row := _row("Budget salaires", _fmt(budget_salary) + " €")
	if total_salaires > 0:
		var used_lbl := Label.new()
		used_lbl.text = "  (%s € utilisés)" % _fmt(total_salaires)
		used_lbl.add_theme_color_override("font_color",
			Color(0.9, 0.2, 0.2) if reste_salaires < 0 else Color(0.6, 0.6, 0.6))
		sal_row.add_child(used_lbl)
	vbox.add_child(sal_row)

	var bt_row := _row("Budget transferts", _fmt(budget_transfer) + " €")
	if cout_en_cours > 0:
		var eng_lbl := Label.new()
		eng_lbl.text = "  (-%s € engagés)" % _fmt(cout_en_cours)
		eng_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		bt_row.add_child(eng_lbl)
	vbox.add_child(bt_row)

	var solde_sal_row := _row("Reste salaires", _fmt(reste_salaires) + " €")
	solde_sal_row.get_child(1).add_theme_color_override("font_color",
		Color(0.9, 0.2, 0.2) if reste_salaires < 0 else Color(0.2, 0.85, 0.3))
	vbox.add_child(solde_sal_row)

	vbox.add_child(_separator())

	vbox.add_child(_section("SPONSORS"))
	for sponsor_name in team.sponsors.keys():
		var val = team.sponsors[sponsor_name]
		var montant: int = int(val[0])
		var type: String = val[1]
		vbox.add_child(_row(sponsor_name, "%s €  ·  %s" % [_fmt(montant), type]))
	vbox.add_child(_separator())

	vbox.add_child(_section("RÉPARTITION BUDGET"))
	var pct_salaires:  int = int(float(total_salaires) / float(team.budget) * 100.0) if team.budget > 0 else 0
	var pct_transfert: int = int(float(budget_transfer) / float(team.budget) * 100.0) if team.budget > 0 else 0
	var pct_autre:     int = maxi(100 - pct_salaires - pct_transfert, 0)
	vbox.add_child(_row("Salaires",   "%d%%" % pct_salaires))
	vbox.add_child(_row("Transferts", "%d%%" % pct_transfert))
	vbox.add_child(_row("Autre",      "%d%%" % pct_autre))


func _draw_graph_revenus(sponsors: int, budget: int) -> void:
	for child in graph_hbox.get_children():
		child.queue_free()

	var max_val := maxi(sponsors, budget)
	_add_bar(graph_hbox, "Sponsors", sponsors, Color(0.2, 0.85, 0.3), max_val)
	_add_bar(graph_hbox, "Budget",   budget,   Color(0.3, 0.6,  1.0), max_val)

	var total_lbl := Label.new()
	total_lbl.text = "Total : %s €" % _fmt(sponsors + budget)
	total_lbl.add_theme_font_size_override("font_size", 11)
	total_lbl.add_theme_color_override("font_color", Color(0.2, 0.85, 0.3))
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	graph_hbox.add_child(total_lbl)


func _draw_graph_depenses(salaires: int, transferts: int) -> void:
	var max_val := maxi(salaires, transferts)
	graph_hbox.add_child(VSeparator.new())
	_add_bar(graph_hbox, "Salaires",   salaires,   Color(0.9, 0.3,  0.3), max_val)
	_add_bar(graph_hbox, "Transferts", transferts, Color(0.9, 0.65, 0.1), max_val)

	var total_lbl := Label.new()
	total_lbl.text = "Total : %s €" % _fmt(salaires + transferts)
	total_lbl.add_theme_font_size_override("font_size", 11)
	total_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	graph_hbox.add_child(total_lbl)


func _add_bar(parent: HBoxContainer, label: String, value: int, color: Color, max_val: int) -> void:
	const BAR_H := 120.0
	var pct: float = float(value) / float(max_val) if max_val > 0 else 0.0

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)

	var val_lbl := Label.new()
	val_lbl.text = _fmt(value) + " €"
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_color_override("font_color", color)
	col.add_child(val_lbl)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, BAR_H)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(bg)

	var bar := ColorRect.new()
	bar.color = color
	bar.set_anchor_and_offset(SIDE_LEFT,   0.0, 2)
	bar.set_anchor_and_offset(SIDE_RIGHT,  1.0, -2)
	bar.set_anchor_and_offset(SIDE_TOP,    0.0, BAR_H * (1.0 - pct))
	bar.set_anchor_and_offset(SIDE_BOTTOM, 0.0, BAR_H)
	bar_container.add_child(bar)
	col.add_child(bar_container)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lbl)

	parent.add_child(col)


func _section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl


func _row(key: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var k  := Label.new()
	k.text = key
	k.custom_minimum_size.x = 180
	var v  := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(k)
	hb.add_child(v)
	return hb


func _separator() -> HSeparator:
	return HSeparator.new()


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
