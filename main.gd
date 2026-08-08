extends Node

var game_state: GameState

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
	game_state = RulesEngine.create_initial_state()

	print("Board: ", game_state.board)
	print("Current player: ", game_state.current_player)
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Phase: ", game_state.phase)
	print("Winner: ", game_state.winner)

	$TurnLabel.text = players[game_state.current_player]["name"] + " goes first"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles

	var test_move = {
		"player_id": game_state.current_player,
"tiles": [
	{
		"position": Vector2i(2, 0),
		"type": 0,
		"rotation": 1
	},
	{
		"position": Vector2i(3, 0),
		"type": 0,
		"rotation": 1
	},
	{
		"position": Vector2i(4, 0),
		"type": 0,
		"rotation": 1
	}
]
	}

	RulesEngine.apply_move(game_state, test_move)
	
	print("Board after move: ", game_state.board)
	print("Remaining after move: ", game_state.remaining_tiles)
	
	
func _on_button_pressed():
	if game_state.current_player == 0:
		game_state.current_player = 1
	else:
		game_state.current_player = 0
		
	print("Current player: ", game_state.current_player)

	$TurnLabel.text = players[game_state.current_player]["name"] + "'s turn"


func _on_place_tile_button_pressed():
	if game_state.remaining_tiles > 0:
		game_state.remaining_tiles -= 1

	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles

	if game_state.remaining_tiles == 0:
		$TurnLabel.text = "No tiles left"
