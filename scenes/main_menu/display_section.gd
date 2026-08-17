extends HBoxContainer

@onready var windowed_button: Button = $WindowedButton
@onready var fullscreen_button: Button = $FullscreenButton

func _ready():
	update_indicator()

func _on_windowed_button_pressed():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	update_indicator()

func _on_fullscreen_button_pressed():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_indicator()

func update_indicator():
	var mode = DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		windowed_button.text = "Windowed"
		fullscreen_button.text = "✓ Fullscreen"
	else:
		windowed_button.text = "✓ Windowed"
		fullscreen_button.text = "Fullscreen"
