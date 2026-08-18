extends Node

var game_state: GameState
var selected_tile_type: int = -1
var pending_move: PendingMove

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
	$Board.set_pending_move(pending_move.to_move())
	$Board.set_indicators([])
	update_hud()
	
func reset_pending_move():
	if pending_move == null:
		pending_move = PendingMove.new(game_state.current_player)
	else:
		pending_move.reset_for_player(game_state.current_player)

	selected_tile_type = -1
	
func confirm_move():
	if pending_move.is_empty():
		print("No pending tiles to confirm")
		return

	var move := pending_move.to_move()

	var validation_result := MoveValidator.validate_move(game_state, move)

	if not validation_result["is_valid"]:
		print("Invalid move: ", validation_result["message"])
		return

	RulesEngine.apply_move(game_state, move)
	$Board.set_board(game_state.board)

	RulesEngine.end_turn(game_state)
	start_turn()

	print("Move confirmed")
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Current player: ", game_state.current_player)
	
func cancel_pending_move():
	pending_move.clear()
	selected_tile_type = -1

	$Board.set_pending_move(pending_move.to_move())
	$Board.set_indicators([])

	print("Pending move cancelled")

func _on_cancel_button_pressed():
	cancel_pending_move()
	
func get_pending_tile_limit() -> int:
	return mini(3, game_state.remaining_tiles)

func update_placement_indicators():
	var positions := PlacementHelper.get_placeable_positions(
		game_state.board,
		pending_move.get_tiles()
	)

	if pending_move.size() >= get_pending_tile_limit():
		positions.clear()

	$Board.set_indicators(positions)

func _on_straight_button_pressed():
	selected_tile_type = MonoTile.TileType.STRAIGHT
	update_placement_indicators()
	print("Selected tile: STRAIGHT")

func _on_corner_button_pressed():
	selected_tile_type = MonoTile.TileType.CORNER
	update_placement_indicators()
	print("Selected tile: CORNER")

func _on_board_indicator_clicked(grid_pos: Vector2i):
	if selected_tile_type == -1:
		print("No tile type selected")
		return

	if pending_move.size() >= get_pending_tile_limit():
		print("Pending move reached tile limit")
		return

	var added := pending_move.add_tile(
		grid_pos,
		selected_tile_type,
		0
	)

	if not added:
		return

	$Board.set_pending_move(pending_move.to_move())
	update_placement_indicators()

	print("Pending tile added at: ", grid_pos)
	print("Pending tile count: ", pending_move.size())

func _on_board_pending_tile_clicked(grid_pos: Vector2i):
	var rotated := pending_move.rotate_at(grid_pos)

	if not rotated:
		return

	$Board.set_pending_move(pending_move.to_move())

	print("Rotated pending tile at: ", grid_pos)
	print("New rotation: ", pending_move.get_tile_at(grid_pos)["rotation"])
