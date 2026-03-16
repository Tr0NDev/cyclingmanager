extends Node

var myteam:         String = "alpecin-premier-tech"
var myteam_riders:  Array  = []
var team_list:      Array  = []
var rapportlist:    Array  = []
var rapport_rider           = null
var pending_mails:  Array  = []
var blocked_riders: Dictionary = {}
var total_days:     int    = 0
var favoris:        Array  = []
var transfer_offers: Dictionary = {}

var date := {
	"year":  2026,
	"month": 3,
	"day":   14
}


func _ready() -> void:
	_init_save()
	load_all_teams()
	load_game()


func _init_save() -> void:
	if DirAccess.dir_exists_absolute("user://save"):
		return
	DirAccess.make_dir_recursive_absolute("user://save/team")
	var dir := DirAccess.open("res://data/team/")
	if dir == null:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir():
			DirAccess.make_dir_recursive_absolute("user://save/team/%s" % folder)
			_copy_file("res://data/team/%s/rider.csv" % folder, "user://save/team/%s/rider.csv" % folder)
			_copy_file("res://data/team/%s/info.json" % folder, "user://save/team/%s/info.json" % folder)
		folder = dir.get_next()
	dir.list_dir_end()
	print("✅ Save initialisée")


func _copy_file(from: String, to: String) -> void:
	if not FileAccess.file_exists(from):
		return
	var file_in  := FileAccess.open(from, FileAccess.READ)
	var content  := file_in.get_as_text()
	file_in.close()
	var file_out := FileAccess.open(to, FileAccess.WRITE)
	file_out.store_string(content)
	file_out.close()


func load_all_teams() -> void:
	team_list.clear()
	var dir := DirAccess.open("res://data/team/")
	if dir == null:
		return
	dir.list_dir_begin()
	var folder := dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != myteam:
			team_list.append(Team.load_team(folder))
		folder = dir.get_next()
	dir.list_dir_end()


func save_game() -> void:
	var data := {
		"myteam":          myteam,
		"total_days":      total_days,
		"date":            date,
		"favoris":         favoris,
		"blocked_riders":  blocked_riders,
		"pending_mails":   pending_mails,
		"transfer_offers": _serialize_transfer_offers(),
	}
	DirAccess.make_dir_recursive_absolute("user://save")
	var file := FileAccess.open("user://save/gamedata.json", FileAccess.WRITE)
	if file == null:
		push_error("save_game: impossible d'écrire gamedata.json")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("💾 Partie sauvegardée")


func load_game() -> void:
	var path := "user://save/gamedata.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var raw  := file.get_as_text()
	file.close()

	var data = JSON.parse_string(raw)
	if not data is Dictionary:
		push_error("load_game: gamedata.json invalide")
		return

	myteam        = data.get("myteam",        myteam)
	total_days    = int(data.get("total_days", 0))
	favoris       = data.get("favoris",        [])
	pending_mails = data.get("pending_mails",  [])

	var br = data.get("blocked_riders", {})
	if br is Dictionary:
		blocked_riders = br

	var d = data.get("date", {})
	if d is Dictionary:
		date["year"]  = int(d.get("year",  2026))
		date["month"] = int(d.get("month", 3))
		date["day"]   = int(d.get("day",   14))

	transfer_offers = {}
	var raw_offers = data.get("transfer_offers", {})
	if raw_offers is Dictionary:
		for rider_name in raw_offers.keys():
			transfer_offers[rider_name] = []
			for offer in raw_offers[rider_name]:
				transfer_offers[rider_name].append({
					"team":     offer.get("team",     ""),
					"salary":   int(offer.get("salary",   0)),
					"transfer": int(offer.get("transfer", 0)),
					"promises": offer.get("promises", []),
					"deadline": int(offer.get("deadline", 0)),
					"rider":    null,
				})

	_resolve_riders()
	print("✅ Partie chargée — jour %d" % total_days)


func _resolve_riders() -> void:
	for rider_name in transfer_offers.keys():
		for offer in transfer_offers[rider_name]:
			if offer["rider"] != null:
				continue
			for team in team_list:
				var found = team.get_rider_by_name(rider_name)
				if found:
					offer["rider"] = found
					break
			if offer["rider"] == null:
				var mt := Team.load_team(myteam)
				offer["rider"] = mt.get_rider_by_name(rider_name)


func _serialize_transfer_offers() -> Dictionary:
	var out := {}
	for rider_name in transfer_offers.keys():
		out[rider_name] = []
		for offer in transfer_offers[rider_name]:
			out[rider_name].append({
				"team":     offer["team"],
				"salary":   offer["salary"],
				"transfer": offer["transfer"],
				"promises": offer["promises"],
				"deadline": offer["deadline"],
			})
	return out


func switch_team(rider: Rider, from_team: String, to_team: String, transfer_amount: int = 0) -> void:
	var from := get_team(from_team)
	var to   := get_team(to_team)
	if from == null or to == null:
		push_error("switch_team: équipe introuvable (%s → %s)" % [from_team, to_team])
		return

	from.riders = from.riders.filter(func(r): return r.full_name() != rider.full_name())
	rider.team  = to_team
	to.riders.append(rider)

	if transfer_amount > 0:
		from.budget_transfer += transfer_amount
		to.budget_transfer   -= transfer_amount
		from.budget           = from.budget_transfer + from.budget_salary
		to.budget             = to.budget_transfer   + to.budget_salary
		_save_team_json(from)
		_save_team_json(to)

	_save_team_csv(from)
	_save_team_csv(to)
	print("🔄 %s transféré de %s vers %s (montant : %s €)" % [
		rider.full_name(), from_team, to_team, _fmt(transfer_amount)
	])


func _save_team_csv(team: Team) -> void:
	var path := "user://save/team/%s/rider.csv" % team.folder
	DirAccess.make_dir_recursive_absolute("user://save/team/%s" % team.folder)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("_save_team_csv: impossible d'écrire %s" % path)
		return
	file.store_line("firstname,lastname,birthdate,team,weight,length,cob,hll,mtn,gc,itt,spr,maxcob,maxhll,maxmtn,maxgc,maxitt,maxspr,happyness,form,salary,contract,recovery,injury,media,flt,maxflt,or_,maxor,ttl,maxttl,tts,maxtts")
	for rider in team.riders:
		var inj: String = str(rider.injury) if rider.is_injured() else "null"
		file.store_line("%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [
			rider.firstname, rider.lastname, rider.birthdate, rider.team,
			rider.weight, rider.length,
			rider.cob, rider.hll, rider.mtn, rider.gc, rider.itt, rider.spr,
			rider.maxcob, rider.maxhll, rider.maxmtn, rider.maxgc, rider.maxitt, rider.maxspr,
			rider.happyness, rider.form, rider.salary, rider.contract,
			rider.recovery, inj, rider.media,
			rider.flt, rider.maxflt, rider.or_, rider.maxor,
			rider.ttl, rider.maxttl, rider.tts, rider.maxtts
		])
	file.close()


func _save_team_json(team: Team) -> void:
	var path := "user://save/team/%s/info.json" % team.folder
	DirAccess.make_dir_recursive_absolute("user://save/team/%s" % team.folder)
	var sponsors_out := {}
	for k in team.sponsors.keys():
		sponsors_out[k] = team.sponsors[k]
	var data := {
		"name":            team.teamname,
		"realname":        team.realname,
		"short_name":      team.short_name,
		"budget":          team.budget,
		"budgettrans":     team.budget_transfer,
		"budgetsalary":    team.budget_salary,
		"popularity":      team.popularity,
		"uci":             team.uci,
		"country":         team.country,
		"category":        team.category,
		"sponsors":        sponsors_out,
		"transfer_budget": team.transfer_budget,
		"objectives":      team.objectives,
		"director":        team.director
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("_save_team_json: impossible d'écrire %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func get_team(folder: String) -> Team:
	if folder == myteam:
		return Team.load_team(myteam)
	for team in team_list:
		if team.folder == folder:
			return team
	return null


func tick_blocked_riders() -> void:
	var to_remove: Array[String] = []
	for key in blocked_riders.keys():
		blocked_riders[key] -= 1
		if blocked_riders[key] <= 0:
			to_remove.append(key)
	for key in to_remove:
		blocked_riders.erase(key)


func add_day() -> void:
	total_days += 1
	date["day"] += 1
	if date["day"] > days_in_month(date["month"], date["year"]):
		date["day"]    = 1
		date["month"] += 1
		if date["month"] > 12:
			date["month"] = 1
			date["year"] += 1


func days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12: return 31
		4, 6, 9, 11:            return 30
		2: return 29 if is_leap_year(year) else 28
	return 30


func is_leap_year(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)


func format_date() -> String:
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


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
