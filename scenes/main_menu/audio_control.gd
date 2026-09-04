extends HSlider

@export var audio_bus_name: String
var audio_bus_id

func _ready():
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)

func _on_value_changed(value: float):
	if value <= 0.001:
		AudioServer.set_bus_mute(audio_bus_id, true)
		return

	AudioServer.set_bus_mute(audio_bus_id, false)
	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(value))
