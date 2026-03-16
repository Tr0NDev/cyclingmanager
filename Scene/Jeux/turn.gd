extends Node

@onready var datelabel := $"/root/Jeux/CanvasLayer/Date"


func _on_button_suivant_button_down() -> void:
	Game.tick_blocked_riders()
	Game.add_day()
	datelabel.text = Game.format_date()
	simulation()
	_check_pending_mails()
	rapport()
	_cleanup_old_mails()
	Game.save_game()

func _cleanup_old_mails() -> void:
	var mailbox = get_node_or_null("/root/Jeux/CanvasLayer/HBoxContainer/MailBox")
	if mailbox == null:
		return
	mailbox._messages = mailbox._messages.filter(func(m):
		if not m["read"]:
			return true
		var sent_day: int = int(m.get("game_day", 0))
		return (Game.total_days - sent_day) < 10
	)
	mailbox.save_mails()
	mailbox._display()

func _check_pending_mails() -> void:
	var remaining: Array = []
	for mail in Game.pending_mails:
		var d = mail["send_on"]
		if d["year"] <= Game.date["year"] and d["month"] <= Game.date["month"] and d["day"] <= Game.date["day"]:
			get_node("/root/Mail").send(mail["type"], mail["from"], mail["subject"], mail["body"])
		else:
			remaining.append(mail)
	Game.pending_mails = remaining


func addrapportrider(rider) -> void:
	if rider not in Game.rapportlist:
		Game.rapportlist.append(rider)


func bot_transfert(team: Team) -> void:
	var budget_transfert: int = team.budget_transfer
	var budget_salary:    int = team.budget_salary
	if budget_transfert <= 0:
		return

	var candidates: Array = []
	for other_team in Game.team_list:
		if other_team.folder == team.folder:
			continue
		for rider in other_team.riders:
			var block_key: String = rider.full_name() + "_" + team.folder
			if Game.blocked_riders.has(block_key) and Game.blocked_riders[block_key] > 0:
				continue
			var rider_name: String = rider.full_name()
			if Game.transfer_offers.has(rider_name):
				var already: bool = false
				for offer in Game.transfer_offers[rider_name]:
					if offer["team"] == team.folder:
						already = true
						break
				if already:
					continue
			candidates.append(rider)

	var scored: Array = []
	for rider in candidates:
		var s := _bot_score_rider(rider, team, budget_transfert)
		if s["score"] >= 5:
			scored.append(s)

	if scored.is_empty():
		return

	scored.sort_custom(func(a, b): return a["score"] > b["score"])

	var nb_offres_en_cours := 0
	for offers in Game.transfer_offers.values():
		for offer in offers:
			if offer["team"] == team.folder:
				nb_offres_en_cours += 1

	var chance: float = 0.15 if nb_offres_en_cours >= 2 else 0.3
	if randf() > chance:
		return

	var target = null
	if randf() < 0.3:
		var jeunes := scored.filter(func(s): return s["rider"].age() <= 23)
		if not jeunes.is_empty():
			jeunes.sort_custom(func(a, b):
				var ra: int = (a["rider"].maxcob + a["rider"].maxhll + a["rider"].maxmtn + a["rider"].maxgc + a["rider"].maxitt + a["rider"].maxspr) / 6
				var rb: int = (b["rider"].maxcob + b["rider"].maxhll + b["rider"].maxmtn + b["rider"].maxgc + b["rider"].maxitt + b["rider"].maxspr) / 6
				return ra > rb
			)
			target = jeunes[0]

	if target == null:
		target = scored[0]

	var rider      = target["rider"]
	var rider_name: String = rider.full_name()
	var note:       int = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10

	var ai_salary: int = int(rider.salary * randf_range(1.0, 1.2))
	ai_salary = mini(ai_salary, int(budget_salary * 0.25))
	if ai_salary < rider.salary:
		return

	var age:       int   = rider.age()
	var potentiel: int   = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr) / 6
	var bonus_age: float = 2.0 if age <= 21 else (1.7 if age <= 23 else (1.4 if age <= 25 else (1.2 if age <= 27 else 1.0)))
	var bonus_pot: float = 1.0 + float(potentiel - note) / 100.0
	var valeur:    int   = int(note * 50000 * bonus_age * bonus_pot)
	var ai_transfer: int = int(valeur * randf_range(0.7, 1.1))
	ai_transfer = mini(ai_transfer, budget_transfert)

	if ai_salary > budget_transfert:
		return

	var deadline: int = Game.total_days + randi_range(7, 10)

	if not Game.transfer_offers.has(rider_name):
		Game.transfer_offers[rider_name] = []

	Game.transfer_offers[rider_name].append({
		"team": team.folder,
		"salary": ai_salary,
		"transfer": ai_transfer,
		"promises": [],
		"deadline": deadline,
		"rider": rider
	})

	var block_key: String = rider_name + "_" + team.folder
	Game.blocked_riders[block_key] = deadline - Game.total_days + 1

	print("[BOT] %s fait une offre pour %s (%s € / %s €)" % [
		team.teamname, rider_name, _fmt(ai_salary), _fmt(ai_transfer)
	])

	get_node("/root/Mail").send(
		"transfer",
		"Observateur mercato",
		"🔍 %s prospecte %s" % [team.teamname, rider_name],
		"%s a contacté l'entourage de %s pour un éventuel transfert.\n\nL'agent du coureur étudie la proposition." % [team.teamname, rider_name]
	)


func _bot_score_rider(rider, team: Team, budget_transfert: int) -> Dictionary:
	var score := 0
	var age: int = rider.age()
	var note: int = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
	var potentiel: int = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10

	if rider.salary > budget_transfert:
		var fail := {"score": -99, "rider": rider}
		return fail

	if note >= 75:    score += 4
	elif note >= 60:  score += 3
	elif note >= 45:  score += 2

	var ratio: float = float(potentiel) / float(note) if note > 0 else 1.0
	if age <= 23 and ratio >= 1.3:   score += 4
	elif age <= 26 and ratio >= 1.2: score += 3
	elif age <= 29:                  score += 1
	else:                            score -= 1

	var besoins := _team_needs(team)
	var profil  := _detect_profil(rider)
	for besoin in besoins:
		if besoin in profil:
			score += 3

	var salaire_attendu: int = note * 15000
	if rider.salary <= salaire_attendu * 0.8:
		score += 2
	elif rider.salary >= salaire_attendu * 1.5:
		score -= 2

	return {"score": score, "rider": rider}


func simulation() -> void:
	for team in Game.team_list:
		bot_transfert(team)
	_process_transfer_offers()


func _process_transfer_offers() -> void:
	var to_remove: Array[String] = []

	for rider_name in Game.transfer_offers.keys():
		var offers: Array = Game.transfer_offers[rider_name]
		if offers.is_empty():
			continue

		var first_offer = offers[0]
		if Game.total_days < first_offer["deadline"]:
			continue

		var best = _pick_best_offer(offers)
		var won: bool = best["team"] == Game.myteam

		for offer in offers:
			if offer["team"] == best["team"]:
				continue
			if offer["team"] == Game.myteam:
				Game.blocked_riders[rider_name] = randi_range(5, 10)
			else:
				var block_key: String = rider_name + "_" + offer["team"]
				Game.blocked_riders[block_key] = 300

		if won:
			var rider = first_offer["rider"]
			Game.switch_team(rider, rider.team, Game.myteam, best["transfer"])
			get_node("/root/Mail").send(
				"transfer",
				"Agent de %s" % rider_name,
				"✅ Offre acceptée — %s" % rider_name,
				"Bonjour,\n\nAprès examen de toutes les propositions, mon client a décidé d'accepter votre offre.\n\nSalaire : %s € / an\n\nBienvenue dans votre nouvelle recrue !\n\nCordialement,\nAgent de %s" % [_fmt(best["salary"]), rider_name]
			)
		else:
			var player_offered := false
			for offer in offers:
				if offer["team"] == Game.myteam:
					player_offered = true
					break

			var concurrents: Array[String] = []
			for offer in offers:
				if offer["team"] != Game.myteam and offer["team"] != best["team"]:
					concurrents.append(offer["team"])

			var rider = first_offer["rider"]
			Game.switch_team(rider, rider.team, best["team"], best["transfer"])

			if player_offered:
				get_node("/root/Mail").send(
					"transfer",
					"Agent de %s" % rider_name,
					"❌ Offre refusée — %s" % rider_name,
					"Bonjour,\n\nNous vous informons que %s a finalement choisi de rejoindre %s.\n\n%s\n\nL'offre retenue était financièrement plus avantageuse pour mon client.\n\nCordialement,\nAgent de %s" % [
						rider_name,
						best["team"],
						("Équipes concurrentes : %s." % ", ".join(concurrents)) if not concurrents.is_empty() else "",
						rider_name
					]
				)
			else:
				get_node("/root/Mail").send(
					"transfer",
					"Observateur mercato",
					"📰 Transfert — %s rejoint %s" % [rider_name, best["team"]],
					"Information mercato :\n\n%s a quitté son équipe pour rejoindre %s.\n\nPlusieurs équipes s'étaient positionnées sur ce dossier." % [rider_name, best["team"]]
				)

		to_remove.append(rider_name)

	for name in to_remove:
		Game.transfer_offers.erase(name)


func _pick_best_offer(offers: Array) -> Dictionary:
	var best = offers[0]
	for offer in offers:
		var score_best: int = best["salary"] + best["transfer"] + best["promises"].size() * 50000
		var score_curr: int = offer["salary"] + offer["transfer"] + offer["promises"].size() * 50000
		if score_curr > score_best:
			best = offer
	return best


func rapport() -> void:
	for rider in Game.rapportlist:
		var analyse := _analyse_rider(rider)
		var action := ""
		var action_label := ""
		if rider.team != Game.myteam:
			Game.rapport_rider = rider
			action = "meeting_transfer"
			action_label = "📋 Contacter pour transfert"
		get_node("/root/Mail").send(
			"team",
			"Cellule de recrutement",
			"Rapport : %s" % rider.full_name(),
			analyse, "", action, action_label
		)
	Game.rapportlist.clear()


func _analyse_rider(rider) -> String:
	var team       := Team.load_team(Game.myteam)
	var salary:    int = rider.salary
	var age:       int = rider.age()
	var note:      int = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
	var potentiel: int = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10
	var profil     := _detect_profil(rider)
	var besoins    := _team_needs(team)
	var score      := 0
	var raisons: Array[String] = []

	var current_year: int = Time.get_date_dict_from_system()["year"]
	var years_left:   int = rider.contract - current_year
	var valeur_base:  int = note * 50000
	var bonus_age: float  = 1.0
	if age <= 21:    bonus_age = 2.0
	elif age <= 23:  bonus_age = 1.7
	elif age <= 25:  bonus_age = 1.4
	elif age <= 27:  bonus_age = 1.2
	elif age <= 30:  bonus_age = 1.0
	elif age <= 33:  bonus_age = 0.7
	else:            bonus_age = 0.4
	var bonus_potentiel: float = 1.0 + (float(potentiel - note) / 100.0)
	var malus_contrat:   float = 0.5 if years_left <= 1 else (0.8 if years_left == 2 else 1.0)
	var valeur_estimee:  int   = int(valeur_base * bonus_age * bonus_potentiel * malus_contrat)
	raisons.append("💰 Valeur estimée : %s €" % _fmt(valeur_estimee))

	var budget_transfert: int = team.budget_transfer
	if salary > budget_transfert:
		score -= 5
		raisons.append("🚫 HORS BUDGET — (%s €) dépasse le budget transfert (%s €)" % [_fmt(salary), _fmt(budget_transfert)])
	elif salary <= valeur_estimee * 0.5:
		score += 3
		raisons.append("✅ Sous-coté — bien en dessous de sa valeur (%s €)" % _fmt(valeur_estimee))
	elif salary <= valeur_estimee * 0.8:
		score += 2
		raisons.append("✅ Prix correct par rapport à sa valeur (%s €)" % _fmt(valeur_estimee))
	elif salary <= valeur_estimee * 1.2:
		score += 1
		raisons.append("ℹ️ Prix dans la norme (%s €)" % _fmt(valeur_estimee))
	elif salary <= valeur_estimee * 1.6:
		score -= 1
		raisons.append("⚠️ Surcoté par rapport à sa valeur (%s €)" % _fmt(valeur_estimee))
	else:
		score -= 3
		raisons.append("❌ Très surcoté — bien au dessus de sa valeur (%s €)" % _fmt(valeur_estimee))

	if salary > note * 30000:
		score -= 3
		raisons.append("❌ Salaire très élevé (%s €)" % _fmt(salary))
	elif salary > note * 20000:
		score -= 1
		raisons.append("⚠️ Salaire élevé (%s €)" % _fmt(salary))
	elif salary > note * 15000:
		score += 1
		raisons.append("✅ Salaire raisonnable (%s €)" % _fmt(salary))
	elif salary > note * 10000:
		score += 2
		raisons.append("✅ Salaire intéressant (%s €)" % _fmt(salary))
	else:
		score += 3
		raisons.append("✅ Salaire très intéressant (%s €)" % _fmt(salary))

	var ratio: float = float(potentiel) / float(note) if note > 0 else 1.0
	if age <= 21:
		score += 5 if ratio >= 1.4 else 3
		raisons.append("✅ %s (%d ans) — (%d → %d)" % [("Pépite absolue" if ratio >= 1.4 else "Très jeune"), age, note, potentiel])
	elif age <= 23:
		score += 4 if ratio >= 1.3 else 2
		raisons.append("✅ %s (%d ans) — (%d → %d)" % [("Jeune talent" if ratio >= 1.3 else "Jeune"), age, note, potentiel])
	elif age <= 26:
		score += 3 if ratio >= 1.2 else 1
		raisons.append("%s (%d ans) — (%d → %d)" % [("✅ En progression" if ratio >= 1.2 else "ℹ️ En développement"), age, note, potentiel])
	elif age <= 29:
		score += 2 if ratio >= 1.1 else 1
		raisons.append("ℹ️ Fleur de l'âge (%d ans) — (%d → %d)" % [age, note, potentiel])
	elif age <= 32:
		if ratio >= 1.05: score += 1
		raisons.append("⚠️ Coureur mature (%d ans) — (%d → %d)" % [age, note, potentiel])
	else:
		score -= 2
		raisons.append("❌ Vétéran (%d ans) — aucune progression (%d/100)" % [age, note])

	for besoin in besoins:
		if besoin in profil:
			score += 2
			raisons.append("✅ Profil %s correspond au besoin de l'équipe" % besoin)

	if note >= 75:
		score += 3; raisons.append("✅ Excellent niveau (%d/100)" % note)
	elif note >= 60:
		score += 2; raisons.append("✅ Bon niveau (%d/100)" % note)
	elif note >= 45:
		score += 1; raisons.append("ℹ️ Niveau moyen (%d/100)" % note)
	else:
		raisons.append("❌ Niveau insuffisant (%d/100)" % note)

	var verdict := ""
	if score >= 8:    verdict = "🌟 RECRUE PRIORITAIRE"
	elif score >= 5:  verdict = "👍 RECRUE INTÉRESSANTE"
	elif score >= 3:  verdict = "🤔 RECRUE POSSIBLE"
	else:             verdict = "👎 PAS RECOMMANDÉ"

	var lines: Array[String] = []
	lines.append("Coureur : %s (%d ans) — %s" % [rider.full_name(), age, rider.team])
	lines.append("Profil : %s" % ", ".join(profil))
	lines.append("Note : %d/100  |  Potentiel : %d/100" % [note, potentiel])
	lines.append("Salaire : %s €" % _fmt(salary))
	lines.append("")
	lines.append("── Analyse ──")
	for r in raisons:
		lines.append(r)
	lines.append("")
	lines.append("── Verdict ──")
	lines.append(verdict)
	return "\n".join(lines)


func _detect_profil(rider) -> Array:
	var profils: Array = []
	if rider.mtn >= 70: profils.append("Grimpeur")
	if rider.spr >= 70: profils.append("Sprinteur")
	if rider.cob >= 70: profils.append("Classicman")
	if rider.hll >= 70: profils.append("Puncheur")
	if rider.itt >= 70: profils.append("Rouleur")
	if rider.gc  >= 70: profils.append("Leader GC")
	if rider.flt >= 70: profils.append("Plat")
	if profils.is_empty(): profils.append("Polyvalent")
	return profils


func _team_needs(team: Team) -> Array:
	var needs: Array = []
	if team.rider_count() == 0:
		return needs
	var leaders := {"mtn":0,"spr":0,"cob":0,"hll":0,"itt":0,"gc":0}
	var bons    := {"mtn":0,"spr":0,"cob":0,"hll":0,"itt":0,"gc":0}
	for rider in team.riders:
		for stat in leaders.keys():
			var val: int = rider.get(stat)
			if val >= 80:   leaders[stat] += 1
			elif val >= 65: bons[stat]    += 1
	var map := {"mtn":"Grimpeur","spr":"Sprinteur","cob":"Classicman","hll":"Puncheur","itt":"Rouleur","gc":"Leader GC"}
	for stat in leaders.keys():
		if leaders[stat] == 0:
			needs.append(map[stat])
	return needs


func _analyse_prolongation(rider) -> String:
	var age:       int   = rider.age()
	var salary:    int   = rider.salary
	var contract:  int   = rider.contract
	var note:      int   = (rider.cob + rider.hll + rider.mtn + rider.gc + rider.itt + rider.spr + rider.flt + rider.or_ + rider.ttl + rider.tts) / 10
	var potentiel: int   = (rider.maxcob + rider.maxhll + rider.maxmtn + rider.maxgc + rider.maxitt + rider.maxspr + rider.maxflt + rider.maxor + rider.maxttl + rider.maxtts) / 10
	var profil             := _detect_profil(rider)
	var team               := Team.load_team(Game.myteam)
	var budget_transfert:  int   = team.budget_transfer
	var ratio:             float = float(potentiel) / float(note) if note > 0 else 1.0
	var score              := 0
	var raisons: Array[String] = []

	if salary > budget_transfert:
		score -= 5
		raisons.append("🚫 HORS BUDGET — Salaire (%s €) dépasse le budget transfert (%s €)" % [_fmt(salary), _fmt(budget_transfert)])
	elif salary <= budget_transfert * 0.3:
		score += 3; raisons.append("✅ Excellent rapport qualité/prix (%s €)" % _fmt(salary))
	elif salary <= budget_transfert * 0.6:
		score += 2; raisons.append("✅ Prix classique (%s €)" % _fmt(salary))
	elif salary <= budget_transfert * 0.9:
		score += 1; raisons.append("⚠️ Prix élevé (%s €)" % _fmt(salary))
	else:
		score -= 2; raisons.append("❌ Prix extrêmement élevé (%s €)" % _fmt(salary))

	if salary > note * 30000:
		score -= 3; raisons.append("❌ Très surpayé (%d/100 mais %s €)" % [note, _fmt(salary)])
	elif salary > note * 20000:
		score -= 1; raisons.append("⚠️ Salaire élevé / niveau (%d/100)" % note)
	elif salary > note * 15000:
		score += 1; raisons.append("✅ Salaire cohérent (%d/100)" % note)
	elif salary > note * 10000:
		score += 2; raisons.append("✅ Salaire intéressant (%d/100)" % note)
	else:
		score += 3; raisons.append("✅ Sous-coté (%d/100, %s €)" % [note, _fmt(salary)])

	if age <= 21:
		score += 5 if ratio >= 1.4 else 3
		raisons.append("✅ %s (%d ans) — (%d → %d)" % [("Pépite" if ratio >= 1.4 else "Très jeune"), age, note, potentiel])
	elif age <= 23:
		score += 4 if ratio >= 1.3 else 2
		raisons.append("✅ Jeune (%d ans) — (%d → %d)" % [age, note, potentiel])
	elif age <= 26:
		score += 3 if ratio >= 1.2 else 1
		raisons.append("ℹ️ En progression (%d ans) — (%d → %d)" % [age, note, potentiel])
	elif age <= 29:
		score += 2 if ratio >= 1.1 else 1
		raisons.append("ℹ️ Fleur de l'âge (%d ans)" % age)
	elif age <= 32:
		if ratio >= 1.05: score += 1
		raisons.append("⚠️ Mature (%d ans)" % age)
	else:
		score -= 2; raisons.append("❌ Vétéran (%d ans)" % age)

	var current_year: int = Time.get_date_dict_from_system()["year"]
	var years_left:   int = contract - current_year
	if years_left <= 1:
		score += 1; raisons.append("🔴 Contrat expire bientôt (%d)" % contract)
	elif years_left == 2:
		raisons.append("🟡 Contrat expire dans 2 ans (%d)" % contract)
	else:
		raisons.append("🟢 Contrat valide jusqu'en %d" % contract)

	if note >= 75:   score += 3; raisons.append("✅ Excellent niveau (%d/100)" % note)
	elif note >= 60: score += 2; raisons.append("✅ Bon niveau (%d/100)" % note)
	elif note >= 45: score += 1; raisons.append("ℹ️ Niveau moyen (%d/100)" % note)
	else:            score -= 1; raisons.append("❌ Niveau insuffisant (%d/100)" % note)

	if rider.happyness >= 75:
		score += 1; raisons.append("✅ Moral excellent (%d/100)" % rider.happyness)
	elif rider.happyness < 40:
		score -= 1; raisons.append("⚠️ Moral bas (%d/100)" % rider.happyness)

	var besoins := _team_needs(team)
	for besoin in besoins:
		if besoin in profil:
			score += 1; raisons.append("✅ Profil %s correspond à un besoin" % besoin)

	var verdict := ""
	if score >= 10:   verdict = "📝 PROLONGER D'URGENCE"
	elif score >= 7:  verdict = "📝 PROLONGER"
	elif score >= 4:  verdict = "⏳ ATTENDRE"
	elif score >= 2:  verdict = "💰 VENDRE"
	else:             verdict = "🚪 LAISSER PARTIR"

	var lines: Array[String] = []
	lines.append("Coureur : %s (%d ans) — %s" % [rider.full_name(), age, rider.team])
	lines.append("Profil : %s" % ", ".join(profil))
	lines.append("Note : %d/100  |  Potentiel : %d/100" % [note, potentiel])
	lines.append("Contrat jusqu'en %d  |  Salaire : %s €" % [contract, _fmt(salary)])
	lines.append("Forme : %d/100  |  Moral : %d/100" % [rider.form, rider.happyness])
	lines.append("")
	lines.append("── Analyse ──")
	for r in raisons: lines.append(r)
	lines.append("")
	lines.append("── Verdict ──")
	lines.append(verdict)
	return "\n".join(lines)


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
