extends Node


func _on_button_down() -> void:
	if Utils.last_panel != null:
		Utils.hideall()
		Utils.last_panel.show()
