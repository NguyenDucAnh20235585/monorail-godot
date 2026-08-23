extends Node

var game_state: GameState
var selected_tile_type: int = -1
var selected_pending_position = null
var pending_move: PendingMove

@onready var player_1_label: Label = $GameplayUI/HUD/TopRow/Player1Label
@onready var player_2_label: Label = $GameplayUI/HUD/TopRow/Player2Label
@onready var remaining_tiles_label: Label = $GameplayUI/HUD/TopRow/TopCenterZone/RemainingTilesLabel
@onready var game_log: RichTextLabel = $GameplayUI/HUD/BottomRow/RightZone/GameLog
@onready var end_game_overlay: Control = $GameplayUI/EndGameOverlay
@onready var winner_label: Label = $GameplayUI/EndGameOverlay/CenterContainer/EndGameContainer/WinnerLabel

func add_game_log(message: String) -> void:
	game_log.append_text(message + "\n")

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
	
	update_hud()
	game_log.clear()
	add_game_log("Game started.")
	
func _on_confirm_button_pressed():
	confirm_move()
	
func update_hud():
	if game_state.current_player == 0:
		player_1_label.text = "● PLAYER 1"
		player_2_label.text = "PLAYER 2"
	else:
		player_1_label.text = "PLAYER 1"
		player_2_label.text = "● PLAYER 2"

	remaining_tiles_label.text = "TILES: %d" % game_state.remaining_tiles
	
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
	selected_pending_position = null
	$Board.set_selected_pending_position(null)
	
func confirm_move():
	if pending_move.is_empty():
		print("No pending tiles to confirm")
		add_game_log("No tiles to confirm.")
		return

	var move := pending_move.to_move()
	
	var confirmed_player := game_state.current_player + 1
	var straight_count := 0
	var corner_count := 0

	for tile in move["tiles"]:
		if tile["type"] == MonoTile.TileType.STRAIGHT:
			straight_count += 1
		else:
			corner_count += 1

	var validation_result := MoveValidator.validate_move(game_state, move)

	if not validation_result["is_valid"]:
		print("Invalid move: ", validation_result["message"])
		add_game_log("Invalid move: " + validation_result["message"])
		return

	RulesEngine.apply_move(game_state, move)
	$Board.set_board(game_state.board)

	RulesEngine.end_turn(game_state)
	start_turn()
	
	var parts: Array[String] = []

	if straight_count > 0:
		parts.append(
			"%d STRAIGHT tile%s"
			% [straight_count, "" if straight_count == 1 else "s"]
		)

	if corner_count > 0:
		parts.append(
			"%d CORNER tile%s"
			% [corner_count, "" if corner_count == 1 else "s"]
		)

	add_game_log(
		"Player %d placed %s."
		% [confirmed_player, " and ".join(parts)]
	)

	print("Move confirmed")
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Current player: ", game_state.current_player)
	
func cancel_pending_move():
	if pending_move.is_empty():
		return

	pending_move.clear()
	selected_tile_type = -1
	selected_pending_position = null
	
	$Board.set_selected_pending_position(null)
	$Board.set_pending_move(pending_move.to_move())
	$Board.set_indicators([])

	print("Pending move cancelled")
	add_game_log("Move cancelled.")

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

	selected_pending_position = grid_pos
	$Board.set_selected_pending_position(grid_pos)

	update_placement_indicators()

	print("Pending tile added at: ", grid_pos)
	print("Pending tile selected at: ", grid_pos)


func _on_board_pending_tile_clicked(grid_pos: Vector2i):
	selected_pending_position = grid_pos
	$Board.set_selected_pending_position(selected_pending_position)
	print("Pending tile selected at: ", grid_pos)

func _on_rotate_button_pressed() -> void:
	if selected_pending_position == null:
		return

	var rotated := pending_move.rotate_at(selected_pending_position)

	if not rotated:
		return

	$Board.set_pending_move(pending_move.to_move())

	print("Rotated pending tile at: ", selected_pending_position)
	print("New rotation: ", pending_move.get_tile_at(selected_pending_position)["rotation"])
	
func show_end_game(winner: int):
	winner_label.text = "PLAYER %d WINS" % (winner + 1)
	end_game_overlay.visible = true


func _on_play_again_button_pressed():
	get_tree().reload_current_scene()

func _on_back_to_menu_button_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
