extends Panel

@onready var race_title  := $VBox/Title
@onready var log_vbox    := $VBox/HSplit/LogPanel/ScrollContainer/VBoxContainer
@onready var result_vbox := $VBox/HSplit/ResultPanel/ScrollContainer/VBoxContainer


func show_today() -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self

	var today_race: Race = null
	for race in Game.race_list:
		if race.date_in_season == "":
			continue
		var parts: Array = race.date_in_season.split("-")
		if parts.size() < 2:
			continue
		var race_month: int = int(parts[0])
		var race_day:   int = int(parts[1])
		if race_month == Game.date["month"] and race_day == Game.date["day"]:
			today_race = race
			break

	if today_race == null:
		race_title.text = "🏁 Résultats"
		for child in log_vbox.get_children():
			child.queue_free()
		for child in result_vbox.get_children():
			child.queue_free()
		var lbl := Label.new()
		lbl.text = "Pas de course aujourd'hui."
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		log_vbox.add_child(lbl)
		show()
		return

	if Game.last_race_lineups.has(today_race.folder):
		show_result(today_race, Game.last_race_lineups[today_race.folder])
	else:
		var all_lineups := Turn._collect_all_lineups(today_race)
		show_result(today_race, all_lineups)


func show_result(race: Race, all_lineups: Dictionary) -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	race_title.text = "🏁 %s — Résultats" % race.name
	log_vbox.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	result_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in log_vbox.get_children():    child.queue_free()
	for child in result_vbox.get_children(): child.queue_free()
	var result := _simulate_race(race, all_lineups)
	_display_log(result["log"])
	_display_results(result["classement"], result["dnf"])
	Game.last_race_classement = result["classement"]  # ← ajoute ici
	show()


# ═══════════════════════════════════════════════════════════════
#  HELPER — résolution du vrai nom d'équipe
# ═══════════════════════════════════════════════════════════════
func _resolve_team_name(team_folder: String) -> String:
	if team_folder == Game.myteam:
		var my_team := Team.load_team(Game.myteam)
		if my_team: return my_team.teamname
	for t in Game.team_list:
		if t.folder == team_folder:
			return t.teamname
	return team_folder


# ═══════════════════════════════════════════════════════════════
#  SIMULATE RACE
# ═══════════════════════════════════════════════════════════════
func _simulate_race(race: Race, all_lineups: Dictionary) -> Dictionary:
	var log:         Array[String] = []
	var all_riders:  Array         = []
	var all_dropped: Array         = []
	var all_crashed: Array         = []

	var favoris:   Array = get_favorites(race, all_lineups)
	var fav_teams: Array = []
	for f in favoris: fav_teams.append(f["team"])
	var fav_names: Array = []
	for f in favoris: fav_names.append(f["name"])

	# ── Construction des riders ────────────────────────────────
	for team_name in all_lineups.keys():
		var team_display: String = _resolve_team_name(team_name)
		for entry in all_lineups[team_name]:
			var race_score: float = entry.get("race_score", 50.0)
			var stat_advantage: float = pow(race_score / 60.0, 1.8)
			var noise_range: float = 0.08 - clampf((race_score - 50.0) / 500.0, 0.0, 0.05)
			var noise: float = randf_range(-noise_range, noise_range)
			var perf: float = race_score * stat_advantage * (1.0 + noise)
			if entry["rider"] in fav_names:
				perf *= randf_range(1.08, 1.18)

			var parts: Array = entry["rider"].split(" ", 2)
			var rider_obj: Rider = null
			if parts.size() >= 2:
				rider_obj = Rider.load_rider(parts[0], parts[1], team_name)

			all_riders.append({
				"name":      entry["rider"],
				"team":      team_name,
				"team_name": team_display,
				"role":      entry["role"],
				"score":     race_score,
				"perf":      perf,
				"cob":       float(rider_obj.cob)  if rider_obj else race_score,
				"hll":       float(rider_obj.hll)  if rider_obj else race_score,
				"mtn":       float(rider_obj.mtn)  if rider_obj else race_score,
				"flt":       float(rider_obj.flt)  if rider_obj else race_score,
				"form":      float(rider_obj.form) if rider_obj else 75.0,
			})

	if all_riders.is_empty():
		return {"log": ["Aucun coureur au départ."], "classement": [], "dnf": []}

	var km_total: int = max(race.distance_km, 100)
	var race_terrain: Dictionary = race.terrain

	var sectors: Array = race.get_sectors()
	sectors.sort_custom(func(a, b): return int(a.get("km_remaining", 0)) > int(b.get("km_remaining", 0)))
	var first_sector_km: int = km_total
	if not sectors.is_empty():
		first_sector_km = int(sectors[0].get("km_remaining", km_total))
	var last_sector_km: int = 0
	if not sectors.is_empty():
		last_sector_km = int(sectors[sectors.size()-1].get("km_remaining", 0))

	# ── Phase 1 : Échappée matinale ───────────────────────────
	var escapers: Array = []
	var peloton:  Array = []

	for r in all_riders:
		if "Échappée" in r["role"] and randf() < 0.80:
			escapers.append(r)
		else:
			peloton.append(r)

	# Extras spontanés — jamais des favoris
	var extra: int = int(randf_range(1, 4))
	for i in extra:
		var non_fav: Array = peloton.filter(func(r): return r["name"] not in fav_names)
		if not non_fav.is_empty():
			var pick = non_fav[randi() % non_fav.size()]
			escapers.append(pick)
			peloton.erase(pick)
		elif not peloton.is_empty():
			var idx: int = randi() % peloton.size()
			escapers.append(peloton[idx])
			peloton.remove_at(idx)

	# ── Chutes ────────────────────────────────────────────────
	var crash_pool: Array = all_riders.filter(func(r): return r["name"] not in fav_names)
	for r in crash_pool:
		if randf() < 0.02:
			all_crashed.append(r)
			peloton.erase(r)
			escapers.erase(r)

	if not all_crashed.is_empty():
		if all_crashed.size() == 1:
			var r = all_crashed[0]
			var crash_msgs: Array = [
				"🚨 Chute ! %s glisse dans un virage et touche le sol — abandon obligatoire." % r["name"],
				"🚨 %s chute lourdement à grande vitesse — il quitte la course sur civière." % r["name"],
				"🚨 Incident malheureux pour %s (%s) — chute et abandon." % [r["name"], r["team_name"]],
			]
			log.append(crash_msgs[randi() % crash_msgs.size()])
		else:
			var noms_crash: Array = all_crashed.map(func(r): return r["name"])
			log.append("🚨 Chute collective ! %d coureurs impliqués : %s" % [
				all_crashed.size(), ", ".join(noms_crash.slice(0, 5))
			])
			log.append("   Plusieurs abandons — la course continue sans eux.")

	if escapers.size() >= 2:
		var noms: Array = escapers.map(func(r): return r["name"]).slice(0, 5)
		log.append("🚴 Échappée matinale de %d coureurs : %s%s" % [
			escapers.size(), ", ".join(noms),
			"..." if escapers.size() > 5 else ""
		])
		if escapers.size() <= 4:
			var equipes: Array = escapers.map(func(r): return r["team_name"])
			log.append("   Représentées : %s." % ", ".join(equipes))
		if not fav_names.is_empty():
			var fav_reaction: Array = [
				"   Les équipes de favoris laissent partir — l'écart sera contrôlé.",
				"   Le peloton ne réagit pas immédiatement, les favoris économisent leurs forces.",
				"   Aucune équipe de favoris ne se lance à la poursuite pour l'instant.",
			]
			log.append(fav_reaction[randi() % fav_reaction.size()])
	elif escapers.size() == 1:
		log.append("🚴 %s (%s) part en solitaire dès le départ." % [escapers[0]["name"], escapers[0]["team_name"]])
		log.append("   Tentative audacieuse — le peloton surveille sans s'affoler.")
	else:
		log.append("🚴 Pas d'échappée — le peloton contrôle dès le départ.")
		if not fav_names.is_empty():
			var ctrl: Array = peloton.filter(func(r): return r["team"] in fav_teams and r["name"] not in fav_names)
			if not ctrl.is_empty():
				log.append("   %s (%s) impose déjà un rythme soutenu en tête de peloton." % [ctrl[0]["name"], ctrl[0]["team_name"]])

	# Timegap initial
	var tg: int = 0
	var km_tg1: int = int(randf_range(first_sector_km + 10, km_total - 10))
	km_tg1 = maxi(km_tg1, 30)
	if not escapers.is_empty():
		tg = escape_timegap(fav_teams, all_riders, escapers, tg)
		log.append("⏱️ %d sec d'avance à %d km de l'arrivée." % [tg, km_tg1])
		if tg > 120:
			log.append("   L'échappée travaille bien — le peloton ne presse pas encore.")
		elif tg < 40:
			log.append("   L'avance reste limitée — les équipes de favoris ne lâchent pas.")

	# ── Phase 2 : Milieu de course ────────────────────────────
	var km_mid_max: int = maxi(km_tg1 - 5, first_sector_km + 15)
	var km_mid_min: int = maxi(first_sector_km + 5, 20)
	if km_mid_min >= km_mid_max:
		km_mid_min = maxi(km_mid_max - 20, 5)

	var nb_attaques: int = int(randf_range(1, 5))
	for _a in nb_attaques:
		if peloton.is_empty(): break
		var candidates: Array = peloton.filter(func(r): return r["team"] in fav_teams)
		var att
		if not candidates.is_empty() and randf() < 0.55:
			att = candidates[randi() % candidates.size()]
		else:
			att = peloton[randi() % peloton.size()]

		var km_att: int = int(randf_range(km_mid_min, km_mid_max))
		var followers: Array = peloton.filter(func(r):
			return r["name"] != att["name"] and r["perf"] >= att["perf"] * 0.90
		)
		var follower_names: Array = followers.map(func(r): return r["name"]).slice(0, 2)

		if att["name"] in fav_names:
			log.append("💥 %s place une accélération à %d km — le peloton explose !" % [att["name"], km_att])
			if not follower_names.is_empty():
				log.append("   %s tente(nt) de suivre la roue." % ", ".join(follower_names))
		elif att["team"] in fav_teams:
			log.append("💥 %s (%s) prend le relais à %d km pour faire le ménage dans le peloton !" % [att["name"], att["team_name"], km_att])
			if not fav_names.is_empty():
				var leader_fav: Array = peloton.filter(func(r): return r["name"] in fav_names)
				if not leader_fav.is_empty():
					log.append("   %s se place dans la roue de son équipier." % leader_fav[0]["name"])
		else:
			log.append("💥 Attaque surprise de %s (%s) à %d km de l'arrivée !" % [att["name"], att["team_name"], km_att])
			if not follower_names.is_empty():
				log.append("   %s réagit immédiatement et part à sa poursuite." % ", ".join(follower_names))
			else:
				log.append("   Personne ne réagit dans le peloton — l'initiative est hardie.")

		var join_chance: float = 0.55 if att["name"] in fav_names else 0.30
		if randf() < join_chance:
			escapers.append(att)
			peloton.erase(att)
			if att["name"] in fav_names:
				log.append("   %s creuse l'écart et rejoint l'échappée — la course bascule !" % att["name"])
				if not fav_teams.is_empty():
					var autres_fav: Array = peloton.filter(func(r): return r["team"] in fav_teams and r["name"] not in fav_names)
					if not autres_fav.is_empty():
						log.append("   %s (%s) est contraint d'accélérer pour limiter les dégâts." % [autres_fav[0]["name"], autres_fav[0]["team_name"]])
			else:
				log.append("   %s s'échappe et fait la jonction avec le groupe de tête." % att["name"])
				if not follower_names.is_empty():
					log.append("   %s n'a pas pu suivre et retombe dans le peloton." % ", ".join(follower_names))
		else:
			if att["name"] in fav_names:
				log.append("   Le peloton se mobilise immédiatement — %s est neutralisé après quelques secondes d'avance." % att["name"])
				if not follower_names.is_empty():
					log.append("   %s avait suivi l'effort — tout le monde se replace." % ", ".join(follower_names))
			else:
				var repris_msgs: Array = [
					"   %s est repris après 300 mètres d'effort. Le peloton contrôle." % att["name"],
					"   Trop court — %s est avalé par le peloton sans avoir pu creuser l'écart." % att["name"],
					"   %s ne passe pas. Il redevient anonyme dans le peloton." % att["name"],
				]
				log.append(repris_msgs[randi() % repris_msgs.size()])

	if not peloton.is_empty() and not fav_teams.is_empty() and randf() < 0.50:
		var ctrl_pool: Array = peloton.filter(func(r): return r["team"] in fav_teams and r["name"] not in fav_names)
		if not ctrl_pool.is_empty():
			var ctrl = ctrl_pool[randi() % ctrl_pool.size()]
			var ctrl_msgs: Array = [
				"🔵 %s (%s) monte en tête de peloton et impose un tempo élevé." % [ctrl["name"], ctrl["team_name"]],
				"🔵 %s (%s) prend les commandes du peloton — l'étau se resserre." % [ctrl["name"], ctrl["team_name"]],
				"🔵 %s (%s) roule à bloc pour son leader — le peloton s'effile." % [ctrl["name"], ctrl["team_name"]],
			]
			log.append(ctrl_msgs[randi() % ctrl_msgs.size()])
			if not escapers.is_empty() and tg > 0:
				log.append("   L'avance de l'échappée commence à fondre sous la pression.")

	if not escapers.is_empty() and randf() < 0.25:
		var non_fav_esc: Array = escapers.filter(func(r): return r["name"] not in fav_names)
		var nb_rejoins: int = mini(int(randf_range(1, 3)), non_fav_esc.size())
		var rejoins_names: Array = []
		for i in nb_rejoins:
			if non_fav_esc.is_empty(): break
			var r = non_fav_esc[randi() % non_fav_esc.size()]
			non_fav_esc.erase(r)
			escapers.erase(r)
			peloton.append(r)
			rejoins_names.append(r["name"])
		if not rejoins_names.is_empty():
			log.append("🔀 %s ne tient plus l'allure — repris par le peloton." % ", ".join(rejoins_names))
			if escapers.size() > 0:
				log.append("   Il reste %d coureur(s) à l'avant." % escapers.size())

	# Timegap intermédiaire
	var km_tg2: int = int(randf_range(maxi(first_sector_km + 3, 15), maxi(first_sector_km + 20, 25)))
	km_tg2 = mini(km_tg2, km_tg1 - 5)
	km_tg2 = maxi(km_tg2, last_sector_km + 5)
	if not escapers.is_empty():
		var tg_prev: int = tg
		tg = escape_timegap(fav_teams, all_riders, escapers, tg)
		log.append("⏱️ %d sec d'avance à %d km de l'arrivée." % [tg, km_tg2])
		if tg < tg_prev - 20:
			log.append("   ⚠️ L'avance chute rapidement — le peloton a clairement accéléré !")
		elif tg > tg_prev + 20:
			log.append("   ✅ L'échappée en profite pour creuser — bonne opération pour les fuyards.")
		elif tg < 25:
			log.append("   ⚠️ L'avance fond dangereusement — les équipes de favoris accélèrent !")
		elif tg > 180:
			log.append("   ✅ L'échappée est solidement installée, le peloton gère sans forcer.")

	# ── Phase 2.5 : Secteurs clés ─────────────────────────────
	var nb_sectors: int = sectors.size()
	for sector_idx in nb_sectors:
		var sector  = sectors[sector_idx]
		var km_rem: int    = int(sector.get("km_remaining", 0))
		var diff:   int    = int(sector.get("difficulty", 1))
		var stype:  String = sector.get("type", "asphalt")
		var sname:  String = sector.get("name", "secteur")
		var slen:   float  = sector.get("length_km", 1.0)

		var is_late_sector: bool = sector_idx >= (nb_sectors / 2)

		var icon: String = "⛰️"
		if stype in ["cobbles", "gravel", "gravel_road"]: icon = "🪨"
		elif stype in ["dirt", "gravel_climb"]:           icon = "🟤"
		log.append("%s %s (%.1f km — difficulté %d/5) à %d km de l'arrivée" % [
			icon, sname, slen, diff, km_rem
		])

		if diff >= 4 and is_late_sector:
			var ambiance: Array = [
				"   Moment clé de la course — tout peut basculer ici.",
				"   La tension monte dans le peloton à l'approche de ce secteur redouté.",
				"   Les équipes se repositionnent — chacun veut être bien placé.",
			]
			log.append(ambiance[randi() % ambiance.size()])

		var base_threshold: float = 30.0 + diff * 4.5
		if slen >= 6.0: base_threshold += 4.0
		if slen < 2.0:  base_threshold -= 3.0
		var fatigue_penalty: float = minf(float(sector_idx) * 0.6, 5.0)
		var survival_threshold: float = base_threshold + fatigue_penalty

		# ── Échappeurs ──
		var esc_survivors: Array = []
		for r in escapers:
			var fit:       float = _sector_fit(r, stype, diff, slen, race_terrain)
			var fav_bonus: float = 12.0 if r["name"] in fav_names else 0.0
			var noise:     float = randf_range(-0.04, 0.04) * fit
			var effective: float = fit + fav_bonus + noise
			var drop_chance: float = 0.0
			if diff >= 3:
				var deficit: float = survival_threshold - effective
				drop_chance = clampf(0.01 + maxf(deficit, 0.0) / 90.0, 0.01, 0.70)
			if randf() < drop_chance:
				var deficit_ratio: float = clampf((survival_threshold - fit) / 20.0, 0.0, 1.0)
				r["perf"] *= lerp(0.78, 0.58, deficit_ratio)
				var drop_msgs: Array = [
					"   ❌ %s explose dans %s — il est lâché et ne peut plus suivre !" % [r["name"], sname],
					"   ❌ %s craque dans %s — ses jambes ne répondent plus !" % [r["name"], sname],
					"   ❌ %s perd pied dans %s — l'effort est trop intense pour lui." % [r["name"], sname],
				]
				log.append(drop_msgs[randi() % drop_msgs.size()])
				if esc_survivors.size() > 0:
					log.append("      Le reste de l'échappée ne l'attend pas et continue à fond.")
				all_dropped.append(r)
			else:
				esc_survivors.append(r)
		escapers = esc_survivors

		# ── Peloton ──
		var survivors:    Array = []
		var dropped_here: Array = []
		for r in peloton:
			var fit:       float = _sector_fit(r, stype, diff, slen, race_terrain)
			var fav_bonus: float = 14.0 if r["name"] in fav_names else 0.0
			var noise:     float = randf_range(-0.04, 0.04) * fit
			var effective: float = fit + fav_bonus + noise
			var drop_chance: float = 0.0
			if diff >= 3:
				var deficit: float = survival_threshold - effective
				drop_chance = clampf(0.01 + maxf(deficit, 0.0) / 90.0, 0.01, 0.70)
			if randf() < drop_chance:
				dropped_here.append(r)
			else:
				survivors.append(r)

		if not dropped_here.is_empty():
			dropped_here.sort_custom(func(a, b):
				return _sector_fit(a, stype, diff, slen, race_terrain) < _sector_fit(b, stype, diff, slen, race_terrain)
			)
			var noms_drop: Array = dropped_here.map(func(r): return r["name"]).slice(0, 4)
			if dropped_here.size() == 1:
				var drop_solo: Array = [
					"   ❌ %s lâche prise dans %s — il est distancé et ne reviendra pas." % [noms_drop[0], sname],
					"   ❌ %s craque dans %s — il perd plusieurs secondes dès les premiers mètres." % [noms_drop[0], sname],
					"   ❌ %s ne peut pas tenir l'allure dans %s et est lâché." % [noms_drop[0], sname],
				]
				log.append(drop_solo[randi() % drop_solo.size()])
			else:
				log.append("   ❌ Sélection dans %s : %s%s lâchés !" % [
					sname, ", ".join(noms_drop),
					"..." if dropped_here.size() > 4 else ""
				])
				if dropped_here.size() >= 3:
					log.append("      Le peloton de tête se réduit comme peau de chagrin.")
			for r in dropped_here:
				var deficit_ratio: float = clampf((survival_threshold - _sector_fit(r, stype, diff, slen, race_terrain)) / 20.0, 0.0, 1.0)
				r["perf"] *= lerp(0.78, 0.58, deficit_ratio)
				all_dropped.append(r)
		peloton = survivors

		if diff >= 4 and is_late_sector and not peloton.is_empty():
			var nb_surv: int = peloton.size()
			if nb_surv <= 5:
				log.append("   Il ne reste que %d coureur(s) en tête — la course est faite." % nb_surv)
			elif nb_surv <= 10:
				log.append("   Groupe de %d coureurs en tête — la bagarre pour la victoire se profile." % nb_surv)

		# ── Attaque sur secteur ──
		if diff >= 3 and not peloton.is_empty():
			var fav_in_pelo: Array = peloton.filter(func(r): return r["name"] in fav_names)
			var avg_pelo_fit: float = _avg_fit(peloton, stype, diff, slen, race_terrain)

			if not fav_in_pelo.is_empty():
				fav_in_pelo.sort_custom(func(a, b):
					return _sector_fit(a, stype, diff, slen, race_terrain) > _sector_fit(b, stype, diff, slen, race_terrain)
				)
				var att = fav_in_pelo[0]
				var att_fit: float = _sector_fit(att, stype, diff, slen, race_terrain)
				var gap: float = att_fit - avg_pelo_fit
				var attack_chance: float = clampf((gap - 4.0) / 18.0, 0.0, 0.90)
				if randf() < attack_chance:
					var chasers: Array = peloton.filter(func(r):
						return r["name"] != att["name"] and _sector_fit(r, stype, diff, slen, race_terrain) >= att_fit * 0.92
					)
					var chaser_names: Array = chasers.map(func(r): return r["name"]).slice(0, 2)
					var att_msgs: Array = [
						"   💥 %s place une attaque foudroyante dans %s !" % [att["name"], sname],
						"   💥 %s accélère brusquement dans %s — c'est le moment qu'il choisit !" % [att["name"], sname],
						"   💥 %s change de rythme dans %s — l'écart se creuse immédiatement !" % [att["name"], sname],
					]
					log.append(att_msgs[randi() % att_msgs.size()])
					if not chaser_names.is_empty():
						log.append("      %s tente(nt) de rester dans sa roue." % ", ".join(chaser_names))
					else:
						log.append("      Personne n'a les jambes pour répondre à son rythme.")
					var escape_chance: float = clampf((gap - 4.0) / 13.0, 0.10, 0.92)
					if randf() < escape_chance:
						escapers.append(att)
						peloton.erase(att)
						if not chaser_names.is_empty():
							log.append("      %s s'envole ! %s essaie de suivre mais creuse dans le vide." % [att["name"], chaser_names[0]])
						else:
							log.append("      %s s'isole en tête — le peloton le regarde partir." % att["name"])
					else:
						if not chaser_names.is_empty():
							log.append("      %s ramène %s — le groupe se reforme." % [chaser_names[0], att["name"]])
						else:
							log.append("      Le peloton se ressaisit collectivement et reprend %s." % att["name"])

			elif not peloton.is_empty():
				peloton.sort_custom(func(a, b):
					return _sector_fit(a, stype, diff, slen, race_terrain) > _sector_fit(b, stype, diff, slen, race_terrain)
				)
				var att = peloton[0]
				var att_fit: float = _sector_fit(att, stype, diff, slen, race_terrain)
				var gap: float = att_fit - avg_pelo_fit
				var attack_chance: float = clampf((gap - 7.0) / 22.0, 0.0, 0.52)
				if randf() < attack_chance:
					var chasers: Array = peloton.filter(func(r):
						return r["name"] != att["name"] and _sector_fit(r, stype, diff, slen, race_terrain) >= att_fit * 0.94
					)
					var chaser_names: Array = chasers.map(func(r): return r["name"]).slice(0, 2)
					log.append("   💥 %s (%s) tente sa chance dans %s !" % [att["name"], att["team_name"], sname])
					if not chaser_names.is_empty():
						log.append("      %s part à sa poursuite." % ", ".join(chaser_names))
					var escape_chance: float = clampf((gap - 7.0) / 18.0, 0.03, 0.52)
					if randf() < escape_chance:
						escapers.append(att)
						peloton.erase(att)
						if not chaser_names.is_empty():
							log.append("      %s s'échappe ! %s n'a pas pu suivre l'effort." % [att["name"], chaser_names[0]])
						else:
							log.append("      %s s'échappe ! Le peloton laisse filer sans réagir." % att["name"])
					else:
						if not chaser_names.is_empty():
							log.append("      %s revient sur %s — tout le monde est repris." % [chaser_names[0], att["name"]])
						else:
							log.append("      %s est repris — l'effort reste sans suite." % att["name"])

		if is_late_sector and diff >= 3 and not escapers.is_empty():
			tg = escape_timegap(fav_teams, all_riders, escapers, tg)
			log.append("⏱️ %d sec d'avance après %s." % [tg, sname])
			if tg < 15:
				log.append("   ⚠️ L'échappée est sur le point d'être reprise !")
			elif tg < 40:
				log.append("   Le peloton revient — ça va se jouer dans les derniers kilomètres.")

	# ── Arrivée au sommet ─────────────────────────────────────
	if race.has_summit_finish():
		log.append("🏔️ Arrivée au sommet — les sprinteurs purs souffrent dans le final.")
		for r in peloton:
			if r.get("mtn", r["score"]) < 58.0:
				r["perf"] *= 0.78
		for r in escapers:
			if r.get("mtn", r["score"]) < 58.0:
				r["perf"] *= 0.78

	# ── Reprise de l'échappée ? ───────────────────────────────
	var km_tg_final: int  = maxi(last_sector_km - 2, 3)
	var escape_caught: bool = false

	if not escapers.is_empty():
		tg = escape_timegap(fav_teams, all_riders, escapers, tg)
		var esc_avg:  float = _avg_perf(escapers)
		var pel_avg:  float = _avg_perf(peloton)
		var fav_in_pelo_count: int = 0
		for r in peloton:
			if r["name"] in fav_names: fav_in_pelo_count += 1
		var fav_pressure: float = 1.0 + fav_in_pelo_count * 0.15
		var tg_factor:    float = clampf(float(tg) / 100.0, 0.20, 3.0)
		var catch_chance: float = clampf(
			((0.28 + (pel_avg - esc_avg) / 60.0) * fav_pressure) / tg_factor,
			0.04, 0.88
		)
		if randf() < catch_chance:
			var chasseurs: Array = peloton.filter(func(r): return r["team"] in fav_teams and r["name"] not in fav_names)
			if not chasseurs.is_empty():
				log.append("🔄 %s (%s) donne tout pour ramener le peloton — l'échappée est reprise à %d km ! (%d sec insuffisants)" % [
					chasseurs[0]["name"], chasseurs[0]["team_name"], km_tg_final, tg
				])
			else:
				log.append("🔄 L'échappée est reprise à %d km de l'arrivée ! Les favoris ont accéléré collectivement. (%d sec insuffisants)" % [km_tg_final, tg])
			if not escapers.is_empty():
				var esc_names: Array = escapers.map(func(r): return r["name"]).slice(0, 2)
				log.append("   %s retombe dans le peloton, épuisé(s) par l'effort de l'échappée." % ", ".join(esc_names))
			peloton.append_array(escapers)
			escapers.clear()
			escape_caught = true
		else:
			log.append("⚡ L'échappée résiste à %d km de l'arrivée — %d sec d'avance !" % [km_tg_final, tg])
			if tg < 20:
				log.append("   ⚠️ Le peloton est à la roue — ça va se jouer dans les derniers hectomètres !")
				if not escapers.is_empty():
					log.append("   %s donne tout pour maintenir l'avance." % escapers[0]["name"])
			elif tg < 60:
				log.append("   😰 L'avantage est mince — chaque virage peut tout changer...")
			else:
				log.append("   ✅ L'échappée a suffisamment d'avance — la victoire se jouera entre les fuyards.")
				if escapers.size() > 1:
					var esc_names: Array = escapers.map(func(r): return r["name"]).slice(0, 3)
					log.append("   En lice : %s." % ", ".join(esc_names))

	# ── Phase 3 : Finale ──────────────────────────────────────
	var km_final: int = maxi(last_sector_km - 1, 3)
	km_final = mini(km_final, 15)
	var solo_winner = null
	# On détecte si c'est un sprint massif pour ajuster les temps ensuite
	var is_mass_sprint: bool = false

	if peloton.size() > 2:
		peloton.sort_custom(func(a, b): return a["perf"] > b["perf"])
		var fav_in_pelo: Array = peloton.filter(func(r): return r["name"] in fav_names)
		var others:      Array = peloton.filter(func(r): return r["name"] not in fav_names)
		var grp_others:  int   = int(randf_range(1, mini(8, others.size() + 1)))
		var groupe_final: Array = []
		groupe_final.append_array(fav_in_pelo)
		groupe_final.append_array(others.slice(0, grp_others))
		var dropped_final: Array = others.slice(grp_others)

		if not dropped_final.is_empty():
			var noms_drop: Array = dropped_final.map(func(r): return r["name"]).slice(0, 3)
			log.append("🏔️ Sélection finale à %d km : %s%s lâchés — le groupe de tête se forme." % [
				km_final, ", ".join(noms_drop),
				"..." if dropped_final.size() > 3 else ""
			])
			if not groupe_final.is_empty():
				var tete: Array = groupe_final.map(func(r): return r["name"]).slice(0, 4)
				log.append("   Groupe de tête : %s%s." % [", ".join(tete), "..." if groupe_final.size() > 4 else ""])
			for r in dropped_final:
				r["perf"] *= randf_range(0.65, 0.82)
				all_dropped.append(r)

		var nb_finales: int = int(randf_range(1, 3))
		for _f in nb_finales:
			if groupe_final.size() <= 1: break
			var fav_candidates: Array = groupe_final.filter(func(r): return r["name"] in fav_names)
			var solo
			if not fav_candidates.is_empty() and randf() < 0.75:
				solo = fav_candidates[randi() % fav_candidates.size()]
			else:
				solo = groupe_final[randi() % groupe_final.size()]

			var km_solo: int = int(randf_range(1, km_final))
			var reactors: Array = groupe_final.filter(func(r):
				return r["name"] != solo["name"] and r["perf"] >= solo["perf"] * 0.93
			)
			var reactor_names: Array = reactors.map(func(r): return r["name"]).slice(0, 2)

			if solo["name"] in fav_names:
				log.append("💨 %s place une attaque sèche à %d km — c'est le moment décisif !" % [solo["name"], km_solo])
				if not reactor_names.is_empty():
					log.append("   %s tente(nt) de répondre." % ", ".join(reactor_names))
				else:
					log.append("   Personne dans le groupe n'a les jambes pour réagir.")
				if randf() < 0.78:
					log.append("   %s prend immédiatement des secondes — le groupe est scié !" % solo["name"])
					if not reactor_names.is_empty():
						log.append("   %s a essayé mais s'est fait distancer dès les premiers mètres." % reactor_names[0])
					groupe_final.erase(solo)
					peloton = groupe_final
					solo_winner = solo
					break
				else:
					if not reactor_names.is_empty():
						log.append("   %s répond présent et ramène %s — l'attaque échoue." % [reactor_names[0], solo["name"]])
					else:
						log.append("   Le groupe se relance collectivement — %s est repris." % solo["name"])
			else:
				log.append("💨 %s tente sa chance à %d km !" % [solo["name"], km_solo])
				if not reactor_names.is_empty():
					log.append("   %s réagit et part à sa poursuite." % reactor_names[0])
				if randf() < 0.40:
					log.append("   %s s'isole en tête et creuse l'écart !" % solo["name"])
					if not reactor_names.is_empty():
						log.append("   %s n'a pas pu suivre — %s est seul devant !" % [reactor_names[0], solo["name"]])
					groupe_final.erase(solo)
					peloton = groupe_final
					solo_winner = solo
					break
				else:
					if not reactor_names.is_empty():
						log.append("   %s revient sur %s — tout le monde est repris." % [reactor_names[0], solo["name"]])
					else:
						log.append("   %s est repris — l'effort n'aura pas suffi." % solo["name"])

		if solo_winner == null:
			peloton = groupe_final
			if peloton.size() >= 2:
				var finaux: Array = peloton.map(func(r): return r["name"]).slice(0, 4)
				log.append("   Le sprint s'annonce entre : %s%s." % [", ".join(finaux), "..." if peloton.size() > 4 else ""])
				# Sprint massif si ≥ 6 dans le groupe de tête
				if peloton.size() >= 6:
					is_mass_sprint = true

	# Attaque dans l'échappée
	if not escape_caught and escapers.size() > 1 and randf() < 0.55:
		escapers.sort_custom(func(a, b): return a["perf"] > b["perf"])
		var att_ech = escapers[0]
		var km_ech_att: int = int(randf_range(1, km_final))
		var ech_chasers: Array = escapers.filter(func(r): return r["name"] != att_ech["name"])
		var ech_chaser_names: Array = ech_chasers.map(func(r): return r["name"]).slice(0, 2)
		log.append("💨 %s accélère dans l'échappée à %d km — il teste ses compagnons !" % [att_ech["name"], km_ech_att])
		if not ech_chaser_names.is_empty():
			log.append("   %s essaie de répondre." % ", ".join(ech_chaser_names))
		if randf() < 0.50:
			log.append("   %s fait la différence — %s ne peut pas suivre l'effort !" % [
				att_ech["name"],
				", ".join(ech_chaser_names) if not ech_chaser_names.is_empty() else "ses compagnons"
			])
			escapers.erase(att_ech)
			escapers.insert(0, att_ech)
			att_ech["perf"] *= randf_range(1.08, 1.18)
		else:
			if not ech_chaser_names.is_empty():
				log.append("   %s revient sur %s — l'échappée reste groupée pour l'arrivée." % [ech_chaser_names[0], att_ech["name"]])
			else:
				log.append("   %s est repris dans l'échappée — le groupe reste uni." % att_ech["name"])

	# ── Phase 4 : Classement & temps ──────────────────────────
	var contenders: Array = []
	if solo_winner != null:
		contenders.append(solo_winner)
	if not escapers.is_empty():
		escapers.sort_custom(func(a, b): return a["perf"] > b["perf"])
		contenders.append_array(escapers)
	peloton.sort_custom(func(a, b): return a["perf"] > b["perf"])
	contenders.append_array(peloton)
	all_dropped.sort_custom(func(a, b): return a["perf"] > b["perf"])
	contenders.append_array(all_dropped)

	if contenders.is_empty():
		return {"log": log, "classement": [], "dnf": all_crashed}

	var winner = contenders[0]

	# ── Calcul des temps ──────────────────────────────────────
	# ── Calcul des temps ──────────────────────────────────────
	var base_time_sec: float = float(km_total) / 38.0 * 3600.0
	var winner_perf: float   = maxf(winner["perf"], 0.01)
	var dnf_list: Array      = all_crashed.duplicate()

	# Détection du contexte d'arrivée pour calibrer les écarts
	# Sprint massif peloton, sprint échappée, ou course sélective
	var is_sprint_finish: bool = (
		# Sprint dans le peloton groupé (échappée reprise ou pas d'échappée)
		(escape_caught and solo_winner == null and peloton.size() >= 4)
		# Sprint dans l'échappée groupée (pas de solo)
		or (not escape_caught and escapers.size() >= 2 and solo_winner == null)
		# Petit groupe sans solo clair
		or (solo_winner == null and peloton.size() >= 3)
	)

	# Taille du groupe de tête concerné par les écarts sprint
	var sprint_group_size: int = 0
	if is_sprint_finish:
		if escape_caught or escapers.is_empty():
			sprint_group_size = peloton.size()
		else:
			sprint_group_size = escapers.size()

	for i in contenders.size():
		var r = contenders[i]
		if i == 0:
			r["time_sec"] = base_time_sec
			r["time_gap"] = 0
		else:
			var ratio: float = clampf(winner_perf / maxf(r["perf"], 0.01), 1.0, 3.0)
			var gap_sec: float = 0.0

			if is_sprint_finish and i < sprint_group_size:
				# Dans le groupe sprint : quelques secondes max, roue à roue
				# 1er → 0s | 2e → 0-2s | 5e → 0-6s | 10e → 0-10s
				gap_sec = float(i) * randf_range(0.0, 1.5)
			else:
				# Hors groupe sprint : écart basé sur la perf
				gap_sec = pow(ratio - 1.0, 0.75) * 1800.0
				gap_sec = clampf(gap_sec, 0.0, 3600.0)
				if gap_sec < 5.0:
					gap_sec = 0.0

			r["time_sec"] = base_time_sec + gap_sec
			r["time_gap"] = int(clampf(gap_sec, 0.0, 3600.0))

		# DNF si > 30% du temps du vainqueur
		var dnf_threshold: float = base_time_sec * 1.30
		if r["time_sec"] > dnf_threshold and i > 0:
			dnf_list.append(r)

	# Retire les DNF du classement final
	var classement_final: Array = contenders.filter(func(r):
		for d in dnf_list:
			if d["name"] == r["name"]: return false
		return true
	)

	# Log des DNF hors chutes
	var dnf_non_crash: Array = dnf_list.filter(func(r):
		for c in all_crashed:
			if c["name"] == r["name"]: return false
		return true
	)
	if not dnf_non_crash.is_empty():
		var dnf_names: Array = dnf_non_crash.map(func(r): return r["name"]).slice(0, 4)
		log.append("🚩 Hors-délais : %s%s — ils ne seront pas classés." % [
			", ".join(dnf_names),
			"..." if dnf_non_crash.size() > 4 else ""
		])

	# ── Messages d'arrivée ────────────────────────────────────
	if solo_winner != null and winner == solo_winner:
		log.append("🏆 %s (%s) résiste magnifiquement et s'impose en solitaire après un numéro de grande classe !" % [winner["name"], winner["team_name"]])
	elif solo_winner != null and winner != solo_winner:
		log.append("🏆 %s (%s) revient sur %s dans les derniers mètres et lui arrache la victoire au sprint !" % [winner["name"], winner["team_name"], solo_winner["name"]])
	elif not escape_caught and not escapers.is_empty() and escapers.has(winner):
		if escapers.size() == 1:
			log.append("🏆 %s (%s) s'impose en solitaire — magnifique numéro de résistance !" % [winner["name"], winner["team_name"]])
		else:
			var noms_ech: Array = escapers.map(func(r): return r["name"]).filter(func(n): return n != winner["name"]).slice(0, 2)
			log.append("🏆 Sprint dans l'échappée — %s (%s) se montre le plus véloce devant %s !" % [
				winner["name"], winner["team_name"], ", ".join(noms_ech)
			])
	elif not escape_caught and not escapers.is_empty() and not escapers.has(winner):
		log.append("🏆 %s (%s) revient sur l'échappée dans les derniers mètres et s'impose d'autorité !" % [winner["name"], winner["team_name"]])
	else:
		var grp_sprint: Array = classement_final.slice(0, mini(classement_final.size(), 15))
		if grp_sprint.size() >= 6:
			log.append("🏆 Sprint massif — %s (%s) lève les bras dans un groupe de %d !" % [
				winner["name"], winner["team_name"], grp_sprint.size()
			])
		elif grp_sprint.size() >= 2:
			var noms_grp: Array = grp_sprint.map(func(r): return r["name"]).slice(0, 4)
			log.append("🏆 %s (%s) s'impose au sprint dans un petit groupe : %s" % [
				winner["name"], winner["team_name"], ", ".join(noms_grp)
			])
		else:
			log.append("🏆 %s (%s) s'impose en solitaire !" % [winner["name"], winner["team_name"]])

	var my_best: int = -1
	for i in classement_final.size():
		if classement_final[i]["team"] == Game.myteam:
			my_best = i + 1
			break
	if my_best != -1:
		if my_best == 1:
			log.append("🎉 Victoire de votre coureur — journée historique pour votre équipe !")
		elif my_best <= 3:
			log.append("🎖️ Podium ! Votre meilleur coureur finit %dème — belle performance !" % my_best)
		elif my_best <= 10:
			log.append("✅ Top 10 ! Votre meilleur coureur finit %dème." % my_best)
		else:
			log.append("📊 Votre meilleur coureur finit %dème." % my_best)
	else:
		for r in dnf_list:
			if r["team"] == Game.myteam:
				if r in all_crashed:
					log.append("😢 Votre coureur a chuté et n'a pas pu terminer la course.")
				else:
					log.append("😢 Votre coureur est hors-délais — journée difficile.")
				break

	return {"log": log, "classement": classement_final, "dnf": dnf_list}


# ═══════════════════════════════════════════════════════════════
#  SECTOR STAT — mapping stat↔secteur
# ═══════════════════════════════════════════════════════════════
func _sector_stat(r: Dictionary, stype: String, slen: float, diff: int, race_terrain: Dictionary) -> float:
	var cob: float = r.get("cob", r.get("score", 50.0))
	var hll: float = r.get("hll", r.get("score", 50.0))
	var mtn: float = r.get("mtn", r.get("score", 50.0))
	var flt: float = r.get("flt", r.get("score", 50.0))

	match stype:
		"cobbles", "gravel", "gravel_road":
			return cob
		"asphalt":
			if diff <= 1:
				return flt
			elif diff == 2:
				if slen < 2.0:
					return hll * 0.85 + flt * 0.15
				else:
					return hll
			elif diff >= 3 and slen < 3.0:
				return hll
			elif diff >= 3 and slen < 6.0:
				var hills_w:   float = float(race_terrain.get("hills",     0))
				var mtn_w:     float = float(race_terrain.get("mountains", 0))
				var total_w:   float = maxf(hills_w + mtn_w, 1.0)
				var hll_ratio: float = hills_w / total_w
				return hll * hll_ratio + mtn * (1.0 - hll_ratio)
			else:
				return mtn * 0.75 + hll * 0.25
		"dirt", "gravel_climb":
			return cob * 0.5 + hll * 0.5
		_:
			return r.get("score", 50.0)


func _sector_fit(r: Dictionary, stype: String, diff: int, slen: float = 1.0, race_terrain: Dictionary = {}) -> float:
	var base: float = _sector_stat(r, stype, slen, diff, race_terrain)
	var form_factor: float = 0.82 + r.get("form", 75.0) / 100.0 * 0.18
	return base * form_factor


func _avg_fit(riders: Array, stype: String, diff: int, slen: float = 1.0, race_terrain: Dictionary = {}) -> float:
	if riders.is_empty(): return 50.0
	var total: float = 0.0
	for r in riders: total += _sector_fit(r, stype, diff, slen, race_terrain)
	return total / riders.size()


func get_favorites(race: Race, all_lineups: Dictionary) -> Array:
	var riders:  Array = []
	var terrain          = race.terrain
	var w_flat: float = float(terrain.get("flat",      0))
	var w_mtn:  float = float(terrain.get("mountains", 0))
	var w_hll:  float = float(terrain.get("hills",     0))
	var w_cob:  float = float(terrain.get("cobbles",   0))
	var w_grv:  float = float(terrain.get("gravel",    0))
	var total:  float = maxf(w_flat + w_mtn + w_hll + w_cob + w_grv, 1.0)
	w_flat /= total; w_mtn /= total; w_hll /= total
	w_cob  /= total; w_grv /= total

	for team_name in all_lineups.keys():
		for entry in all_lineups[team_name]:
			var base:  float = entry.get("race_score", 50.0)
			var parts: Array = entry["rider"].split(" ", 2)
			var rider_obj: Rider = null
			if parts.size() >= 2:
				rider_obj = Rider.load_rider(parts[0], parts[1], team_name)
			var r_flt: float = float(rider_obj.flt) if rider_obj else base
			var r_hll: float = float(rider_obj.hll) if rider_obj else base
			var r_mtn: float = float(rider_obj.mtn) if rider_obj else base
			var r_cob: float = float(rider_obj.cob) if rider_obj else base
			var score: float = 0.0
			score += r_flt * w_flat
			score += r_mtn * w_mtn
			score += r_hll * w_hll
			score += r_cob * (w_cob + w_grv)
			if terrain.get("summit_finish", false): score *= 1.12
			if base < 55.0: score *= 0.80
			elif base < 60.0: score *= 0.90
			riders.append({"name": entry["rider"], "team": team_name, "score": score, "base": base})

	if riders.is_empty(): return []
	riders.sort_custom(func(a, b): return a["score"] > b["score"])
	var top_score: float = riders[0]["score"]
	var result: Array = []
	for r in riders:
		if r["score"] >= top_score * 0.9:
			result.append({"name": r["name"], "team": r["team"]})
		else:
			break
	return result


func escape_timegap(fav_teams: Array, all_riders: Array, escapers: Array, prev_tg: int) -> int:
	var esc_score: float = 0.0
	for r in escapers: esc_score += r.get("score", 50.0)
	esc_score /= max(1, escapers.size())
	var ctrl_score: float = equipier_score_vs_escape(all_riders, fav_teams)
	var ratio: float = clampf(ctrl_score / max(esc_score, 1.0), 0.25, 4.0)
	var base: float = randf_range(10.0, 140.0)
	var new_tg: int = int(base / ratio)
	if prev_tg > 0:
		new_tg = int(lerp(float(prev_tg), float(new_tg), 0.45))
	return clamp(new_tg, 5, 900)


func equipier_score_vs_escape(all_riders: Array, fav_teams: Array) -> float:
	var total: float = 0.0
	var count: int   = 0
	for r in all_riders:
		if "Équipier" in r["role"] and r["team"] in fav_teams:
			total += r.get("score", 50.0)
			count += 1
	if count == 0: return 50.0
	return total / count


# ═══════════════════════════════════════════════════════════════
#  AFFICHAGE
# ═══════════════════════════════════════════════════════════════
func _fmt_time(sec: float) -> String:
	var h: int = int(sec) / 3600
	var m: int = (int(sec) % 3600) / 60
	var s: int = int(sec) % 60
	return "%dh%02dm%02ds" % [h, m, s]


func _fmt_gap(sec: int) -> String:
	if sec == 0: return "m.t."
	if sec < 60: return "+%ds" % sec
	var m: int = sec / 60
	var s: int = sec % 60
	return "+%dm%02ds" % [m, s]


func _display_log(log: Array) -> void:
	var title := Label.new()
	title.text = "📜 Récit de course"
	title.add_theme_font_size_override("font_size", 13)
	log_vbox.add_child(title)
	log_vbox.add_child(HSeparator.new())

	for line in log:
		var lbl := Label.new()
		lbl.text = line
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size   = Vector2(0, 0)

		if line.begins_with("🏆"):
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
			lbl.add_theme_font_size_override("font_size", 13)
		elif line.begins_with("🎉"):
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		elif line.begins_with("🎖️") or line.begins_with("✅ Top"):
			lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
		elif line.begins_with("💥") or line.begins_with("💨"):
			lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.15))
		elif line.begins_with("⚡") or line.begins_with("🔵"):
			lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		elif line.begins_with("🔄"):
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		elif line.begins_with("🏔️"):
			lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		elif line.begins_with("⏱️"):
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.3))
		elif line.begins_with("🔀"):
			lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
		elif line.begins_with("🪨") or line.begins_with("🧱") or line.begins_with("⛰️"):
			lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
			lbl.add_theme_font_size_override("font_size", 12)
		elif line.begins_with("🚨"):
			lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		elif line.begins_with("🚩"):
			lbl.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4))
		elif line.begins_with("      "):
			lbl.add_theme_color_override("font_color", Color(0.58, 0.58, 0.58))
			lbl.add_theme_font_size_override("font_size", 10)
		elif line.begins_with("   "):
			lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.72))
			lbl.add_theme_font_size_override("font_size", 11)

		log_vbox.add_child(lbl)

		if not line.begins_with("   ") and not line.begins_with("      "):
			var sep := HSeparator.new()
			sep.modulate = Color(1, 1, 1, 0.10)
			log_vbox.add_child(sep)


func _display_results(classement: Array, dnf: Array) -> void:
	var title := Label.new()
	title.text = "🏅 Classement"
	title.add_theme_font_size_override("font_size", 13)
	result_vbox.add_child(title)
	result_vbox.add_child(HSeparator.new())

	for i in classement.size():
		var r   = classement[i]
		var row := HBoxContainer.new()

		var pos_lbl := Label.new()
		pos_lbl.text = "%d." % (i + 1)
		pos_lbl.custom_minimum_size.x = 28
		row.add_child(pos_lbl)

		var name_lbl := Label.new()
		name_lbl.text = r["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if r["team"] == Game.myteam:
			name_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(name_lbl)

		var team_lbl := Label.new()
		team_lbl.text = r.get("team_name", r["team"])
		team_lbl.custom_minimum_size.x = 130
		team_lbl.add_theme_font_size_override("font_size", 10)
		team_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		row.add_child(team_lbl)

		var time_lbl := Label.new()
		time_lbl.custom_minimum_size.x = 80
		time_lbl.add_theme_font_size_override("font_size", 10)
		if i == 0:
			time_lbl.text = _fmt_time(r.get("time_sec", 0.0))
			time_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		else:
			var gap: int = r.get("time_gap", 0)
			time_lbl.text = _fmt_gap(gap)
			time_lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.60))
		row.add_child(time_lbl)

		if i == 0:
			var medal := Label.new(); medal.text = "🥇"; row.add_child(medal)
		elif i == 1:
			var medal := Label.new(); medal.text = "🥈"; row.add_child(medal)
		elif i == 2:
			var medal := Label.new(); medal.text = "🥉"; row.add_child(medal)

		result_vbox.add_child(row)

	# ── Section DNF ───────────────────────────────────────────
	if not dnf.is_empty():
		result_vbox.add_child(HSeparator.new())
		var dnf_title := Label.new()
		dnf_title.text = "❌ Abandons / Hors-délais"
		dnf_title.add_theme_font_size_override("font_size", 11)
		dnf_title.add_theme_color_override("font_color", Color(0.7, 0.35, 0.35))
		result_vbox.add_child(dnf_title)

		for r in dnf:
			var row := HBoxContainer.new()

			var icon_lbl := Label.new()
			icon_lbl.text = "🚨" if not r.has("time_sec") else "🚩"
			icon_lbl.custom_minimum_size.x = 28
			row.add_child(icon_lbl)

			var name_lbl := Label.new()
			name_lbl.text = r["name"]
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.add_theme_color_override("font_color", Color(0.55, 0.35, 0.35))
			if r["team"] == Game.myteam:
				name_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
			row.add_child(name_lbl)

			var team_lbl := Label.new()
			team_lbl.text = r.get("team_name", r["team"])
			team_lbl.custom_minimum_size.x = 130
			team_lbl.add_theme_font_size_override("font_size", 10)
			team_lbl.add_theme_color_override("font_color", Color(0.45, 0.35, 0.35))
			row.add_child(team_lbl)

			var status_lbl := Label.new()
			status_lbl.text = "Chute" if not r.has("time_sec") else "H.D."
			status_lbl.custom_minimum_size.x = 80
			status_lbl.add_theme_font_size_override("font_size", 10)
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3))
			row.add_child(status_lbl)

			result_vbox.add_child(row)


func show_stage_result(race: Race, stage_data: Dictionary, all_lineups: Dictionary, state: Dictionary) -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self

	var stage_num:  int    = int(stage_data.get("stage_number", 1))
	var stage_name: String = stage_data.get("name", "Étape %d" % stage_num)
	var total:      int    = race.get_stage_count()

	race_title.text = "🏁 %s — Étape %d/%d : %s" % [race.name, stage_num, total, stage_name]

	log_vbox.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	result_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for child in log_vbox.get_children():    child.queue_free()
	for child in result_vbox.get_children(): child.queue_free()

	# Race temporaire pour la simulation
	var stage_race        := Race.new()
	stage_race.name        = stage_name
	stage_race.distance_km = int(stage_data.get("distance_km", 150))
	stage_race.terrain     = stage_data.get("terrain", {})
	stage_race.profile     = stage_data.get("profile", {})
	stage_race.key_stats   = stage_data.get("key_stats", ["flt"])
	stage_race.type        = "one-day"
	stage_race.uci         = 0
	stage_race.folder      = race.folder
	stage_race.lastwinners = []
	stage_race.stages      = []

	var result := _simulate_race(stage_race, all_lineups)
	Game.last_race_classement = result["classement"]

	_display_log(result["log"])
	_display_stage_results(result["classement"], result["dnf"], state, stage_data)
	show()
	
	
func _display_stage_results(classement: Array, dnf: Array, state: Dictionary, stage_data: Dictionary) -> void:
	var stage_title := Label.new()
	stage_title.text = "🏅 Résultat de l'étape"
	stage_title.add_theme_font_size_override("font_size", 13)
	result_vbox.add_child(stage_title)
	result_vbox.add_child(HSeparator.new())

	for i in mini(classement.size(), 20):
		var r   = classement[i]
		var row := HBoxContainer.new()
		var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 28
		row.add_child(pos)
		var name := Label.new()
		name.text = r["name"]
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if r.get("team", "") == Game.myteam:
			name.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(name)
		var time := Label.new()
		time.custom_minimum_size.x = 80
		time.add_theme_font_size_override("font_size", 10)
		if i == 0:
			time.text = _fmt_time(r.get("time_sec", 0.0))
		else:
			time.text = _fmt_gap(r.get("time_gap", 0))
			time.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(time)
		if i == 0:   var m := Label.new(); m.text = "🥇"; row.add_child(m)
		elif i == 1: var m := Label.new(); m.text = "🥈"; row.add_child(m)
		elif i == 2: var m := Label.new(); m.text = "🥉"; row.add_child(m)
		result_vbox.add_child(row)

	# ── Classement général ────────────────────────────────────
	result_vbox.add_child(HSeparator.new())
	var gc_title := Label.new()
	gc_title.text = "🟡 Classement général"
	gc_title.add_theme_font_size_override("font_size", 12)
	gc_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	result_vbox.add_child(gc_title)

	var gc: Array = state.get("gc", [])
	if not gc.is_empty():
		var stage_times: Dictionary = {}
		for r in classement:
			stage_times[r.get("name", "")] = r.get("time_sec", 0.0)

		var leader_stage_time: float = stage_times.get(gc[0]["name"], 0.0)
		if leader_stage_time == 0.0 and not classement.is_empty():
			leader_stage_time = float(classement[0].get("time_sec", 0.0))

		var gc_leader_cumul: float = float(gc[0].get("time_sec", 0.0)) + leader_stage_time

		for i in mini(gc.size(), 10):
			var r   = gc[i]
			var row := HBoxContainer.new()
			var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 28
			row.add_child(pos)
			var nm := Label.new()
			nm.text = r["name"]
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if r.get("team", "") == Game.myteam:
				nm.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
			row.add_child(nm)
			var gap := Label.new()
			gap.custom_minimum_size.x = 90
			gap.add_theme_font_size_override("font_size", 10)
			if i == 0:
				gap.text = _fmt_time(gc_leader_cumul)
				gap.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
			else:
				var rider_stage_time: float = stage_times.get(r["name"], leader_stage_time)
				var rider_cumul: float = float(r.get("time_sec", 0.0)) + rider_stage_time
				var gc_gap: int = int(rider_cumul - gc_leader_cumul)
				gap.text = _fmt_gap(gc_gap)
				gap.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			row.add_child(gap)
			result_vbox.add_child(row)

	# ── Maillots ──────────────────────────────────────────────
	_display_jersey_points(state.get("points",   []), "🟢 Maillot vert",   Color(0.2, 0.9, 0.3))
	_display_jersey_points(state.get("mountain", []), "🔴 Maillot à pois", Color(1.0, 0.3, 0.3))
	_display_jersey_time( state.get("youth",    []), "⬜ Maillot blanc",  Color(0.9, 0.9, 0.9), 3)

	# ── DNF ───────────────────────────────────────────────────
	if not dnf.is_empty():
		result_vbox.add_child(HSeparator.new())
		var dnf_title := Label.new()
		dnf_title.text = "❌ Abandons"
		dnf_title.add_theme_color_override("font_color", Color(0.7, 0.35, 0.35))
		result_vbox.add_child(dnf_title)
		for r in dnf:
			var row := HBoxContainer.new()
			var icon := Label.new(); icon.text = "🚨"; icon.custom_minimum_size.x = 28
			row.add_child(icon)
			var nm := Label.new()
			nm.text = r["name"]
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.add_theme_color_override("font_color", Color(0.55, 0.35, 0.35))
			row.add_child(nm)
			result_vbox.add_child(row)


func _display_jersey_time(rankings: Array, title: String, color: Color, max_shown: int = 3) -> void:
	if rankings.is_empty(): return
	result_vbox.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	result_vbox.add_child(lbl)
	var leader_time: float = float(rankings[0].get("time_sec", 0.0))
	for i in mini(rankings.size(), max_shown):
		var r   = rankings[i]
		var row := HBoxContainer.new()
		var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 24
		row.add_child(pos)
		var nm := Label.new()
		nm.text = r["name"]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if r.get("team", "") == Game.myteam:
			nm.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(nm)
		var val := Label.new()
		val.custom_minimum_size.x = 80
		val.add_theme_font_size_override("font_size", 10)
		if i == 0:
			val.text = "Leader"
			val.add_theme_color_override("font_color", color)
		else:
			var gap_sec: int = int(float(r.get("time_sec", leader_time)) - leader_time)
			val.text = _fmt_gap(gap_sec)
			val.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(val)
		result_vbox.add_child(row)


func _display_jersey_points(rankings: Array, title: String, color: Color) -> void:
	if rankings.is_empty(): return
	result_vbox.add_child(HSeparator.new())
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	result_vbox.add_child(lbl)
	for i in mini(rankings.size(), 3):
		var r   = rankings[i]
		var row := HBoxContainer.new()
		var pos := Label.new(); pos.text = "%d." % (i + 1); pos.custom_minimum_size.x = 24
		row.add_child(pos)
		var nm := Label.new()
		nm.text = r["name"]
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if r.get("team", "") == Game.myteam:
			nm.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
		row.add_child(nm)
		var val := Label.new()
		val.text = "%d pts" % r.get("points", 0)
		val.custom_minimum_size.x = 60
		val.add_theme_font_size_override("font_size", 10)
		val.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		row.add_child(val)
		result_vbox.add_child(row)

func _avg_perf(riders: Array) -> float:
	if riders.is_empty(): return 0.0
	var total: float = 0.0
	for r in riders: total += r["perf"]
	return total / riders.size()
