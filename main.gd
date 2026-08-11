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
	confirm_move()
	
func update_hud():
	$TurnLabel.text = players[game_state.current_player]["name"] + "'s turn"
	$RemainingTilesLabel.text = "Remaining tiles: %d" % game_state.remaining_tiles
	
func start_turn():
	reset_pending_move()
	$Board.set_pending_move(pending_move)
	$Board.set_indicators([])
	update_hud()
	
func reset_pending_move():
	pending_move = {
		"player_id": game_state.current_player,
		"tiles": []
	}

	selected_tile_type = -1
	
func confirm_move():
	if pending_move["tiles"].is_empty():
		print("No pending tiles to confirm")
		return

	RulesEngine.apply_move(game_state, pending_move)
	$Board.set_board(game_state.board)

	RulesEngine.end_turn(game_state)
	start_turn()
	
	# DEBUG/TẠM
	print("Pending player: ", pending_move["player_id"])
	print("Move confirmed")
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Current player: ", game_state.current_player)
	
func cancel_pending_move():
	reset_pending_move()
	$Board.set_pending_move(pending_move)
	$Board.set_indicators([])

	print("Pending move cancelled")

func _on_cancel_button_pressed():
	cancel_pending_move()
	
func get_pending_tile_limit() -> int:
	return mini(3, game_state.remaining_tiles)

# DEBUG/TẠM: candidate placement theo pending flow, chưa dùng validator thật
func show_debug_indicators():
	var positions: Array = []

	if pending_move["tiles"].is_empty():
		for board_position in game_state.board.keys():
			for neighbor in MonoTile.get_neighbor_positions(board_position):
				if not game_state.board.has(neighbor) and neighbor not in positions:
					positions.append(neighbor)
	else:
		for tile in pending_move["tiles"]:
			for neighbor in MonoTile.get_neighbor_positions(tile["position"]):
				if not game_state.board.has(neighbor) and neighbor not in positions:
					positions.append(neighbor)

	for tile in pending_move["tiles"]:
		positions.erase(tile["position"])

	if pending_move["tiles"].size() >= get_pending_tile_limit():
		positions.clear()

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

	if pending_move["tiles"].size() >= get_pending_tile_limit():
		print("Pending move reached tile limit")
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

func _on_board_pending_tile_clicked(grid_pos: Vector2i):
	for tile in pending_move["tiles"]:
		if tile["position"] == grid_pos:
			var rotated_tile = MonoTile.rotate_tile(tile)

			tile["type"] = rotated_tile["type"]
			tile["rotation"] = rotated_tile["rotation"]

			$Board.set_pending_move(pending_move)

			print("Rotated pending tile at: ", grid_pos)
			print("New rotation: ", tile["rotation"])
			return
