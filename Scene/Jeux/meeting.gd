extends Panel

var _rider       = null
var _type:       String = ""
var _step:       int    = 0
var _max_counter_offers: int = 0
var _counter_offers:     int = 0

@onready var title_lbl    := $VBox/Title
@onready var rider_lbl    := $VBox/RiderInfo
@onready var dialogue_lbl := $VBox/Dialogue
@onready var salary_spin  := $VBox/OfferRow/SalaryInput
@onready var transfer_spin:= $VBox/OfferRow/TransferInput
@onready var offer_row    := $VBox/OfferRow
@onready var promise_row  := $VBox/PromiseRow
@onready var action_btn   := $VBox/ActionBtn
@onready var cancel_btn   := $VBox/CancelBtn


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


func _on_cancel() -> void:
	Utils.hideall()
	if Utils.last_panel:
		Utils.last_panel.show()
	hide()

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


func open(type: String, rider) -> void:
	action_btn.visible  = true
	Utils.last_panel    = Utils.current_panel
	Utils.current_panel = self
	_rider = rider
	_type  = type
	_step  = 0
	_max_counter_offers = randi_range(1, 3)
	_counter_offers     = 0

	title_lbl.text = "🤝 Réunion — %s" % _get_type_label()
	rider_lbl.text = "%s · %d ans · %s\nSalaire actuel : %s €  ·  Contrat jusqu'en %d" % [
		rider.full_name(), rider.age(), rider.team, _fmt(rider.salary), rider.contract
	]

	print("blocked_riders: ", Game.blocked_riders)
	print("rider name: ", rider.full_name())
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
		"transfer":    return "Négociation de transfert"
		"prolongation":return "Renouvellement de contrat"
	return "Discussion"


func _step_intro() -> void:
	offer_row.visible   = false
	promise_row.visible = false
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
	offer_row.visible   = true
	promise_row.visible = true
	action_btn.text     = "Soumettre l'offre →"
	cancel_btn.visible  = true
	dialogue_lbl.text   = "Formulez votre offre à l'agent :\nTransfert     Salary"

	salary_spin.min_value = 50000
	salary_spin.max_value = 10000000
	salary_spin.step      = 10000
	salary_spin.value     = _rider.salary

	transfer_spin.visible = _type == "transfer"
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
	cancel_btn.visible  = false

	var result := _evaluate_offer(proposed_salary, proposed_transfer, nb_promises, promises_list)
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
			action_btn.text = "Améliorer l'offre"
			cancel_btn.visible = true


func _step_conclusion(proposed_salary: int, promises_list: Array[String]) -> void:
	var promises_text := "\n".join(promises_list) if not promises_list.is_empty() else "Aucune promesse"
	var deadline: int = Game.total_days + randi_range(7, 10)

	dialogue_lbl.text = "📋 Offre soumise !\n\nVotre offre pour %s a été transmise à son équipe.\n\nSalaire proposé : %s € / an\nPromesses : %s\n\nL'équipe actuelle va examiner toutes les offres reçues et prendra une décision dans les prochains jours." % [
		_rider.full_name(), _fmt(proposed_salary), promises_text
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
		"promises": promises_list,
		"deadline": deadline,
		"rider":    _rider
	})

	get_node("/root/Mail").send_tomorrow(
		"transfer",
		"Agent de %s" % _rider.full_name(),
		"Offre reçue — %s" % _rider.full_name(),
		"Bonjour,\n\nNous avons bien reçu votre offre pour %s.\n\nSalaire proposé : %s € / an\nPromesses incluses : %s\n\nNous allons étudier l'ensemble des propositions reçues et reviendrons vers vous sous peu.\n\nCordialement,\nAgent de %s" % [
			_rider.full_name(), _fmt(proposed_salary), promises_text, _rider.full_name()
		]
	)


func _evaluate_offer(salary: int, transfer: int, nb_promises: int, promises_list: Array[String]) -> Dictionary:
	var score := 0
	var messages: Array[String] = []
	var value := _estimate_value()

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

	if nb_promises >= 3:
		score += 3
		messages.append("« Toutes ces promesses sont très attrayantes pour mon client. »")
	elif nb_promises == 2:
		score += 2
		messages.append("« Ces engagements intéressent mon client. »")
	elif nb_promises == 1:
		score += 1
		messages.append("« La promesse incluse est appréciée. »")

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
	var malus_contract: float = 0.5 if years_left <= 1 else (0.8 if years_left == 2 else 1.0)
	return int(note * 50000 * bonus_age * bonus_pot * malus_contract)


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
