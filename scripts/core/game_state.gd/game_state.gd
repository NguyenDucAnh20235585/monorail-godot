class_name GameState
extends RefCounted

var game_state: GameState

var board: Dictionary = {}
var current_player: int = -1
var remaining_tiles: int = 24

enum GamePhase {
	PLACING,
	GAME_FINISHED
}

var phase: GamePhase = GamePhase.PLACING
var winner: int = -1
