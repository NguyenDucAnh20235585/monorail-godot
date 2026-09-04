extends Node

var game_state: GameState
var selected_tile_type: int = -1
var selected_pending_position = null
var pending_move: PendingMove

enum PlayerController {
	HUMAN,
	AI,
	NETWORK
}

var player_controllers: Array[PlayerController] = []

@onready var player_1_label: Label = $GameplayUI/HUD/MainLayout/TopArea/TopBar/LeftSide/Player1Label
@onready var player_2_label: Label = $GameplayUI/HUD/MainLayout/TopArea/TopBar/RightSide/Player2Label
@onready var remaining_tiles_label: Label = $GameplayUI/HUD/MainLayout/TopArea/TopBar/CenterInfo/RemainingTilesLabel
@onready var impossible_button: Button = $GameplayUI/HUD/MainLayout/BottomArea/BottomLayout/ControlsRow/CenterControls/ImpossibleButton
@onready var game_log: RichTextLabel = $GameplayUI/HUD/MainLayout/BottomArea/BottomLayout/ControlsRow/RightControls/GameLog
@onready var end_game_overlay: Control = $GameplayUI/EndGameOverlay
@onready var winner_label: Label = $GameplayUI/EndGameOverlay/CenterContainer/EndGameContainer/WinnerLabel
@onready var impossible_scene: Control = $GameplayUI/ImpossibleScene
@onready var impossible_message: Label = $GameplayUI/ImpossibleScene/CenterContainer/PanelContainer/Content/MessageLabel
@onready var impossible_action_button: Button = $GameplayUI/ImpossibleScene/CenterContainer/PanelContainer/Content/ButtonRow/DeclareButton
@onready var pause_menu: Control = $GameplayUI/PauseMenu
@onready var hud: Control = $GameplayUI/HUD
@onready var options_menu: Control = $GameplayUI/Options
@onready var pause_content: Control = $GameplayUI/PauseMenu/CenterContainer

func add_game_log(message: String):
	game_log.append_text(message + "\n")

func _ready():
	print("Game mode: ", GameSession.game_mode)
	print("Starting choice: ", GameSession.starting_choice)
	
	game_state = RulesEngine.create_initial_state()
	if GameSession.game_mode == GameSession.GameMode.PVE:
		match GameSession.starting_choice:
			GameSession.StartingChoice.GO_FIRST:
				game_state.current_player = 0

			GameSession.StartingChoice.GO_SECOND:
				game_state.current_player = 1

			GameSession.StartingChoice.RANDOM:
				game_state.current_player = randi_range(0, 1)
				
	if GameSession.game_mode == GameSession.GameMode.PVE:
		player_controllers = [
			PlayerController.HUMAN,
			PlayerController.AI
		]
	else:
		player_controllers = [
			PlayerController.HUMAN,
			PlayerController.HUMAN
		]
	
	reset_pending_move()
	
	$Board.set_board(game_state.board)
	$Board.set_indicators([])

	print("Board: ", game_state.board)
	print("Current player: ", game_state.current_player)
	print("Remaining tiles: ", game_state.remaining_tiles)
	print("Phase: ", game_state.phase)
	print("Winner: ", game_state.winner)
	print(
	"Current controller: ",
	PlayerController.keys()[get_current_controller()]
	)
	
	update_hud()
	game_log.clear()
	add_game_log("Game started.")
	maybe_start_ai_turn()
	
func _on_confirm_button_pressed():
	confirm_move()
	
func update_hud():
	if GameSession.game_mode == GameSession.GameMode.PVE:
		if game_state.current_player == 0:
			player_1_label.text = "⬢ PLAYER"
			player_2_label.text = "AI"
		else:
			player_1_label.text = "PLAYER"
			player_2_label.text = "⬢ AI"
	else:
		if game_state.current_player == 0:
			player_1_label.text = "⬢ PLAYER 1"
			player_2_label.text = "PLAYER 2"
		else:
			player_1_label.text = "PLAYER 1"
			player_2_label.text = "⬢ PLAYER 2"

	remaining_tiles_label.text = "TILES: %d" % game_state.remaining_tiles
	
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		impossible_button.text = "Give Up"
	else:
		impossible_button.text = "IMPOSSIBLE"
		
func get_current_controller() -> PlayerController:
	return player_controllers[game_state.current_player]
	
func maybe_start_ai_turn():
	if get_current_controller() != PlayerController.AI:
		return

	print("AI turn started")

	var action := AIPlayer.choose_action(
		game_state,
		AIPlayer.Difficulty.HEURISTIC,
		game_state.impossible_declared_by
	)

	print("AI action: ", action)
	
	match action["type"]:
		AIPlayer.ACTION_MOVE:
			execute_ai_move(action["move"])

		AIPlayer.ACTION_DECLARE_IMPOSSIBLE:
			execute_ai_declare_impossible()

		AIPlayer.ACTION_NONE:
			print("AI has no action: ", action["reason"])
			add_game_log(action["reason"])
			recover_ai_turn(action["reason"])

func execute_ai_move(move: Dictionary):
	
	var validation_result := MoveValidator.validate_move(game_state, move)

	if not validation_result["is_valid"]:
		print("AI generated invalid move: ", validation_result["message"])
		add_game_log("AI could not use its planned move.")
		recover_ai_turn(validation_result["message"])
		return
	
	for tile in move["tiles"]:
		var added := pending_move.add_tile(
			tile["position"],
			tile["type"],
			tile["rotation"],
			get_pending_tile_limit()
		)

		if not added:
			print("AI failed to add pending tile: ", tile)
			recover_ai_turn("Failed to create pending move.")
			return

	$Board.set_pending_move(pending_move.to_move())
	confirm_move()

func execute_ai_declare_impossible():
	var result := ImpossibleFlow.declare_impossible(
		game_state,
		game_state.current_player,
		0,
		game_state.impossible_declared_by
	)

	if not result["is_valid"]:
		print("AI failed to declare Impossible: ", result["message"])
		add_game_log(result["message"])
		return

	game_state.impossible_declared_by = result["declared_by"]
	game_state.current_player = result["challenger"]

	add_game_log(result["message"])
	start_turn()

func recover_ai_turn(reason: String):
	reset_pending_move()
	$Board.set_pending_move(pending_move.to_move())
	$Board.set_indicators([])

	print("AI recovery: ", reason)

	# AI đang challenge Impossible mà không thể tiếp tục
	# → coi như Give Up, người declare thắng.
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		game_state.winner = game_state.impossible_declared_by
		game_state.phase = GameState.GamePhase.GAME_FINISHED

		add_game_log(
			"AI could not continue the challenge. Player %d wins."
			% (game_state.winner + 1)
		)

		show_end_game(game_state.winner)
		return

	# Normal turn: fallback sang Declare Impossible.
	var result := ImpossibleFlow.declare_impossible(
		game_state,
		game_state.current_player,
		0,
		game_state.impossible_declared_by
	)

	if result["is_valid"]:
		game_state.impossible_declared_by = result["declared_by"]
		game_state.current_player = result["challenger"]

		add_game_log("AI declared Impossible.")
		start_turn()
		return

	# Emergency fallback cho tester build:
	# tuyệt đối không để game đứng ở AI turn.
	print("AI recovery failed. Skipping AI turn.")
	add_game_log("AI could not act. Turn skipped.")

	RulesEngine.end_turn(game_state)
	start_turn()

func start_turn():
	if (
		game_state.remaining_tiles <= 0
		and not ImpossibleFlow.is_in_review(game_state.impossible_declared_by)
	):
		game_state.winner = game_state.current_player
		game_state.phase = GameState.GamePhase.GAME_FINISHED

		add_game_log(
			"No tiles remaining. Player %d wins by Impossible."
			% (game_state.winner + 1)
		)

		show_end_game(game_state.winner)
		return

	reset_pending_move()	
	$Board.set_pending_move(pending_move.to_move())
	$Board.set_indicators([])
	update_hud()
	maybe_start_ai_turn()
	
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

	# Ghi lịch sử nước đi
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

	# --- Impossible review ---
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		var review_result := ImpossibleFlow.resolve_after_move(
			game_state,
			move,
			game_state.impossible_declared_by
		)

		if review_result["is_finished"]:
			game_state.winner = review_result["winner"]
			game_state.phase = GameState.GamePhase.GAME_FINISHED
			add_game_log(review_result["message"])
			show_end_game(game_state.winner)
			return

		# Challenger tiếp tục đi, KHÔNG đổi lượt.
		start_turn()
		return

	# --- Normal game ---
	var win_result := WinChecker.check_win(game_state, move)

	if win_result["is_win"]:
		game_state.winner = win_result["winner"]
		game_state.phase = GameState.GamePhase.GAME_FINISHED
		show_end_game(game_state.winner)
		return

	RulesEngine.end_turn(game_state)
	start_turn()

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
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		return game_state.remaining_tiles

	return mini(3, game_state.remaining_tiles)

func update_placement_indicators():
	var in_review := ImpossibleFlow.is_in_review(
		game_state.impossible_declared_by
	)

	var positions := PlacementHelper.get_placeable_positions(
		game_state.board,
		pending_move.get_tiles(),
		get_pending_tile_limit(),
		in_review
	)

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

	var default_rotation := 1 if selected_tile_type == MonoTile.TileType.STRAIGHT else 0

	var added := pending_move.add_tile(
		grid_pos,
		selected_tile_type,
		default_rotation,
		get_pending_tile_limit()
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

func _on_rotate_button_pressed():
	if selected_pending_position == null:
		return

	var rotated := pending_move.rotate_at(selected_pending_position)

	if not rotated:
		return

	$Board.set_pending_move(pending_move.to_move())

	print("Rotated pending tile at: ", selected_pending_position)
	print("New rotation: ", pending_move.get_tile_at(selected_pending_position)["rotation"])
	
func show_end_game(winner: int):
	if GameSession.game_mode == GameSession.GameMode.PVE:
		if winner == 0:
			winner_label.text = "PLAYER WINS"
		else:
			winner_label.text = "AI WINS"
	else:
		winner_label.text = "PLAYER %d WINS" % (winner + 1)

	end_game_overlay.visible = true

func _on_play_again_button_pressed():
	get_tree().reload_current_scene()

func _on_back_to_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_impossible_button_pressed():
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		impossible_message.text = "Give up? The declaring player will win."
		impossible_action_button.text = "Give up"
		impossible_scene.visible = true
		return

	var check := ImpossibleFlow.can_declare(
		game_state,
		game_state.current_player,
		pending_move.size(),
		game_state.impossible_declared_by
	)

	if not check["is_allowed"]:
		add_game_log(check["message"])
		return

	impossible_message.text = "Declare this monorail impossible?"
	impossible_action_button.text = "Declare"
	impossible_scene.visible = true

func _on_impossible_cancel_button_pressed():
	impossible_scene.visible = false

func _on_impossible_declare_button_pressed():
	if ImpossibleFlow.is_in_review(game_state.impossible_declared_by):
		game_state.winner = game_state.impossible_declared_by
		game_state.phase = GameState.GamePhase.GAME_FINISHED

		impossible_scene.visible = false
		add_game_log(
			"Player %d gave up. Player %d wins."
			% [game_state.current_player + 1, game_state.winner + 1]
		)
		show_end_game(game_state.winner)
		return
		
	var result := ImpossibleFlow.declare_impossible(
		game_state,
		game_state.current_player,
		pending_move.size(),
		game_state.impossible_declared_by
	)

	if not result["is_valid"]:
		add_game_log(result["message"])
		return

	game_state.impossible_declared_by = result["declared_by"]
	game_state.current_player = result["challenger"]

	impossible_scene.visible = false

	add_game_log(result["message"])
	start_turn()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		print("ESC detected | paused = ", get_tree().paused)

		if not get_tree().paused:
			get_viewport().set_input_as_handled()
			_on_menu_button_pressed()

func _on_menu_button_pressed():
	$BoardCamera.reset_drag_state()
	hud.visible = false
	pause_menu.visible = true
	get_tree().paused = true

func _on_resume_button_pressed():
	$BoardCamera.reset_drag_state()
	get_tree().paused = false
	pause_menu.visible = false
	hud.visible = true

func _on_pause_settings_button_pressed():
	pause_content.visible = false
	options_menu.visible = true

func _on_game_options_close_pressed():
	options_menu.visible = false
	pause_content.visible = true
	
func _on_options_back_to_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")

func _on_exit_game_pressed():
	get_tree().paused = false
	get_tree().quit()
