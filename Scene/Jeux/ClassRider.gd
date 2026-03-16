extends Node

class_name Rider

var firstname: String
var lastname:  String
var birthdate: String
var team:      String
var weight:    int
var length:    int

var cob: int
var hll: int
var mtn: int
var gc:  int
var itt: int
var spr: int
var flt: int
var or_: int
var ttl: int
var tts: int

var maxcob: int
var maxhll: int
var maxmtn: int
var maxgc:  int
var maxitt: int
var maxspr: int
var maxflt: int
var maxor:  int
var maxttl: int
var maxtts: int

var happyness: int
var form:      int
var recovery:  int
var injury:    Variant

var salary:   int
var contract: int
var media: int


static func from_dict(data: Dictionary) -> Rider:
	var r := Rider.new()
	r.firstname = data.get("firstname", "")
	r.lastname  = data.get("lastname",  "")
	r.birthdate = data.get("birthdate", "")
	r.team      = data.get("team",      "")
	r.weight    = int(data.get("weight", 0))
	r.length    = int(data.get("length", 0))
	r.cob = int(data.get("cob", 0))
	r.hll = int(data.get("hll", 0))
	r.mtn = int(data.get("mtn", 0))
	r.gc  = int(data.get("gc",  0))
	r.itt = int(data.get("itt", 0))
	r.spr = int(data.get("spr", 0))
	r.flt = int(data.get("flt", 0))
	r.or_ = int(data.get("or_", 0))
	r.ttl = int(data.get("ttl", 0))
	r.tts = int(data.get("tts", 0))
	r.maxcob = int(data.get("maxcob", 0))
	r.maxhll = int(data.get("maxhll", 0))
	r.maxmtn = int(data.get("maxmtn", 0))
	r.maxgc  = int(data.get("maxgc",  0))
	r.maxitt = int(data.get("maxitt", 0))
	r.maxspr = int(data.get("maxspr", 0))
	r.maxflt = int(data.get("maxflt", 0))
	r.maxor  = int(data.get("maxor",  0))
	r.maxttl = int(data.get("maxttl", 0))
	r.maxtts = int(data.get("maxtts", 0))
	r.happyness = int(data.get("happyness", 0))
	r.form      = int(data.get("form",      0))
	r.recovery  = int(data.get("recovery",  0))
	r.injury    = null
	r.salary   = int(data.get("salary",   0))
	r.contract = int(data.get("contract", 0))
	r.media    = int(data.get("media",    0))
	return r


func full_name() -> String:
	return firstname + " " + lastname


func age() -> int:
	var parts := birthdate.split("/")
	if parts.size() < 3:
		return 0
	return Time.get_date_dict_from_system()["year"] - int(parts[2])


func is_injured() -> bool:
	return injury != null


func set_injury(days: int) -> void:
	injury = days


func heal() -> void:
	injury = null


func tick_injury() -> void:
	if injury is int:
		injury -= 1
		if injury <= 0:
			heal()


func apply_fatigue(effort: int) -> void:
	form = clampi(form - effort + (recovery / 10), 0, 100)


static func _csv_path(team_folder: String) -> String:
	var save_path := "user://save/team/%s/rider.csv" % team_folder
	if FileAccess.file_exists(save_path):
		return save_path
	return "res://data/team/%s/rider.csv" % team_folder


func load_team(team_folder: String) -> Array:
	var csv_path := _csv_path(team_folder)
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("Rider.load_team: impossible d'ouvrir %s" % csv_path)
		return []

	var headers := _parse_line(file.get_line())
	var result: Array = []

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var values := _parse_line(line)
		if values.size() != headers.size():
			continue
		result.append(Rider.from_dict(_zip(headers, values)))

	file.close()
	return result


static func load_rider(firstname: String, lastname: String, team: String) -> Rider:
	var csv_path := _csv_path(team)
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("Rider.load_rider: impossible d'ouvrir %s" % csv_path)
		return null

	var headers := _parse_line(file.get_line())

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var values := _parse_line(line)
		if values.size() != headers.size():
			continue
		var data := _zip(headers, values)
		if data.get("firstname", "") == firstname and data.get("lastname", "") == lastname:
			file.close()
			return Rider.from_dict(data)

	file.close()
	push_warning("Rider.load_rider: '%s %s' introuvable dans '%s'" % [firstname, lastname, team])
	return null


static func _parse_line(line: String) -> Array[String]:
	var result: Array[String] = []
	var current := ""
	var in_quotes := false
	for c in line:
		if c == '"':
			in_quotes = not in_quotes
		elif c == "," and not in_quotes:
			result.append(current.strip_edges())
			current = ""
		else:
			current += c
	result.append(current.strip_edges())
	return result


static func _zip(hdrs: Array[String], values: Array[String]) -> Dictionary:
	var data := {}
	for i in hdrs.size():
		data[hdrs[i]] = values[i] if i < values.size() else ""
	return data
