extends Panel

const STAR_YELLOW           := "res://data/image/yellow_star.png"
const STAR_GRAY             := "res://data/image/gray_star.png"
const STAR_LEFT_HALF_YELLOW := "res://data/image/left_half_yellow_star.png"
const STAR_RIGHT_HALF_YELLOW:= "res://data/image/right_half_yellow_star.png"
const STAR_LEFT_HALF_GRAY   := "res://data/image/left_half_gray_star.png"
const STAR_RIGHT_HALF_GRAY  := "res://data/image/right_half_gray_star.png"
const STAR_BLUE             := "res://data/image/blue_star.png"
const STAR_LEFT_HALF_BLUE   := "res://data/image/left_half_blue_star.png"
const STAR_RIGHT_HALF_BLUE  := "res://data/image/right_half_blue_star.png"

@onready var id_label := $Id
@onready var team_logo := $TeamLogo
@onready var hbox := $HBoxContainer
@onready var photo := $RiderPhoto
@onready var rapport := $Rapport
@onready var fav_btn := $FavBtn

var current_rider : Rider

func _ready() -> void:
	fav_btn.connect("toggled", _on_fav_toggled)

func _on_fav_toggled(pressed: bool) -> void:
	var name: String = current_rider.full_name()
	if pressed:
		if name not in Game.favoris:
			Game.favoris.append(name)
	else:
		Game.favoris.erase(name)

func show_rider(rider) -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	for child in hbox.get_children():
		child.queue_free()

	id_label.text = "%s\n%d ans · %d kg · %d cm\n\nTeam: %s" % [
		rider.full_name(), rider.age(), rider.weight, rider.length, rider.team
	]

	var logo_path := "res://data/team/%s/images/logo.png" % rider.team
	if ResourceLoader.exists(logo_path):
		team_logo.texture = load(logo_path)
	team_logo.expand_mode          = TextureRect.EXPAND_FIT_WIDTH
	team_logo.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	team_logo.custom_minimum_size  = Vector2(64, 64)
	team_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	hbox.add_child(_make_left(rider))
	hbox.add_child(_make_right(rider))
	_show_photo(rider)
	show()
	current_rider = rider
	fav_btn.set_pressed_no_signal(rider.full_name() in Game.favoris)


func _make_left(rider) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 280
	col.add_theme_constant_override("separation", 12)

	col.add_child(_section("CONDITION"))
	col.add_child(_row("Forme",    str(rider.form)      + " / 100"))
	col.add_child(_row("Récup.",   str(rider.recovery)  + " / 100"))
	col.add_child(_row("Blessure", "🤕 %d jours" % rider.injury if rider.is_injured() else "✅ Aucune"))
	col.add_child(_row("Moral",    str(rider.happyness) + " / 100"))
	col.add_child(_row("Médias",   str(rider.media)     + " / 100"))

	col.add_child(_separator())

	col.add_child(_section("CONTRAT"))
	col.add_child(_row("Salaire", "%s €" % _format_salary(rider.salary)))
	col.add_child(_row("Fin",     str(rider.contract)))

	return col


func _make_right(rider) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 24)
	col.add_child(top)

	var overall_box   := VBoxContainer.new()
	var overall_title := Label.new()
	overall_title.text = "NOTE"
	overall_title.add_theme_font_size_override("font_size", 11)
	overall_box.add_child(overall_title)

	var avg_current: int = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
	var avg_max: int     = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10
	overall_box.add_child(_stars_node_dual(avg_current, avg_max))
	top.add_child(overall_box)

	col.add_child(_separator())

	col.add_child(_section("STATS"))
	var stats_main = [
		["COB", rider.cob, rider.maxcob],
		["HLL", rider.hll, rider.maxhll],
		["MTN", rider.mtn, rider.maxmtn],
		["GC",  rider.gc,  rider.maxgc],
		["ITT", rider.itt, rider.maxitt],
		["SPR", rider.spr, rider.maxspr],
		["FLT", rider.flt, rider.maxflt],
		["OR",  rider.or_, rider.maxor],
		["TTL", rider.ttl, rider.maxttl],
		["TTS", rider.tts, rider.maxtts],
	]
	for s in stats_main:
		col.add_child(_stat_row(s[0], s[1], s[2]))

	return col


func _show_photo(rider) -> void:
	var photo_name: String = rider.firstname.to_lower().replace(" ", "-") + "-" + rider.lastname.to_lower().replace(" ", "-")
	var path: String = "res://data/image/rider/%s.png" % photo_name
	if not ResourceLoader.exists(path):
		path = "res://data/image/unknown.png"
	photo.texture = load(path)
	photo.expand_mode           = TextureRect.EXPAND_FIT_WIDTH
	photo.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.custom_minimum_size   = Vector2(64, 64)
	photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _stat_row(label: String, value: int, max_value: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size.x = 50
	hb.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.custom_minimum_size.x = 35
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(val_lbl)

	var stars := _stars_node_dual(value, max_value)
	stars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(stars)

	return hb


func _stars_node(value: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	var stars_float := float(value) / 19.0
	var full  := int(stars_float)
	var half  := 1 if (stars_float - full) >= 0.5 else 0
	var empty := 5 - full - half
	for i in full:
		hb.add_child(_star_img(STAR_YELLOW))
	if half:
		hb.add_child(_star_img(STAR_LEFT_HALF_YELLOW, 8))
		hb.add_child(_star_img(STAR_RIGHT_HALF_GRAY,  8))
	for i in empty:
		hb.add_child(_star_img(STAR_GRAY))
	return hb


func _stars_node_dual(value: int, max_value: int) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)

	var val_float := float(value)     / 19.0
	var max_float := float(max_value) / 19.0

	var full_yellow := int(val_float)
	var half_yellow := 1 if (val_float - full_yellow) >= 0.25 else 0
	var full_max    := int(max_float)
	var half_max    := 1 if (max_float - full_max) >= 0.25 else 0

	var full_blue_start := full_yellow + half_yellow
	var full_blue   := maxi(full_max - full_blue_start, 0)
	var half_blue   := half_max if (full_max >= full_blue_start + full_blue) else 0
	var total_filled := full_yellow + half_yellow + full_blue + half_blue
	var empty        := maxi(5 - total_filled, 0)

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


func _stars_node_from_avg(total: int, count: int) -> HBoxContainer:
	var avg: float = float(total) / float(count)
	return _stars_node(int(avg))


func _star_img(path: String, width: int = 16) -> TextureRect:
	var img := TextureRect.new()
	img.texture = load(path)
	img.custom_minimum_size = Vector2(width, 16)
	img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	return img


func _section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


func _row(key: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var k  := Label.new()
	k.text = key
	k.custom_minimum_size.x = 100
	var v  := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(k)
	hb.add_child(v)
	return hb


func _separator() -> HSeparator:
	return HSeparator.new()


func _format_salary(salary: int) -> String:
	var s: String = str(salary)
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = s[i] + result
		count += 1
	return result


func _on_rapport_button_down() -> void:
	Turn.addrapportrider(current_rider)
