class_name BoardView
extends Node2D

const CELL_SIZE := 80

var board: Dictionary = {}

var pending_tiles: Array = []

func set_board(board_data: Dictionary) -> void:
	board = board_data
	queue_redraw()


func _draw() -> void:
	# Tile đã confirm
	for grid_position in board.keys():
		draw_cell(grid_position, Color(0.7, 0.85, 0.95))

	# Tile đang pending
	for tile in pending_tiles:
		draw_cell(tile["position"], Color(0.95, 0.9, 0.55))


func draw_cell(grid_position: Vector2i, color: Color) -> void:
	var screen_position = Vector2(
		grid_position.x * CELL_SIZE,
		grid_position.y * CELL_SIZE
	)

	var rect = Rect2(
		screen_position,
		Vector2(CELL_SIZE, CELL_SIZE)
	)

	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.2, 0.2, 0.2), false, 2.0)
		
func set_pending_move(move: Dictionary) -> void:
	pending_tiles = move["tiles"]
	queue_redraw()
