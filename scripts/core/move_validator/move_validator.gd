class_name MoveValidator
extends RefCounted

# ============================================================================
# Monorail — Move Validator
# Phụ trách: Khiêm
#
# TRẠNG THÁI: bản Giai đoạn 2. Chữ ký hàm và định dạng kết quả đã CHỐT,
# nội dung luật còn bổ sung tiếp ở Giai đoạn 3. Công nối được confirm_move()
# vào đây ngay bây giờ mà tuần sau không phải sửa lại chỗ nối.
#
# Đã kiểm tra ở bản này:
#   1. Game chưa kết thúc (phase khác GAME_FINISHED).
#   2. player_id khớp current_player.
#   3. Move có 1–3 tile.
#   4. Không vượt quá số tile còn lại.
#   5. Dữ liệu tile đúng định dạng.
#   6. Không có hai tile trong move vào cùng một ô.
#   7. Không đặt đè lên tile đã có trên board.
#   8. Các tile mới phải kề cạnh nhau thành một cụm liền.
#   9. Ít nhất một tile mới phải kề board hiện tại.
#
# CHƯA kiểm tra (Giai đoạn 3):
#   - Luật thẳng hàng (Rules.pdf và Roadmap đang lệch nhau — xem docs).
#   - Điều kiện kết nối đường ray.
#
# validate_move() CHỈ ĐỌC GameState:
#   không sửa board, không giảm remaining_tiles, không chuyển lượt, không đụng UI.
# ============================================================================


# ----------------------------------------------------------------------------
# Mã lỗi
# ----------------------------------------------------------------------------

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


# ----------------------------------------------------------------------------
# Hàm chính
# ----------------------------------------------------------------------------

## Kiểm tra một nước đi.
##
## Trả về ValidationResult:
##   {
##       "is_valid": bool,
##       "error_code": String,
##       "message": String,
##       "invalid_positions": Array[Vector2i]
##   }
##
## Khi hợp lệ: is_valid = true, error_code = "OK", invalid_positions rỗng.
## Chỉ dừng ở lỗi ĐẦU TIÊN tìm thấy — mỗi lần chỉ báo một lý do cho người chơi dễ hiểu.
static func validate_move(state: GameState, move: Dictionary) -> Dictionary:
	# --- Game đã kết thúc ---
	# Chặn theo GAME_FINISHED chứ không phải "khác PLACING", để khi Công thêm
	# phase IMPOSSIBLE_REVIEW thì đối thủ vẫn đặt được tile trong giai đoạn đó.
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

	if tiles.size() > PlacementHelper.MAX_TILES_PER_MOVE:
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

	# --- Các tile mới phải liền cụm ---
	var positions: Array[Vector2i] = _collect_positions(tiles)

	if not PlacementHelper.is_cluster_contiguous(positions):
		return _fail(
			TILES_NOT_ADJACENT,
			"Các tile đặt trong cùng một lượt phải kề cạnh nhau.",
			positions
		)

	# --- Ít nhất một tile chạm board ---
	if not PlacementHelper.cluster_touches_board(state.board, positions):
		return _fail(
			NOT_TOUCHING_BOARD,
			"Ít nhất một tile mới phải kề cạnh tile đã có trên bàn.",
			positions
		)

	# TODO Giai đoạn 3: luật thẳng hàng (sau khi chốt với Công).
	# TODO Giai đoạn 3: điều kiện kết nối đường ray.

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
