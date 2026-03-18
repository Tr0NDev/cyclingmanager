extends Node
class_name Race

var realname:      String
var goodname:          String
var description:   String
var country:       String
var category:      String
var type:          String   # "one-day" ou "stage-race"
var distance_km:   int
var uci:   int
var date_in_season:String
var key_stats:     Array
var terrain:       Dictionary
var profile:       Dictionary
var lastwinners:   Array
var folder:        String


static func load_race(race_folder: String) -> Race:
	var r := Race.new()
	r.folder = race_folder

	var json_path := "res://data/race/%s/info.json" % race_folder
	if not FileAccess.file_exists(json_path):
		push_warning("info.json introuvable pour la course : %s" % json_path)
		r.realname = race_folder
		r.name     = race_folder
		return r

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Impossible d'ouvrir %s" % json_path)
		return r

	var raw := file.get_as_text()
	file.close()
	raw = raw.strip_edges()
	if raw.begins_with("\ufeff"):
		raw = raw.substr(1)

	var json := JSON.new()
	var err  := json.parse(raw)
	if err != OK:
		push_error("JSON error ligne %d : %s" % [json.get_error_line(), json.get_error_message()])
		return r

	var data = json.get_data()
	if not data is Dictionary:
		return r

	r.realname       = data.get("realname",       race_folder)
	r.name           = data.get("name",           "")
	r.description    = data.get("description",    "")
	r.country        = data.get("country",        "")
	r.category       = data.get("category",       "")
	r.type           = data.get("type",           "one-day")
	r.distance_km    = int(data.get("distance_km", 0))
	r.uci    = int(data.get("uci", 0))
	r.date_in_season = data.get("date_in_season", "")
	r.key_stats      = data.get("key_stats",      [])
	r.terrain        = data.get("terrain",        {})
	r.profile        = data.get("profile",        {})
	r.lastwinners    = data.get("lastwinners",     [])

	return r


func get_logo_path() -> String:
	return "res://data/race/%s/logo.png" % folder


func get_logo_texture() -> Texture2D:
	var path := get_logo_path()
	if ResourceLoader.exists(path):
		return load(path)
	return null


func get_last_winner() -> String:
	if lastwinners.is_empty():
		return "Inconnu"
	return lastwinners[0]


func get_sectors() -> Array:
	return profile.get("sectors", [])


func get_sectors_sorted() -> Array:
	var sectors := get_sectors().duplicate()
	sectors.sort_custom(func(a, b): return a["km_remaining"] > b["km_remaining"])
	return sectors

func get_elevation() -> int:
	return int(profile.get("elevation_m", 0))


func is_cobbled() -> bool:
	return int(terrain.get("cobbles", 0)) > 0


func is_hilly() -> bool:
	return int(terrain.get("hills", 0)) > 20


func is_mountain() -> bool:
	return int(terrain.get("mountains", 0)) > 20


func has_summit_finish() -> bool:
	return terrain.get("summit_finish", false)
