extends Panel

var _rider              = null
var _type:       String = ""
var _step:       int    = 0
var _max_counter_offers: int = 0
var _counter_offers:     int = 0
var _salary_requested:   int = 0
var _proposed_years: int = 0

@onready var title_lbl    := $VBox/Title
@onready var rider_lbl    := $VBox/RiderInfo
@onready var dialogue_lbl := $VBox/Dialogue
@onready var salary_spin  := $VBox/OfferRow/SalaryInput
@onready var transfer_spin:= $VBox/OfferRow/TransferInput
@onready var offer_row    := $VBox/OfferRow
@onready var promise_row  := $VBox/PromiseRow
@onready var action_btn   := $VBox/ActionBtn
@onready var cancel_btn   := $VBox/CancelBtn
@onready var contract_spinbox := $VBox/OfferRow/ContractSpinBox


func _ready() -> void:
	dialogue_lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD
	dialogue_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_lbl.custom_minimum_size   = Vector2(100, 0)
	rider_lbl.autowrap_mode            = TextServer.AUTOWRAP_WORD
	rider_lbl.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	rider_lbl.custom_minimum_size      = Vector2(100, 0)
	action_btn.connect("pressed", _on_action)
	cancel_btn.connect("pressed", _on_cancel)
	offer_row.visible   = false
	promise_row.visible = false
	if contract_spinbox:
		contract_spinbox.visible = false


func _on_cancel() -> void:
	Utils.hideall()
	if Utils.last_panel:
		Utils.last_panel.show()
	hide()

func _set_contract_visible(v: bool) -> void:
	if contract_spinbox:
		contract_spinbox.visible = v

func _get_contract_value() -> int:
	if contract_spinbox:
		return int(contract_spinbox.value)
	return Game.date["year"] + 2

func show_meeting() -> void:
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	offer_row.visible   = false
	promise_row.visible = false
	cancel_btn.visible  = false
	action_btn.visible  = false
	title_lbl.text      = "🤝 Réunion"
	rider_lbl.text      = ""
	dialogue_lbl.text   = "Aucune réunion planifiée pour le moment.\n\nRevenez ici après avoir analysé des coureurs ou reçu des offres."
	_step = 4
	show()


func open(type: String, rider, salary_amount: int = 0) -> void:
	action_btn.visible  = true
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	_rider              = rider
	_type               = type
	_step               = 0
	_salary_requested   = salary_amount
	_max_counter_offers = randi_range(1, 3)
	_counter_offers     = 0

	title_lbl.text = "🤝 Réunion — %s" % _get_type_label()
	rider_lbl.text = "%s · %d ans · %s\nSalaire actuel : %s €  ·  Contrat jusqu'en %d" % [
		rider.full_name(), rider.age(), rider.team, _fmt(rider.salary), rider.contract
	]

	if type == "salary":
		_step_salary_intro()
		show()
		return

	var name: String = rider.full_name()
	if type == "transfer" and Game.blocked_riders.has(name) and Game.blocked_riders[name] > Game.total_days:
		offer_row.visible   = false
		promise_row.visible = false
		action_btn.text     = "Fermer"
		cancel_btn.visible  = false
		dialogue_lbl.text   = "L'agent de %s refuse de vous recevoir.\n\n« Mon client ne souhaite pas être contacté par votre équipe pour le moment.»" % rider.full_name()
		_step = 4
		show()
		return

	_step_intro()
	show()


func _get_type_label() -> String:
	match _type:
		"transfer":     return "Négociation de transfert"
		"prolongation": return "Renouvellement de contrat"
		"salary":       return "Demande d'augmentation"
	return "Discussion"


# ═══════════════════════════════════════════════════════════════
#  MODE SALARY
# ═══════════════════════════════════════════════════════════════
func _step_salary_intro() -> void:
	offer_row.visible   = false
	promise_row.visible = false
	_set_contract_visible(false)
	cancel_btn.visible  = true
	action_btn.text     = "Faire une proposition →"

	var note: int = (_rider.cob + _rider.hll + _rider.mtn + _rider.gc + _rider.itt + _rider.spr + _rider.flt + _rider.or_ + _rider.ttl + _rider.tts) / 10
	dialogue_lbl.text = "%s vous demande une augmentation de salaire.\n\n« Bonjour. Mon niveau actuel (%d/100) justifie selon moi une revalorisation. Je souhaite passer à %s € par an. »\n\nSalaire actuel : %s €\nAugmentation demandée : +%s €\nNouveau salaire souhaité : %s €" % [
		_rider.full_name(), note,
		_fmt(_rider.salary + _salary_requested),
		_fmt(_rider.salary),
		_fmt(_salary_requested),
		_fmt(_rider.salary + _salary_requested)
	]
	_step = 10



func _step_salary_offer() -> void:
	offer_row.visible     = true
	promise_row.visible   = false
	transfer_spin.visible = false
	_set_contract_visible(false)
	cancel_btn.visible    = true
	action_btn.text       = "Valider →"
	dialogue_lbl.text     = "Proposez un nouveau salaire à %s :" % _rider.full_name()

	salary_spin.min_value = _rider.salary
	salary_spin.max_value = _rider.salary * 3
	salary_spin.step      = 5000
	salary_spin.value     = _rider.salary + _salary_requested
	_step = 11


func _step_salary_response() -> void:
	var proposed: int = int(salary_spin.value)
	offer_row.visible   = false
	cancel_btn.visible  = false

	var ratio: float = float(proposed) / float(_rider.salary + _salary_requested)

	if proposed >= _rider.salary + _salary_requested:
		# Accepté pleinement
		_apply_salary(proposed)
		dialogue_lbl.text = "✅ %s accepte votre proposition !\n\n« Merci beaucoup. Je suis très motivé à donner le meilleur pour l'équipe. »\n\nNouveau salaire : %s € / an" % [
			_rider.full_name(), _fmt(proposed)
		]
		_rider.happyness = mini(_rider.happyness + 15, 100)
		_save_rider_happyness()
		_step = 4
		action_btn.text = "Fermer"

	elif ratio >= 0.85:
		# Contre-offre proche, acceptée
		_apply_salary(proposed)
		dialogue_lbl.text = "✅ %s accepte votre contre-proposition.\n\n« Ce n'est pas tout à fait ce que j'espérais, mais je comprends les contraintes. »\n\nNouveau salaire : %s € / an" % [
			_rider.full_name(), _fmt(proposed)
		]
		_rider.happyness = mini(_rider.happyness + 5, 100)
		_save_rider_happyness()
		_step = 4
		action_btn.text = "Fermer"

	elif _counter_offers >= _max_counter_offers:
		# Trop de refus — moral en chute
		dialogue_lbl.text = "❌ %s refuse votre offre et quitte la réunion déçu.\n\n« Je pensais que vous me valorisiez davantage. C'est décevant. »\n\nSon moral chute fortement." % _rider.full_name()
		_rider.happyness = maxi(_rider.happyness - 35, 0)
		_save_rider_happyness()
		_step = 4
		action_btn.text = "Fermer"

	else:
		# Peut encore négocier
		_counter_offers += 1
		dialogue_lbl.text = "😤 %s n'est pas satisfait de votre offre.\n\n« %s € c'est en dessous de mes attentes. Je vous laisse une dernière chance. »\n\nIl attend au moins %s €." % [
			_rider.full_name(),
			_fmt(proposed),
			_fmt(_rider.salary + _salary_requested)
		]
		action_btn.text    = "Revoir l'offre →"
		cancel_btn.visible = true
		_step = 12


func _apply_salary(new_salary: int) -> void:
	_rider.salary = new_salary
	var team := Team.load_team(Game.myteam)
	for r in team.riders:
		if r.full_name() == _rider.full_name():
			r.salary = new_salary
			break
	Game._save_team_csv(team)


func _save_rider_happyness() -> void:
	var team := Team.load_team(Game.myteam)
	for r in team.riders:
		if r.full_name() == _rider.full_name():
			r.happyness = _rider.happyness
			break
	Game._save_team_csv(team)


# ═══════════════════════════════════════════════════════════════
#  MODE TRANSFER / PROLONGATION
# ═══════════════════════════════════════════════════════════════
func _step_intro() -> void:
	offer_row.visible   = false
	promise_row.visible = false
	_set_contract_visible(false)
	action_btn.text     = "Faire une offre →"
	cancel_btn.visible  = true

	match _type:
		"transfer":
			dialogue_lbl.text = "L'agent de %s vous reçoit.\n\n« Bonjour. Mon client est ouvert à la discussion, mais sachez qu'il est très apprécié dans son équipe actuelle. Il faudra faire une offre sérieuse pour le convaincre. »\n\nSalaire actuel : %s €\nValeur estimée : %s €" % [
				_rider.full_name(), _fmt(_rider.salary), _fmt(_estimate_value())
			]
		"prolongation":
			dialogue_lbl.text = "Discussion de renouvellement avec %s.\n\n« Mon client apprécie l'équipe, mais il reçoit des offres d'autres équipes. Il faudra proposer quelque chose d'intéressant pour qu'il reste. »\n\nSalaire actuel : %s €\nContrat jusqu'en : %d" % [
				_rider.full_name(), _fmt(_rider.salary), _rider.contract
			]


func _step_offre() -> void:
	offer_row.visible     = true
	promise_row.visible   = true
	transfer_spin.visible = _type == "transfer"
	_set_contract_visible(true)
	cancel_btn.visible    = true
	action_btn.text       = "Soumettre l'offre →"
	dialogue_lbl.text     = "Formulez votre offre à l'agent :"

	salary_spin.min_value = 50000
	salary_spin.max_value = 10000000
	salary_spin.step      = 10000
	salary_spin.value     = _rider.salary

	if contract_spinbox:
		contract_spinbox.min_value = Game.date["year"] + 1
		contract_spinbox.max_value = Game.date["year"] + 6
		contract_spinbox.step      = 1
		contract_spinbox.value     = Game.date["year"] + 2

	if _type == "transfer":
		transfer_spin.min_value = 0
		transfer_spin.max_value = 20000000
		transfer_spin.step      = 50000
		transfer_spin.value     = _estimate_value()

	for child in promise_row.get_children():
		child.queue_free()

	var lbl := Label.new()
	lbl.text = "Promesses :"
	promise_row.add_child(lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	promise_row.add_child(grid)

	for p in [
		["leader",    "🏆 Leader"],
		["races",     "🗓️ Programme"],
		["salary+",   "💰 Augmentation"],
		["freedom",   "🕊️ Liberté"],
		["contract+", "📝 Prolongation"],
	]:
		var cb := CheckBox.new()
		cb.name = p[0]
		cb.text = p[1]
		grid.add_child(cb)


func _step_reponse() -> void:
	var proposed_salary:   int = int(salary_spin.value)
	var proposed_transfer: int = int(transfer_spin.value) if _type == "transfer" else 0
	var proposed_contract: int = _get_contract_value()
	var duration:          int = proposed_contract - Game.date["year"]

	var nb_promises := 0
	var promises_list: Array[String] = []
	for child in promise_row.get_children():
		if child is GridContainer:
			for cb in child.get_children():
				if cb is CheckBox and cb.button_pressed:
					nb_promises += 1
					promises_list.append("• " + cb.text)

	offer_row.visible   = false
	promise_row.visible = false
	_set_contract_visible(false)
	cancel_btn.visible  = false

	var result := _evaluate_offer(proposed_salary, proposed_transfer, nb_promises, promises_list, duration)
	dialogue_lbl.text = result["message"]

	if result["accepted"]:
		_step = 3
		action_btn.text = "✅ Finaliser →"
		_step_conclusion(proposed_salary, promises_list)
	else:
		if _counter_offers >= _max_counter_offers:
			_step = 4
			action_btn.text    = "Fermer"
			cancel_btn.visible = false
			dialogue_lbl.text += "\n\n🚫 L'agent se lève.\n\n« Je suis désolé, nous avons atteint nos limites. Mon client ne souhaite pas donner suite. »"
			var cooldown: int = randi_range(5, 10)
			Game.blocked_riders[_rider.full_name()] = Game.total_days + cooldown
		else:
			_counter_offers += 1
			_step = 2
			action_btn.text    = "Améliorer l'offre"
			cancel_btn.visible = true


func _step_conclusion(proposed_salary: int, promises_list: Array[String]) -> void:
	var proposed_contract: int = _get_contract_value()
	var promises_text := "\n".join(promises_list) if not promises_list.is_empty() else "Aucune promesse"
	var deadline: int = Game.total_days + randi_range(7, 10)

	dialogue_lbl.text = "📋 Offre soumise !\n\nVotre offre pour %s a été transmise.\n\nSalaire proposé : %s € / an\nContrat jusqu'en : %d\nPromesses : %s\n\nL'équipe actuelle va examiner toutes les offres reçues et prendra une décision dans les prochains jours." % [
		_rider.full_name(), _fmt(proposed_salary), proposed_contract, promises_text
	]
	action_btn.text    = "Fermer"
	cancel_btn.visible = false

	var rider_name: String = _rider.full_name()
	if not Game.transfer_offers.has(rider_name):
		Game.transfer_offers[rider_name] = []
	Game.transfer_offers[rider_name].append({
		"team":     Game.myteam,
		"salary":   proposed_salary,
		"transfer": int(transfer_spin.value),
		"contract": proposed_contract,
		"promises": promises_list,
		"deadline": deadline,
		"rider":    _rider
	})


func _evaluate_offer(salary: int, transfer: int, nb_promises: int, promises_list: Array[String], duration: int = 2) -> Dictionary:
	var score := 0
	var messages: Array[String] = []
	var value := _estimate_value()
	var age: int = _rider.age()

	# Salaire — inchangé
	var salary_ratio: float = float(salary) / float(_rider.salary)
	if salary_ratio >= 1.3:
		score += 3
		messages.append("« Votre offre salariale est très généreuse. »")
	elif salary_ratio >= 1.1:
		score += 2
		messages.append("« Le salaire proposé est correct. »")
	elif salary_ratio >= 0.95:
		score += 1
		messages.append("« Le salaire est acceptable mais pas exceptionnel. »")
	else:
		score -= 2
		messages.append("« Le salaire est insuffisant. Mon client mérite mieux. »")

	# Durée du contrat
	if age <= 24:
		# Jeune : préfère court pour renégocier après progression
		if duration <= 2:
			score += 2
			messages.append("« La durée du contrat lui laisse de la flexibilité. »")
		elif duration == 3:
			score += 0
			messages.append("« La durée est un peu longue pour un jeune coureur. »")
		else:
			score -= 2
			messages.append("« Mon client ne veut pas se bloquer aussi longtemps à ce stade de sa carrière. »")
	elif age >= 32:
		# Vétéran : préfère long pour sécurité
		if duration >= 3:
			score += 2
			messages.append("« La durée du contrat offre une belle sécurité à mon client. »")
		elif duration == 2:
			score += 1
			messages.append("« La durée est correcte. »")
		else:
			score -= 1
			messages.append("« Mon client aurait préféré un engagement plus long. »")
	else:
		# Milieu de carrière : équilibré
		if duration == 2 or duration == 3:
			score += 1
			messages.append("« La durée du contrat est raisonnable. »")
		elif duration >= 4:
			score += 2
			messages.append("« Mon client apprécie cet engagement sur la durée. »")

	# Promesses — inchangé
	if nb_promises >= 3:
		score += 3
		messages.append("« Toutes ces promesses sont très attrayantes pour mon client. »")
	elif nb_promises == 2:
		score += 2
		messages.append("« Ces engagements intéressent mon client. »")
	elif nb_promises == 1:
		score += 1
		messages.append("« La promesse incluse est appréciée. »")

	# Transfert — inchangé
	if _type == "transfer":
		var transfer_ratio: float = float(transfer) / float(value) if value > 0 else 0.0
		if transfer_ratio >= 1.2:
			score += 3
			messages.append("« Le prix du transfert est très attractif. »")
		elif transfer_ratio >= 0.9:
			score += 2
			messages.append("« Le montant du transfert est raisonnable. »")
		elif transfer_ratio >= 0.6:
			score += 1
			messages.append("« L'offre de transfert est un peu basse. »")
		else:
			score -= 2
			messages.append("« Ce montant est bien trop bas pour libérer mon client. »")

	if _rider.happyness < 50:
		score += 1
		messages.append("« Mon client est ouvert au changement en ce moment. »")

	var accepted := score >= 5
	var response := ""
	if accepted:
		response = "L'agent sourit.\n\n« Après réflexion, mon client est prêt à signer. »\n\n"
	elif score >= 3:
		response = "L'agent réfléchit.\n\n« C'est une offre intéressante, mais mon client hésite encore. »\n\n"
	else:
		response = "L'agent secoue la tête.\n\n« Je suis désolé, cette offre ne correspond pas aux attentes. »\n\n"

	return {"accepted": accepted, "message": response + "\n".join(messages), "promises": promises_list}


func _estimate_value() -> int:
	var age:       int   = _rider.age()
	var note:      int   = (_rider.cob + _rider.hll + _rider.mtn + _rider.gc + _rider.itt + _rider.spr + _rider.flt + _rider.or_ + _rider.ttl + _rider.tts) / 10
	var potentiel: int   = (_rider.maxcob + _rider.maxhll + _rider.maxmtn + _rider.maxgc + _rider.maxitt + _rider.maxspr + _rider.maxflt + _rider.maxor + _rider.maxttl + _rider.maxtts) / 10
	var bonus_age: float = 1.0
	if age <= 21:   bonus_age = 2.0
	elif age <= 23: bonus_age = 1.7
	elif age <= 25: bonus_age = 1.4
	elif age <= 27: bonus_age = 1.2
	elif age <= 30: bonus_age = 1.0
	elif age <= 33: bonus_age = 0.7
	else:           bonus_age = 0.4
	var bonus_pot:      float = 1.0 + float(potentiel - note) / 100.0
	var years_left:     int   = _rider.contract - Time.get_date_dict_from_system()["year"]
	var malus_contract: float = 0.0 if years_left <= 0 else (0.15 if years_left == 1 else (0.5 if years_left == 2 else 1.0))
	return int(note * 50000 * bonus_age * bonus_pot * malus_contract)


# ═══════════════════════════════════════════════════════════════
#  ACTION BUTTON
# ═══════════════════════════════════════════════════════════════
func _on_action() -> void:
	match _step:
		0:
			_step = 1
			_step_offre()
		1:
			_step_reponse()
		2:
			_step = 1
			_step_offre()
		3, 4:
			Utils.hideall()
			hide()
		# Salary
		10:
			_step_salary_offer()
		11:
			_step_salary_response()
		12:
			_step_salary_offer()
		# Prolongation
		20:
			_step_prolongation_offer()
		21:
			_step_prolongation_response()
		22:
			_step_prolongation_offer()


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
	
func _step_prolongation_intro() -> void:
	offer_row.visible     = false
	promise_row.visible   = false
	transfer_spin.visible = false
	_set_contract_visible(false)
	cancel_btn.visible    = true
	action_btn.text       = "Faire une offre →"

	var note: int = (_rider.cob + _rider.hll + _rider.mtn + _rider.gc + _rider.itt + _rider.spr + _rider.flt + _rider.or_ + _rider.ttl + _rider.tts) / 10
	var salaire_attendu: int = note * 18000
	var current_year: int = Game.date["year"]
	var years_left: int = _rider.contract - current_year

	var humeur := ""
	if _rider.happyness >= 70:
		humeur = "« Je suis bien ici et je souhaite continuer l'aventure. »"
	elif _rider.happyness >= 40:
		humeur = "« Je suis ouvert à la discussion, mais il faudra une offre sérieuse. »"
	else:
		humeur = "« Franchement, je ne suis pas très heureux ici. Il faudra me convaincre. »"

	dialogue_lbl.text = "%s est disponible pour discuter d'une prolongation.\n\n%s\n\nContrat actuel jusqu'en %d (%d an(s) restant(s))\nSalaire actuel : %s €\nSalaire attendu selon son niveau : %s €" % [
		_rider.full_name(), humeur,
		_rider.contract, years_left,
		_fmt(_rider.salary), _fmt(salaire_attendu)
	]
	_step = 20


func _step_prolongation_offer() -> void:
	offer_row.visible     = true
	promise_row.visible   = false
	transfer_spin.visible = false
	_set_contract_visible(true)
	cancel_btn.visible    = true
	action_btn.text       = "Soumettre →"
	dialogue_lbl.text     = "Proposez un nouveau contrat à %s :" % _rider.full_name()

	salary_spin.min_value = _rider.salary * 0.8
	salary_spin.max_value = _rider.salary * 3
	salary_spin.step      = 5000
	salary_spin.value     = _rider.salary

	if contract_spinbox:
		contract_spinbox.min_value = Game.date["year"] + 1
		contract_spinbox.max_value = Game.date["year"] + 5
		contract_spinbox.step      = 1
		contract_spinbox.value     = Game.date["year"] + 2

	_step = 21


func _step_prolongation_response() -> void:
	var proposed_salary: int = int(salary_spin.value)
	var new_contract:    int = _get_contract_value()
	var duration:        int = new_contract - Game.date["year"]

	offer_row.visible   = false
	_set_contract_visible(false)
	cancel_btn.visible  = false

	var note: int = (_rider.cob + _rider.hll + _rider.mtn + _rider.gc + _rider.itt + _rider.spr + _rider.flt + _rider.or_ + _rider.ttl + _rider.tts) / 10
	var salaire_attendu: int = note * 18000
	var score: float = 0.0

	var salary_ratio: float = float(proposed_salary) / float(salaire_attendu)
	if salary_ratio >= 1.2:    score += 3.0
	elif salary_ratio >= 1.0:  score += 2.0
	elif salary_ratio >= 0.85: score += 1.0
	else:                      score -= 2.0

	if _rider.happyness >= 70:   score += 2.0
	elif _rider.happyness >= 50: score += 1.0
	elif _rider.happyness < 30:  score -= 3.0
	elif _rider.happyness < 50:  score -= 1.5

	var age: int = _rider.age()
	if age <= 25 and duration >= 3: score -= 1.0
	if age >= 32 and duration >= 3: score += 1.0

	var potentiel: int = (_rider.maxcob + _rider.maxhll + _rider.maxmtn + _rider.maxgc + _rider.maxitt + _rider.maxspr) / 6
	if float(note) / float(potentiel) < 0.7 and proposed_salary < salaire_attendu:
		score -= 1.5

	var accepted: bool = score >= 2.0

	if accepted:
		_rider.contract  = new_contract
		_rider.salary    = proposed_salary
		_rider.happyness = mini(_rider.happyness + 10, 100)
		var team := Team.load_team(Game.myteam)
		for r in team.riders:
			if r.full_name() == _rider.full_name():
				r.contract  = new_contract
				r.salary    = proposed_salary
				r.happyness = _rider.happyness
				break
		Game._save_team_csv(team)
		dialogue_lbl.text = "✅ %s accepte la prolongation !\n\n« Je suis content de continuer ici. »\n\nNouveau contrat : jusqu'en %d\nNouveau salaire : %s € / an" % [
			_rider.full_name(), new_contract, _fmt(proposed_salary)
		]
		_step = 4
		action_btn.text = "Fermer"
	else:
		if _counter_offers >= _max_counter_offers:
			_rider.happyness = maxi(_rider.happyness - 25, 0)
			var team := Team.load_team(Game.myteam)
			for r in team.riders:
				if r.full_name() == _rider.full_name():
					r.happyness = _rider.happyness
					break
			Game._save_team_csv(team)
			dialogue_lbl.text  = "❌ %s refuse de prolonger.\n\n« Les conditions proposées ne me conviennent pas. Je partirai à la fin de mon contrat. »\n\nSon moral chute fortement." % _rider.full_name()
			_step              = 4
			action_btn.text    = "Fermer"
			cancel_btn.visible = false
		else:
			_counter_offers += 1
			var reason := ""
			if _rider.happyness < 30:
				reason = "« Je ne suis vraiment pas heureux ici. Cette offre ne suffit pas à me convaincre. »"
			elif float(proposed_salary) < float(salaire_attendu) * 0.85:
				reason = "« Le salaire proposé est en dessous de mes attentes. »"
			else:
				reason = "« J'ai besoin d'y réfléchir. Peut-être pouvez-vous améliorer votre offre ? »"
			dialogue_lbl.text  = "😤 %s hésite.\n\n%s" % [_rider.full_name(), reason]
			action_btn.text    = "Revoir l'offre →"
			cancel_btn.visible = true
			_step = 22
