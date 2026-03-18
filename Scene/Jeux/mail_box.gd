extends Panel

@onready var list_vbox := $HSplit/ListPanel/ScrollContainer/VBoxContainer
@onready var detail_panel := $HSplit/DetailPanel
@onready var detail_from := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/From
@onready var detail_subject := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Subject
@onready var detail_date := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Date
@onready var detail_body := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Body
@onready var filter_row := $FilterRow
@onready var del_btn := $HSplit/DetailPanel/DelMail
@onready var read_all_btn := $ReadAll

var _messages: Array = []
var _filter:   String = "all"
var _selected: int    = -1
var _action_btn: Button = null

# Sélection course
var _race_selection_vbox: VBoxContainer = null
var _race_dropdowns: Array = []   # Array de OptionButton (coureur)
var _role_dropdowns: Array = []   # Array de OptionButton (rôle)
var _current_race_folder: String = ""

const TYPE_ICONS := {
	"transfer": "💼",
	"team":     "🚴",
	"notif":    "🔔",
	"sponsor":  "🏆",
}

const ROLES := ["Leader", "Équipier", "Échappée"]


func _ready() -> void:
	detail_panel.visible = false
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body.custom_minimum_size = Vector2(100, 0)
	del_btn.connect("pressed", _on_delete_pressed)
	read_all_btn.connect("pressed", _on_read_all)


func _on_read_all() -> void:
	for msg in _messages:
		msg["read"] = true
	save_mails()
	_display()


func _process(_delta: float) -> void:
	_update_badge()


func _on_delete_pressed() -> void:
	if _selected == -1:
		return
	_messages = _messages.filter(func(m): return m["id"] != _selected)
	_selected = -1
	detail_panel.visible = false
	save_mails()
	_display()


func show_mailbox() -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	_load_mails()
	_display()
	show()


func _load_mails() -> void:
	var path := "user://mails.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Array:
		_messages = data


func save_mails() -> void:
	var file := FileAccess.open("user://mails.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_messages, "\t"))
	file.close()


func add_message(type: String, from: String, subject: String, body: String, date: String = "", action: String = "", action_label: String = "") -> void:
	if date == "":
		date = _today()
	_messages.append({
		"id":           _messages.size(),
		"type":         type,
		"from":         from,
		"subject":      subject,
		"body":         body,
		"date":         date,
		"read":         false,
		"action":       action,
		"action_label": action_label,
	})
	save_mails()
	if is_visible():
		_display()


func send_from_template(template_id: int, values: Dictionary) -> void:
	var path := "res://data/mail/mail.json"
	if not FileAccess.file_exists(path):
		push_error("mail.json introuvable")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Array or template_id >= data.size():
		return
	var t: Dictionary = data[template_id].duplicate(true)
	t["date"] = _today()
	for key in values:
		var placeholder: String = "%" + key + "%"
		t["subject"]      = t["subject"].replace(placeholder, str(values[key]))
		t["body"]         = t["body"].replace(placeholder,    str(values[key]))
		t["from"]         = t["from"].replace(placeholder,    str(values[key]))
		t["date"]         = t["date"].replace(placeholder,    str(values[key]))
		t["action"]       = t.get("action", "").replace(placeholder,       str(values[key]))
		t["action_label"] = t.get("action_label", "").replace(placeholder, str(values[key]))
	add_message(t["type"], t["from"], t["subject"], t["body"], t["date"], t.get("action", ""), t.get("action_label", ""))


func _on_filter(f: String) -> void:
	_filter = f
	_display()


func _display() -> void:
	for child in list_vbox.get_children():
		child.queue_free()
	var filtered := _messages.filter(func(m): return _filter == "all" or m["type"] == _filter)
	filtered.reverse()
	if filtered.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucun message"
		empty_lbl.add_theme_font_size_override("font_size", 13)
		list_vbox.add_child(empty_lbl)
		return
	for msg in filtered:
		list_vbox.add_child(_make_row(msg))


func _make_row(msg: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func(): panel.modulate = Color(1.2, 1.2, 1.2))
	panel.mouse_exited.connect(func():  panel.modulate = Color(1, 1, 1))
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_message_clicked(msg)
	)
	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	var dot := Label.new()
	dot.text = "●" if not msg["read"] else " "
	dot.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	dot.add_theme_font_size_override("font_size", 8)
	dot.custom_minimum_size.x = 12
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(dot)

	var icon := Label.new()
	icon.text = TYPE_ICONS.get(msg["type"], "📩")
	icon.add_theme_font_size_override("font_size", 11)
	icon.custom_minimum_size.x = 18
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var from_lbl := Label.new()
	from_lbl.text = msg["from"]
	from_lbl.add_theme_font_size_override("font_size", 12)
	from_lbl.clip_contents = true
	from_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(from_lbl)

	var subj_lbl := Label.new()
	subj_lbl.text = msg["subject"]
	subj_lbl.add_theme_font_size_override("font_size", 10)
	subj_lbl.clip_contents = true
	subj_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(subj_lbl)
	hbox.add_child(vb)

	var date_lbl := Label.new()
	date_lbl.text = msg["date"]
	date_lbl.add_theme_font_size_override("font_size", 10)
	date_lbl.custom_minimum_size.x = 70
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(date_lbl)

	return panel


func _on_message_clicked(msg: Dictionary) -> void:
	detail_body.custom_minimum_size = Vector2(670, 0)
	msg["read"] = true
	_selected   = msg["id"]
	save_mails()

	detail_from.text    = "De : %s  %s" % [TYPE_ICONS.get(msg["type"], "📩"), msg["from"]]
	detail_subject.text = msg["subject"]
	detail_date.text    = msg["date"]
	detail_body.text    = msg["body"]

	# Nettoie l'ancien bouton action et sélection course
	if is_instance_valid(_action_btn):
		_action_btn.queue_free()
		_action_btn = null
	if is_instance_valid(_race_selection_vbox):
		_race_selection_vbox.queue_free()
		_race_selection_vbox = null
	_race_dropdowns.clear()
	_role_dropdowns.clear()

	var action: String = msg.get("action", "")
	var detail_vbox := $HSplit/DetailPanel/ScrollContainer/VBoxContainer

	if action.begins_with("meeting_race_"):
		_current_race_folder = action.substr("meeting_race_".length())
		_build_race_selection(detail_vbox)
	elif action != "":
		_action_btn = Button.new()
		_action_btn.text = msg.get("action_label", "Voir →")
		_action_btn.connect("pressed", func(): _on_action(action))
		detail_vbox.add_child(_action_btn)

	detail_panel.visible = true
	_display()


func _build_race_selection(parent: VBoxContainer) -> void:
	_race_selection_vbox = VBoxContainer.new()
	_race_selection_vbox.add_theme_constant_override("separation", 8)

	var race := Race.load_race(_current_race_folder)

	var title := Label.new()
	title.text = "🏁 Sélection pour %s" % race.name
	title.add_theme_font_size_override("font_size", 13)
	_race_selection_vbox.add_child(title)

	var sep := HSeparator.new()
	_race_selection_vbox.add_child(sep)

	# Charge les riders disponibles (hors blessés)
	var team := Team.load_team(Game.myteam)
	var available := team.riders.filter(func(r): return not r.is_injured())
	
	var auto_btn := Button.new()
	auto_btn.text = "🤖 Sélection automatique"
	auto_btn.connect("pressed", _on_auto_select)
	_race_selection_vbox.add_child(auto_btn)

	# Header
	var header := HBoxContainer.new()
	var h1 := Label.new(); h1.text = "Coureur"; h1.custom_minimum_size.x = 220
	var h2 := Label.new(); h2.text = "Rôle";    h2.custom_minimum_size.x = 130
	header.add_child(h1)
	header.add_child(h2)
	_race_selection_vbox.add_child(header)

	# 8 lignes coureur + rôle
	for i in 8:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var num := Label.new()
		num.text = "%d." % (i + 1)
		num.custom_minimum_size.x = 20
		row.add_child(num)

		var rider_opt := OptionButton.new()
		rider_opt.custom_minimum_size.x = 200
		row.add_child(rider_opt)
		_race_dropdowns.append(rider_opt)

		var role_opt := OptionButton.new()
		role_opt.custom_minimum_size.x = 120
		row.add_child(role_opt)
		_role_dropdowns.append(role_opt)

		_race_selection_vbox.add_child(row)

	# Connecte après avoir tout créé
	for i in 8:
		var idx := i
		_race_dropdowns[i].connect("item_selected", func(_v): _refresh_dropdowns())
		_role_dropdowns[i].connect("item_selected",  func(_v): _refresh_dropdowns())

	_refresh_dropdowns()

	# Bouton valider
	var validate_btn := Button.new()
	validate_btn.text = "✅ Confirmer la sélection"
	validate_btn.connect("pressed", _on_validate_race_selection)
	_race_selection_vbox.add_child(validate_btn)

	parent.add_child(_race_selection_vbox)


func _on_auto_select() -> void:
	var race    := Race.load_race(_current_race_folder)
	var team    := Team.load_team(Game.myteam)
	var lineup  := Turn._build_team_lineup(team, race)

	for i in mini(lineup.size(), 8):
		var rider_opt: OptionButton = _race_dropdowns[i]
		var role_opt:  OptionButton = _role_dropdowns[i]
		var entry = lineup[i]

		# Sélectionne le coureur
		for k in rider_opt.get_item_count():
			if rider_opt.get_item_text(k) == entry["rider"]:
				rider_opt.select(k)
				break

		# Sélectionne le rôle
		var role_clean: String = entry["role"].replace(" 🏆", "").replace(" 🏃", "")
		var role_map := {"Leader 🏆": "Leader", "Échappée 🏃": "Échappée", "Équipier": "Équipier"}
		var role: String = role_map.get(entry["role"], "Équipier")
		for k in role_opt.get_item_count():
			if role_opt.get_item_text(k) == role:
				role_opt.select(k)
				break

	_refresh_dropdowns()

func _refresh_dropdowns() -> void:
	var team := Team.load_team(Game.myteam)
	var available := team.riders.filter(func(r): return not r.is_injured())

	# Noms déjà sélectionnés par ligne
	var selected_names: Array = []
	for i in 8:
		var opt: OptionButton = _race_dropdowns[i]
		if opt.get_item_count() > 0 and opt.get_selected() > 0:
			selected_names.append(opt.get_item_text(opt.get_selected()))
		else:
			selected_names.append("")

	# Y a-t-il déjà un leader ?
	var leader_line := -1
	for i in 8:
		var role_opt: OptionButton = _role_dropdowns[i]
		if role_opt.get_item_count() > 0 and role_opt.get_selected() >= 0:
			if role_opt.get_item_text(role_opt.get_selected()) == "Leader" and selected_names[i] != "":
				leader_line = i
				break

	for i in 8:
		var rider_opt: OptionButton = _race_dropdowns[i]
		var role_opt:  OptionButton = _role_dropdowns[i]

		# Sauvegarde sélection courante
		var current_name: String = ""
		if rider_opt.get_item_count() > 0 and rider_opt.get_selected() > 0:
			current_name = rider_opt.get_item_text(rider_opt.get_selected())

		var current_role: String = "Équipier"
		if role_opt.get_item_count() > 0 and role_opt.get_selected() >= 0:
			current_role = role_opt.get_item_text(role_opt.get_selected())

		# Rebuild rider dropdown
		rider_opt.clear()
		rider_opt.add_item("— Choisir —", 0)
		for j in available.size():
			var name: String = available[j].full_name()
			if name in selected_names and name != current_name:
				continue
			rider_opt.add_item(name, j + 1)
		for k in rider_opt.get_item_count():
			if rider_opt.get_item_text(k) == current_name:
				rider_opt.select(k)
				break

		# Rebuild role dropdown
		role_opt.clear()
		for role in ROLES:
			role_opt.add_item(role)
			# Leader désactivé si déjà pris par une autre ligne
			if role == "Leader" and leader_line != -1 and leader_line != i:
				role_opt.set_item_disabled(role_opt.get_item_count() - 1, true)
		# Restore rôle (défaut = Équipier)
		var restored := false
		for k in role_opt.get_item_count():
			if role_opt.get_item_text(k) == current_role and not role_opt.is_item_disabled(k):
				role_opt.select(k)
				restored = true
				break
		if not restored:
			# Fallback sur Équipier
			for k in role_opt.get_item_count():
				if role_opt.get_item_text(k) == "Équipier":
					role_opt.select(k)
					break

func _on_validate_race_selection() -> void:
	var selection: Array = []
	var used_names: Array = []

	for i in 8:
		var rider_idx: int = _race_dropdowns[i].get_selected_id()
		if rider_idx == 0:
			continue  # pas sélectionné
		var rider_name: String = _race_dropdowns[i].get_item_text(_race_dropdowns[i].get_selected())
		if rider_name in used_names:
			continue  # doublon
		used_names.append(rider_name)
		selection.append({
			"rider": rider_name,
			"role":  _role_dropdowns[i].get_item_text(_role_dropdowns[i].get_selected())
		})

	if selection.size() < 1:
		return

	# Sauvegarde dans Game
	Game.race_selection[_current_race_folder] = selection

	# Mail de confirmation
	var lines: Array[String] = []
	lines.append("Sélection confirmée pour %s :" % _current_race_folder)
	lines.append("")
	for s in selection:
		lines.append("• %s — %s" % [s["rider"], s["role"]])

	get_node("/root/Mail").send(
		"notif",
		"Staff technique",
		"✅ Sélection confirmée — %s" % _current_race_folder,
		"\n".join(lines)
	)

	# Nettoie l'UI
	if is_instance_valid(_race_selection_vbox):
		_race_selection_vbox.queue_free()
		_race_selection_vbox = null


func _on_action(action: String) -> void:
	Utils.hideall()
	match action:
		"myteam":    $"../Team".show_team(Game.myteam)
		"transfers": $"../Transfert".show_transfers()
		"sponsors":  $"../Sponsor".show_sponsors()
		"finance":   $"../Finance".show_finance()
		"teams":     $"../Teams".show_teams()
		"meeting_transfer":
			var meeting := $"../Meeting"
			meeting.open("transfer", Game.rapport_rider)


func _update_badge() -> void:
	var unread := _messages.filter(func(m): return not m["read"]).size()
	var btn = get_node_or_null("/root/Jeux/CanvasLayer/HBoxContainer/Menu/MailBox")
	if btn:
		btn.text = "📬 (%d)" % unread if unread > 0 else "📭"


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%02d/%02d/%d" % [d["day"], d["month"], d["year"]]
