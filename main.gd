extends Node

var game_state: GameState
var selected_tile_type: int = -1
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
	
	$Board.set_indicators([])

	print("Board: ", game_state.board)
	print("Current player: ", game_state.current_player)
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Phase: ", game_state.phase)
	print("Winner: ", game_state.winner)
	
	$TurnLabel.text = players[game_state.current_player]["name"] + " goes first"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles
	
func _on_confirm_button_pressed():
	confirm_pending_move()
	
func update_hud():
	$TurnLabel.text = players[game_state.current_player]["name"] + "'s turn"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles
	
func reset_pending_move():
	pending_move = {
		"player_id": game_state.current_player,
		"tiles": []
	}

	selected_tile_type = -1
	
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

func _on_cancel_button_pressed():
	cancel_pending_move()

# DEBUG/TẠM: candidate positions chưa dùng validator thật
func show_debug_indicators():
	var positions = [
		Vector2i(-1, 0),
		Vector2i(2, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		Vector2i(1, -1),
		Vector2i(1, 1)
	]

	for tile in pending_move["tiles"]:
		positions.erase(tile["position"])

	$Board.set_indicators(positions)

func _on_straight_button_pressed():
	selected_tile_type = MonoTile.TileType.STRAIGHT
	show_debug_indicators()
	print("Selected tile: STRAIGHT")

func _on_corner_button_pressed():
	selected_tile_type = MonoTile.TileType.CORNER
	show_debug_indicators()
	print("Selected tile: CORNER")

func _on_board_indicator_clicked(grid_pos: Vector2i):
	if selected_tile_type == -1:
		print("No tile type selected")
		return

	if pending_move["tiles"].size() >= 3:
		print("Pending move already has 3 tiles")
		return

	var tile = {
		"position": grid_pos,
		"type": selected_tile_type,
		"rotation": 0
	}

	pending_move["tiles"].append(tile)

	$Board.set_pending_move(pending_move)
	show_debug_indicators()

	print("Pending tile added: ", tile)
	print("Pending tile count: ", pending_move["tiles"].size())
