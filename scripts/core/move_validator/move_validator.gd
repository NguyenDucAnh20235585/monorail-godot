class_name MoveValidator
extends RefCounted

const OK: String = "OK"
const GAME_FINISHED: String = "GAME_FINISHED"
const WRONG_PLAYER: String = "WRONG_PLAYER"
const INVALID_TILE_COUNT: String = "INVALID_TILE_COUNT"
const NOT_ENOUGH_TILES: String = "NOT_ENOUGH_TILES"
const INVALID_TILE_DATA: String = "INVALID_TILE_DATA"
const DUPLICATE_POSITION: String = "DUPLICATE_POSITION"
const CELL_OCCUPIED: String = "CELL_OCCUPIED"
const TILES_NOT_ADJACENT: String = "TILES_NOT_ADJACENT"
const NOT_TOUCHING_BOARD: String = "NOT_TOUCHING_BOARD"
const TRACK_MISMATCH: String = "TRACK_MISMATCH"
const CLOSED_LOOP_NOT_FINAL: String = "CLOSED_LOOP_NOT_FINAL"

# ----------------------------------------------------------------------------
# Hàm chính

static func validate_move(state: GameState, move: Dictionary) -> Dictionary:
	if state.phase == GameState.GamePhase.GAME_FINISHED:
		return _fail(GAME_FINISHED, "Ván đấu đã kết thúc.", [])

	# --- Đúng người chơi ---
	if not move.has("player_id") or move["player_id"] != state.current_player:
		return _fail(
			WRONG_PLAYER,
			"Chưa đến lượt của người chơi này.",
			[]
		)

	# --- Số lượng tile ---
	if not move.has("tiles") or typeof(move["tiles"]) != TYPE_ARRAY:
		return _fail(INVALID_TILE_DATA, "Nước đi không có danh sách tile.", [])

	var tiles: Array = move["tiles"]

	if tiles.is_empty():
		return _fail(INVALID_TILE_COUNT, "Phải đặt ít nhất 1 tile.", [])

	var in_impossible_review := ImpossibleFlow.is_in_review(
		state.impossible_declared_by
)

	if (
		not in_impossible_review
		and tiles.size() > PlacementHelper.MAX_TILES_PER_MOVE
	):
		return _fail(
			INVALID_TILE_COUNT,
			"Mỗi lượt chỉ được đặt tối đa %d tile." % PlacementHelper.MAX_TILES_PER_MOVE,
			_collect_positions(tiles)
		)

	if tiles.size() > state.remaining_tiles:
		return _fail(
			NOT_ENOUGH_TILES,
			"Chỉ còn %d tile, không đủ cho nước đi này." % state.remaining_tiles,
			_collect_positions(tiles)
		)

	# --- Định dạng từng tile ---
	for tile in tiles:
		if not _is_valid_move_tile(tile):
			return _fail(
				INVALID_TILE_DATA,
				"Dữ liệu tile không hợp lệ.",
				_collect_positions(tiles)
			)

	# --- Trùng ô trong cùng một move ---
	var seen: Dictionary = {}
	var duplicates: Array[Vector2i] = []
	for tile in tiles:
		var position: Vector2i = tile["position"]
		if seen.has(position):
			if not duplicates.has(position):
				duplicates.append(position)
		seen[position] = true

	if not duplicates.is_empty():
		return _fail(
			DUPLICATE_POSITION,
			"Không được đặt hai tile vào cùng một ô.",
			duplicates
		)

	# --- Đè lên tile đã có ---
	var occupied: Array[Vector2i] = []
	for tile in tiles:
		var position: Vector2i = tile["position"]
		if state.board.has(position):
			occupied.append(position)

	if not occupied.is_empty():
		return _fail(
			CELL_OCCUPIED,
			"Không được đặt đè lên tile đã có trên bàn.",
			occupied
		)

	# --- Luật vị trí ---
	var positions: Array[Vector2i] = _collect_positions(tiles)

	if in_impossible_review:
		if not _are_tiles_placeable_sequentially(state.board, tiles):
			return _fail(
				NOT_TOUCHING_BOARD,
				"Mỗi tile phải được đặt kề với board tại thời điểm đặt.",
				positions
			)
	else:
		if not PlacementHelper.is_cluster_contiguous(positions):
			return _fail(
				TILES_NOT_ADJACENT,
				"Các tile đặt trong cùng một lượt phải kề cạnh nhau.",
				positions
			)

		if not PlacementHelper.cluster_touches_board(state.board, positions):
			return _fail(
				NOT_TOUCHING_BOARD,
				"Ít nhất một tile mới phải kề cạnh tile đã có trên bàn.",
				positions
			)

	# --- Kiểm tra hướng ray cho CẢ normal và Impossible ---
	var mismatch_positions := _find_track_mismatches(state.board, tiles)

	if not mismatch_positions.is_empty():
		return _fail(
			TRACK_MISMATCH,
			"Đầu ray không được đâm vào cạnh kín của tile kề.",
			mismatch_positions
		)

	if _creates_invalid_closed_loop(state.board, tiles):
		return _fail(
			CLOSED_LOOP_NOT_FINAL,
			"Không được tạo vòng ray khép kín khi vẫn còn tile nằm ngoài vòng.",
			positions
		)

	return _ok()

# ----------------------------------------------------------------------------
# Nội bộ
# ----------------------------------------------------------------------------

static func _ok() -> Dictionary:
	var empty: Array[Vector2i] = []
	return {
		"is_valid": true,
		"error_code": OK,
		"message": "",
		"invalid_positions": empty,
	}

static func _fail(code: String, message: String, positions: Array) -> Dictionary:
	var invalid: Array[Vector2i] = []
	for position in positions:
		invalid.append(position)
	return {
		"is_valid": false,
		"error_code": code,
		"message": message,
		"invalid_positions": invalid,
	}


static func _collect_positions(tiles: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile in tiles:
		if tile is Dictionary and tile.has("position"):
			result.append(tile["position"])
	return result


static func _is_valid_move_tile(tile: Variant) -> bool:
	if not tile is Dictionary:
		return false
	if not tile.has("position") or typeof(tile["position"]) != TYPE_VECTOR2I:
		return false
	return MonoTile.is_valid_tile({
		"type": tile.get("type", -1),
		"rotation": tile.get("rotation", -1),
	})

static func _find_track_mismatches(
	board: Dictionary,
	tiles: Array
) -> Array[Vector2i]:
	var invalid: Array[Vector2i] = []

	var simulated_board: Dictionary = board.duplicate(true)

	for tile in tiles:
		simulated_board[tile["position"]] = {
			"type": tile["type"],
			"rotation": tile["rotation"],
		}

	for tile in tiles:
		var position: Vector2i = tile["position"]

		var edges: Array[String] = MonoTile.get_open_edges(
			tile["type"],
			tile["rotation"]
		)

		for edge_key in MonoTile.EDGE_OFFSETS.keys():
			var edge: String = edge_key
			var neighbor_position: Vector2i = (
				position + MonoTile.EDGE_OFFSETS[edge]
			)

			if not simulated_board.has(neighbor_position):
				continue

			var neighbor: Dictionary = simulated_board[neighbor_position]

			var neighbor_edges: Array[String] = MonoTile.get_open_edges(
				neighbor["type"],
				neighbor["rotation"]
			)

			var this_open: bool = edges.has(edge)
			var neighbor_open: bool = neighbor_edges.has(
				MonoTile.OPPOSITE_EDGE[edge]
			)

			if this_open != neighbor_open:
				if not invalid.has(position):
					invalid.append(position)

	return invalid

static func _are_tiles_placeable_sequentially(
	board: Dictionary,
	tiles: Array
) -> bool:
	var simulated_board: Dictionary = board.duplicate(true)

	for tile in tiles:
		var position: Vector2i = tile["position"]
		var touches_board := false

		for edge_key in MonoTile.EDGE_OFFSETS.keys():
			var offset: Vector2i = MonoTile.EDGE_OFFSETS[edge_key]
			var neighbor_position := position + offset

			if simulated_board.has(neighbor_position):
				touches_board = true
				break

		if not touches_board:
			return false

		simulated_board[position] = {
			"type": tile["type"],
			"rotation": tile["rotation"],
		}

	return true

static func _creates_invalid_closed_loop(
	board: Dictionary,
	tiles: Array
) -> bool:
	var simulated_board: Dictionary = board.duplicate(true)

	for tile in tiles:
		simulated_board[tile["position"]] = {
			"type": tile["type"],
			"rotation": tile["rotation"],
		}

	# Nếu toàn bộ board chính là final station loop thì hợp lệ.
	var final_loop: Array[Vector2i] = WinChecker.find_station_loop(simulated_board)

	if not final_loop.is_empty() and final_loop.size() == simulated_board.size():
		return false

	# Nếu tồn tại BẤT KỲ closed loop nào khác thì nước đi không hợp lệ.
	for key in simulated_board.keys():
		var position: Vector2i = key
		var loop: Array[Vector2i] = WinChecker.find_loop(
			simulated_board,
			position
		)

		if not loop.is_empty():
			return true

	return false
