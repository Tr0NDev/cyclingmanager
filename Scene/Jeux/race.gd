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

@onready var race_logo  := $RaceLogo
@onready var id_label   := $Id
@onready var hbox       := $HBoxContainer

var current_race: Race


func show_race(race: Race) -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self

	current_race = race

	# Logo
	var tex := race.get_logo_texture()
	if tex:
		race_logo.texture = tex
	race_logo.expand_mode          = TextureRect.EXPAND_FIT_WIDTH
	race_logo.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	race_logo.custom_minimum_size  = Vector2(64, 64)
	race_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Header
	var parts: Array = race.date_in_season.split("-")
	var date_str := ""
	if parts.size() >= 2:
		date_str = "%02d/%02d" % [int(parts[1]), int(parts[0])]

	id_label.text = "%s\n%s · %s · %d km\n%s" % [
		race.name,
		race.category,
		race.country,
		race.distance_km,
		date_str
	]

	# Colonnes
	for child in hbox.get_children():
		child.queue_free()
	hbox.add_child(_make_left(race))
	hbox.add_child(_make_right(race))

	show()


# ── Colonne gauche ────────────────────────────────────────────
func _make_left(race: Race) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 280
	col.add_theme_constant_override("separation", 12)

	# Infos générales
	col.add_child(_section("INFORMATIONS"))
	col.add_child(_row("Type",      race.type))
	col.add_child(_row("Catégorie", race.category))
	col.add_child(_row("Pays",      race.country))
	col.add_child(_row("Distance",  "%d km" % race.distance_km))

	var parts: Array = race.date_in_season.split("-")
	if parts.size() >= 2:
		col.add_child(_row("Date", "%02d/%02d" % [int(parts[1]), int(parts[0])]))

	col.add_child(_separator())


	# Profil
	col.add_child(_section("PROFIL"))
	var profile := race.profile
	if profile.has("elevation_m"):
		col.add_child(_row("Dénivelé", "%d m" % int(profile["elevation_m"])))
	if profile.has("max_gradient_pct"):
		col.add_child(_row("Pente max", "%d%%" % int(profile["max_gradient_pct"])))

	var sectors := race.get_sectors()
	if not sectors.is_empty():
		col.add_child(_separator())
		col.add_child(_section("SECTEURS CLÉS"))

		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 150)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

		var sectors_vbox := VBoxContainer.new()
		sectors_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sectors_vbox.add_theme_constant_override("separation", 4)

		for s in sectors:
			var diff_stars: String = ""
			var diff: int = int(s.get("difficulty", 1))
			for i in diff:      diff_stars += "★"
			for i in (5 - diff): diff_stars += "☆"
			var length: float  = s.get("length_km", 0)
			var km_rem: int    = int(s.get("km_remaining", 0))
			var stype:  String = s.get("type", "")

			var row := VBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.text = "• %s" % s.get("name", "")
			name_lbl.add_theme_font_size_override("font_size", 12)
			row.add_child(name_lbl)

			var detail_lbl := Label.new()
			detail_lbl.text = "  %s  %.1f km  %s  à %d km" % [stype, length, diff_stars, km_rem]
			detail_lbl.add_theme_font_size_override("font_size", 10)
			detail_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			row.add_child(detail_lbl)

			sectors_vbox.add_child(row)
			sectors_vbox.add_child(HSeparator.new())

		scroll.add_child(sectors_vbox)
		col.add_child(scroll)


	return col


# ── Colonne droite ────────────────────────────────────────────
func _make_right(race: Race) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)

	# Stats clés
	col.add_child(_section("STATS CLÉS"))
	var stat_map := {
		"cob": ["COB", "Classicman"],
		"hll": ["HLL", "Puncheur"],
		"mtn": ["MTN", "Grimpeur"],
		"gc":  ["GC",  "Leader GC"],
		"itt": ["ITT", "Rouleur"],
		"spr": ["SPR", "Sprinteur"],
		"flt": ["FLT", "Plat"],
		"or_": ["OR",  "Classiques"],
		"ttl": ["TTL", "CLM long"],
		"tts": ["TTS", "CLM court"],
	}
	for key in race.key_stats:
		if stat_map.has(key):
			var info: Array = stat_map[key]
			var hb := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = "✅ %s (%s)" % [info[0], info[1]]
			lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
			hb.add_child(lbl)
			col.add_child(hb)

	col.add_child(_separator())

	# Palmarès
	col.add_child(_section("PALMARÈS"))
	var winners := race.lastwinners
	for i in mini(winners.size(), 5):
		col.add_child(_row("%d." % (i + 1), winners[i]))

	col.add_child(_separator())

	col.add_child(_separator())
	col.add_child(_section("À PROPOS"))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var desc_lbl := Label.new()
	desc_lbl.text = race.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.custom_minimum_size = Vector2(100, 0)
	scroll.add_child(desc_lbl)
	col.add_child(scroll)

	return col


# ── Helpers UI ────────────────────────────────────────────────
func _section(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


func _row(key: String, value: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var k  := Label.new()
	k.text = key
	k.custom_minimum_size.x = 120
	var v  := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(k)
	hb.add_child(v)
	return hb


func _separator() -> HSeparator:
	return HSeparator.new()


func _star_img(path: String, width: int = 16) -> TextureRect:
	var img := TextureRect.new()
	img.texture = load(path)
	img.custom_minimum_size = Vector2(width, 16)
	img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	return img
