extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Label = $Options

func _ready():
	main_buttons.visible = true
	options.visible = false

func _on_settings_button_pressed():
	main_buttons.visible = false
	options.visible = true	

func _on_close_options_pressed():
	main_buttons.visible = true
	options.visible = false

func _on_pvp_button_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
