extends VBoxContainer

@onready var team := $"../Team"
@onready var teams := $"../Teams"
@onready var finance := $"../Finance"
@onready var sponsor := $"../Sponsor"
@onready var transfert := $"../Transfert"
@onready var mailbox := $"../MailBox"
@onready var meeting := $"../Meeting"

func _on_myteam_button_down() -> void:
	Utils.hideall()
	team.show_team(Game.myteam)


func _on_teams_button_down() -> void:
	Utils.hideall()
	teams.show_teams()


func _on_finance_button_down() -> void:
	Utils.hideall()
	finance.show_finance()
	


func _on_sponsor_button_down() -> void:
	Utils.hideall()
	sponsor.show_sponsors()


func _on_transfert_button_down() -> void:
	Utils.hideall()
	transfert.show_transfers()


var date = {
	"year": 2026,
	"month": 3,
	"day": 14
}
var debut = true


func _on_mail_box_button_down() -> void:
	if Game.date == date && debut == true:
		debut = false
		Mail._send_welcome()
		Mail._send_test_mails()
	Utils.hideall()
	mailbox.show_mailbox()


func _on_meeting_button_down() -> void:
	Utils.hideall()
	meeting.show_meeting()
