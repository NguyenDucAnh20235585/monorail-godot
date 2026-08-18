class_name RulesEngine
extends RefCounted

const LEFT_START_POS := Vector2i(0, 0)
const RIGHT_START_POS := Vector2i(1, 0)

static func create_initial_state() -> GameState:
	var state := GameState.new()

	state.board = {}
	
	state.board[LEFT_START_POS] = MonoTile.make_tile(
	MonoTile.TileType.STRAIGHT,
	1
)

	state.board[RIGHT_START_POS] = MonoTile.make_tile(
		MonoTile.TileType.STRAIGHT,
		1
)
	
	state.current_player = randi_range(0, 1)
	state.remaining_tiles = 24
	state.phase = GameState.GamePhase.PLACING
	state.winner = -1

	return state

static func apply_move(
	state: GameState,
	move: Dictionary
) -> void:
	var tiles = move["tiles"]

	for tile in tiles:
		var position: Vector2i = tile["position"]

		state.board[position] = {
			"type": tile["type"],
			"rotation": tile["rotation"]
		}

	state.remaining_tiles -= tiles.size()
	
static func end_turn(state: GameState) -> void:
	if state.current_player == 0:
		state.current_player = 1
	else:
		state.current_player = 0
