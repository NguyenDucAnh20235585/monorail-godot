extends Node

var game_state: GameState

var pending_move: Dictionary

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
	
	reset_pending_move()
	
	$Board.set_board(game_state.board)

	print("Board: ", game_state.board)
	print("Current player: ", game_state.current_player)
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Phase: ", game_state.phase)
	print("Winner: ", game_state.winner)
	
	$TurnLabel.text = players[game_state.current_player]["name"] + " goes first"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles
	
func _on_button_pressed():
	confirm_pending_move()
	
func _on_place_tile_button_pressed():
	if pending_move["tiles"].size() >= 3:
		print("Pending move already has 3 tiles")
		return

	var next_x = game_state.board.size() + pending_move["tiles"].size()

	pending_move["tiles"].append({
		"position": Vector2i(next_x, 0),
		"type": MonoTile.TileType.STRAIGHT,
		"rotation": 1
	})
	$Board.set_pending_move(pending_move)
	
func update_hud():
	$TurnLabel.text = players[game_state.current_player]["name"] + "'s turn"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles
	
func reset_pending_move():
	pending_move = {
		"player_id": game_state.current_player,
		"tiles": []
	}
	
func confirm_pending_move():
	if pending_move["tiles"].is_empty():
		print("No pending tiles to confirm")
		return

	RulesEngine.apply_move(game_state, pending_move)
	$Board.set_board(game_state.board)

	RulesEngine.end_turn(game_state)

	reset_pending_move()
	$Board.set_pending_move(pending_move)

	update_hud()
	
	print("Move confirmed")
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Current player: ", game_state.current_player)
	
func cancel_pending_move():
	if pending_move["tiles"].is_empty():
		print("No pending tiles to cancel")
		return

	reset_pending_move()
	$Board.set_pending_move(pending_move)

	print("Pending move cancelled")

func _on_cancel_button_pressed() -> void:
	cancel_pending_move()
