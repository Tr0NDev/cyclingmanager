extends Node
class_name Team

var realname:        String
var teamname:        String
var short_name:      String
var country:         String
var category:        String
var budget:          int
var budget_transfer: int
var budget_salary:   int
var transfer_budget: int
var popularity:      int
var uci:             int
var objectives:      Array
var director:        String
var sponsors:        Dictionary
var folder:          String
var riders: Array = []


static func _json_path(team_folder: String) -> String:
	var save_path := "user://save/team/%s/info.json" % team_folder
	if FileAccess.file_exists(save_path):
		return save_path
	return "res://data/team/%s/info.json" % team_folder


static func load_team(team_folder: String) -> Team:
	var t := Team.new()
	t.folder = team_folder
	var json_path := _json_path(team_folder)

	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var raw := file.get_as_text()
			file.close()
			raw = raw.strip_edges()
			if raw.begins_with("\ufeff"):
				raw = raw.substr(1)
			var json := JSON.new()
			var err  := json.parse(raw)
			if err == OK:
				var data = json.get_data()
				if data is Dictionary:
					t.realname       = data.get("realname",        "")
					t.teamname       = data.get("name",            "")
					t.short_name     = data.get("short_name",      "")
					t.country        = data.get("country",         "")
					t.category       = data.get("category",        "")
					t.budget          = int(data.get("budget", 0))
					t.budget_transfer = int(data.get("budgettrans", 0))
					t.budget_salary   = int(data.get("budgetsalary", 0))
					t.transfer_budget= int(data.get("transfer_budget", 0))
					t.popularity     = int(data.get("popularity",      0))
					t.uci            = int(data.get("uci",             0))
					t.objectives     = data.get("objectives",      [])
					t.director       = data.get("director",        "")
					t.sponsors       = data.get("sponsors",        {})
			else:
				push_error("JSON error ligne %d : %s" % [json.get_error_line(), json.get_error_message()])
	else:
		push_warning("info.json introuvable pour : %s" % json_path)
		t.realname = team_folder

	t.riders = t._load_riders(team_folder)
	return t

func get_rider_by_name(full_name: String):
	for rider in riders:
		if rider.full_name() == full_name:
			return rider
	return null


func _load_riders(team_folder: String) -> Array:
	var r := Rider.new()
	return r.load_team(team_folder)


func rider_count() -> int:
	return riders.size()


func get_rider(firstname: String, lastname: String):
	for rider in riders:
		if rider.firstname == firstname and rider.lastname == lastname:
			return rider
	return null
	
func reset_uci() -> void:
	uci = 0
	# Sauvegarde dans le JSON
	var json_path := "user://save/team/%s/info.json" % folder
	var data := {}

	# Charge le JSON existant pour ne pas écraser les autres champs
	if FileAccess.file_exists(json_path):
		var file := FileAccess.open(json_path, FileAccess.READ)
		if file:
			var raw := file.get_as_text().strip_edges()
			if raw.begins_with("\ufeff"): raw = raw.substr(1)
			file.close()
			var json := JSON.new()
			if json.parse(raw) == OK and json.get_data() is Dictionary:
				data = json.get_data()

	data["uci"] = 0

	var out := FileAccess.open(json_path, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data, "\t"))
		out.close()
