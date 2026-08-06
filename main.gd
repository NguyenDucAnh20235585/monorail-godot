extends Node

var remaining_tiles: int = 24
var current_player: int

var players = {
	0: {
		"name": "Player 1",
		"order": 0
	},
	1: {
		"name": "Player 2",
		"order": 1
	},
}

func _ready():
	current_player = randi_range(0, 1)

	$TurnLabel.text = players[current_player]["name"] + " goes first"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % remaining_tiles


func _on_button_pressed():
	if current_player == 0:
		current_player = 1
	else:
		current_player = 0

	$TurnLabel.text = players[current_player]["name"] + "'s turn"


func _on_place_tile_button_pressed():
	if remaining_tiles > 0:
		remaining_tiles -= 1

	$RemainingTilesLabel.text = "Remaining tiles: %d" % remaining_tiles

	if remaining_tiles == 0:
		$TurnLabel.text = "No tiles left"
