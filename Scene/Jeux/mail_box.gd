extends Panel

@onready var list_vbox := $HSplit/ListPanel/ScrollContainer/VBoxContainer
@onready var detail_panel := $HSplit/DetailPanel
@onready var detail_from := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/From
@onready var detail_subject := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Subject
@onready var detail_date := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Date
@onready var detail_body := $HSplit/DetailPanel/ScrollContainer/VBoxContainer/Body
@onready var filter_row := $FilterRow
@onready var del_btn := $HSplit/DetailPanel/DelMail

var _messages: Array = []
var _filter:   String = "all"
var _selected: int    = -1
var _action_btn: Button = null

const TYPE_ICONS := {
	"transfer": "💼",
	"team":     "🚴",
	"notif":    "🔔",
	"sponsor":  "🏆",
}


func _ready() -> void:
	_build_filter_buttons()
	detail_panel.visible = false
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body.custom_minimum_size = Vector2(100, 0)
	del_btn.connect("pressed", _on_delete_pressed)

func _process(delta: float) -> void:
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
		t["subject"]      = t["subject"].replace(placeholder,      str(values[key]))
		t["body"]         = t["body"].replace(placeholder,         str(values[key]))
		t["from"]         = t["from"].replace(placeholder,         str(values[key]))
		t["date"]         = t["date"].replace(placeholder,         str(values[key]))
		t["action"]       = t.get("action", "").replace(placeholder, str(values[key]))
		t["action_label"] = t.get("action_label", "").replace(placeholder, str(values[key]))

	add_message(t["type"], t["from"], t["subject"], t["body"], t["date"], t.get("action", ""), t.get("action_label", ""))


func _build_filter_buttons() -> void:
	for child in filter_row.get_children():
		child.queue_free()
	var filters := [["all", "Tous"], ["transfer", "Transferts"], ["team", "Équipe"], ["notif", "Notifs"], ["sponsor", "Sponsors"]]
	for f in filters:
		var btn := Button.new()
		btn.text = f[1]
		btn.flat = _filter != f[0]
		btn.connect("pressed", func(): _on_filter(f[0]))
		filter_row.add_child(btn)


func _on_filter(f: String) -> void:
	_filter = f
	_build_filter_buttons()
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

	if is_instance_valid(_action_btn):
		_action_btn.queue_free()
		_action_btn = null

	var action: String = msg.get("action", "")
	if action != "":
		_action_btn = Button.new()
		_action_btn.text = msg.get("action_label", "Voir →")
		_action_btn.connect("pressed", func(): _on_action(action))
		$HSplit/DetailPanel/ScrollContainer/VBoxContainer.add_child(_action_btn)

	detail_panel.visible = true
	_display()


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
