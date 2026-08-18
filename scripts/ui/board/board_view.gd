class_name BoardView
extends Node2D

signal indicator_clicked(grid_pos: Vector2i)

const CELL_SIZE := 80

signal pending_tile_clicked(grid_pos: Vector2i)

var board: Dictionary = {}

var pending_tiles: Array = []
var indicator_positions: Array = []

func set_board(board_data: Dictionary) -> void:
	board = board_data
	queue_redraw()

func set_indicators(positions: Array) -> void:
	indicator_positions = positions
	queue_redraw()
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_position := to_local(event.position)

			var grid_pos := Vector2i(
				floori(local_position.x / CELL_SIZE),
				floori(local_position.y / CELL_SIZE)
			)

			for tile in pending_tiles:
				if tile["position"] == grid_pos:
					pending_tile_clicked.emit(grid_pos)
					return

			if grid_pos in indicator_positions:
				indicator_clicked.emit(grid_pos)

func _draw():
	
	# DEBUG/TẠM: candidate indicators
	for grid_position in indicator_positions:
		draw_cell(grid_position, Color(0.55, 0.9, 0.65, 0.45))
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
