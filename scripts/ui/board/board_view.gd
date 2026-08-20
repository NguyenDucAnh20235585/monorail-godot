class_name BoardView
extends Node2D

signal indicator_clicked(grid_pos: Vector2i)

const CELL_SIZE := 80

const STRAIGHT_TEXTURE := preload("res://assets/png/Straight_tile.png")
const CORNER_TEXTURE := preload("res://assets/png/Curve_tile.png")
const STATION_1_TEXTURE := preload("res://assets/png/Station_tile_01.png")
const STATION_2_TEXTURE := preload("res://assets/png/Station_tile_02.png")

signal pending_tile_clicked(grid_pos: Vector2i)

var board: Dictionary = {}

var pending_tiles: Array = []
var indicator_positions: Array = []
var selected_pending_position = null

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
		if grid_position == Vector2i(0, 0):
			draw_station_tile(grid_position, STATION_1_TEXTURE)
		elif grid_position == Vector2i(1, 0):
			draw_station_tile(grid_position, STATION_2_TEXTURE)
		else:
			var tile = board[grid_position]
			draw_tile(
				grid_position,
				tile["type"],
				tile["rotation"],
				false
			)

	# Tile đang pending
	var selected_tile: Dictionary = {}

	for tile in pending_tiles:
		var is_selected: bool = (
			selected_pending_position != null
			and tile["position"] == selected_pending_position
		)

		if is_selected:
			selected_tile = tile
		else:
			draw_tile(
				tile["position"],
				tile["type"],
				tile["rotation"],
				true,
				false
			)

	if not selected_tile.is_empty():
		draw_tile(
			selected_tile["position"],
			selected_tile["type"],
			selected_tile["rotation"],
			true,
			true
		)
	
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

func draw_station_tile(
	grid_position: Vector2i,
	texture: Texture2D
) -> void:
	var screen_position := Vector2(
		grid_position.x * CELL_SIZE,
		grid_position.y * CELL_SIZE
	)

	var rect := Rect2(
		screen_position,
		Vector2(CELL_SIZE, CELL_SIZE)
	)

	draw_texture_rect(texture, rect, false)

func draw_tile(
	grid_position: Vector2i,
	tile_type: int,
	rotation: int,
	pending: bool,
	selected: bool = false
):
	var texture: Texture2D
	var angle := 0.0

	if tile_type == 0: # STRAIGHT
		texture = STRAIGHT_TEXTURE

		if rotation % 2 == 0:
			angle = PI / 2.0
	else: # CORNER
		texture = CORNER_TEXTURE
		angle = rotation * PI / 2.0

	var center := Vector2(
		grid_position.x * CELL_SIZE + CELL_SIZE / 2.0,
		grid_position.y * CELL_SIZE + CELL_SIZE / 2.0
	)

	draw_set_transform(center, angle, Vector2.ONE)

	var rect := Rect2(
		Vector2(-CELL_SIZE / 2.0, -CELL_SIZE / 2.0),
		Vector2(CELL_SIZE, CELL_SIZE)
	)

	var modulate := Color.WHITE
	if pending:
		modulate.a = 0.7

	draw_texture_rect(texture, rect, false, modulate)

	if pending:
		draw_rect(
			rect,
			Color(1.0, 0.85, 0.2),
			false,
			2.0,
			true
		)

	if selected:
		var inset := 2.0
		var inner_rect := Rect2(
			rect.position + Vector2(inset, inset),
			rect.size - Vector2(inset * 2.0, inset * 2.0)
		)

		draw_rect(
			inner_rect,
			Color(0.25, 0.9, 1.0),
			false,
			2.0,
			true
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
func set_pending_move(move: Dictionary) -> void:
	pending_tiles = move["tiles"]
	queue_redraw()
	
func set_selected_pending_position(grid_pos) -> void:
	selected_pending_position = grid_pos
	queue_redraw()
