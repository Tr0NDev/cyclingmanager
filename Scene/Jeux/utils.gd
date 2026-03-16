extends Node

var last_panel = null
var current_panel = null

func hideall() -> void:
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Team").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Rider").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Teams").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Finance").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Sponsor").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Transfert").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/MailBox").hide()
	get_tree().root.get_node("Jeux/CanvasLayer/HBoxContainer/Meeting").hide()
