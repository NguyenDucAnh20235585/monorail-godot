class_name RulesEngine
extends RefCounted

const LEFT_START_POS := Vector2i(0, 0)
const RIGHT_START_POS := Vector2i(1, 0)

static func create_initial_state() -> GameState:
	var state := GameState.new()
	state.current_player = randi_range(0, 1)

	return state
