extends Node

@onready var mailbox := $"/root/Jeux/CanvasLayer/HBoxContainer/MailBox"


func send_template(template_id: int, values: Dictionary) -> void:
	mailbox.send_from_template(template_id, values)


func send(type: String, from: String, subject: String, body: String, date: String = "", action: String = "", action_label: String = "") -> void:
	if date == "":
		date = "%02d/%02d/%d" % [Game.date["day"], Game.date["month"], Game.date["year"]]
	mailbox.add_message(type, from, subject, body, date, action, action_label)

func send_tomorrow(type: String, from: String, subject: String, body: String) -> void:
	var tomorrow := Game.date.duplicate()
	tomorrow["day"] += 1
	if tomorrow["day"] > Game.days_in_month(tomorrow["month"], tomorrow["year"]):
		tomorrow["day"] = 1
		tomorrow["month"] += 1
		if tomorrow["month"] > 12:
			tomorrow["month"] = 1
			tomorrow["year"] += 1

	Game.pending_mails.append({
		"type":    type,
		"from":    from,
		"subject": subject,
		"body":    body,
		"send_on": tomorrow
	})


func _send_welcome() -> void:
	send_template(0, {
		"manager_name": "Directeur",
		"team_name":    Game.myteam,
		"date":         "15/03/2026"
	})


func _send_test_mails() -> void:
	notify_injury("Felix Gall", 14, "Paris-Nice")

	notify_contract_expiry("Olav Kooij", 2028, 1200000)

	notify_transfer_offer(
		"Paul Seixas",
		"UAE Team Emirates",
		3500000,
		1500000,
		3,
		"30/03/2026",
		"Mauro Gianetti"
	)

	notify_sponsor("Nike", 500000, "Top 5 Tour de France", "2026")


func notify_injury(rider_name: String, days: int, event: String = "l'entraînement") -> void:
	send_template(2, {
		"rider_name":  rider_name,
		"event":       event,
		"diagnosis":   "Fracture / entorse",
		"days":        str(days),
		"return_date": "à déterminer",
		"doctor_name": "Martin"
	})


func notify_contract_expiry(rider_name: String, year: int, salary: int) -> void:
	send_template(3, {
		"rider_name": rider_name,
		"year":       str(year),
		"salary":     _fmt(salary)
	})


func notify_transfer_offer(rider_name: String, from_team: String, amount: int, salary: int = 0, years: int = 2, deadline: String = "30/03/2026", contact: String = "Directeur sportif") -> void:
	send_template(4, {
		"rider_name":     rider_name,
		"from_team":      from_team,
		"amount":         _fmt(amount),
		"salary":         _fmt(salary),
		"contract_years": str(years),
		"deadline":       deadline,
		"contact_name":   contact
	})


func notify_sponsor(sponsor_name: String, amount: int, objectif: String, season: String = "2026") -> void:
	send_template(1, {
		"sponsor_name": sponsor_name,
		"amount":       _fmt(amount),
		"objectif":     objectif,
		"season":       season
	})


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


func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%02d/%02d/%d" % [d["day"], d["month"], d["year"]]
