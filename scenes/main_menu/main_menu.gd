extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Label = $Options
@onready var turn_order: Control = $TurnOrder

func _ready():
	main_buttons.visible = true
	options.visible = false
	turn_order.visible = false

func _on_settings_button_pressed():
	main_buttons.visible = false
	options.visible = true	

func _on_close_options_pressed():
	main_buttons.visible = true
	options.visible = false

func _on_pvp_button_pressed():
	GameSession.game_mode = GameSession.GameMode.PVP
	GameSession.starting_choice = GameSession.StartingChoice.RANDOM
	get_tree().change_scene_to_file("res://main.tscn")

func _on_pve_button_pressed():
	GameSession.game_mode = GameSession.GameMode.PVE
	main_buttons.visible = false
	turn_order.visible = true

func _on_go_first_pressed():
	GameSession.starting_choice = GameSession.StartingChoice.GO_FIRST
	get_tree().change_scene_to_file("res://main.tscn")

func _on_go_second_pressed():
	GameSession.starting_choice = GameSession.StartingChoice.GO_SECOND
	get_tree().change_scene_to_file("res://main.tscn")
	
func _on_random_pressed():
	GameSession.starting_choice = GameSession.StartingChoice.RANDOM
	get_tree().change_scene_to_file("res://main.tscn")

func _on_exit_button_pressed():
	get_tree().quit()
