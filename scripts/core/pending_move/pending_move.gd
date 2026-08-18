class_name PendingMove
extends RefCounted

# ============================================================================
# Monorail — Pending Move
# Phụ trách: Khiêm
# Giai đoạn 2 — tile interaction
#
# Giữ 1–3 tile mà người chơi đang thử đặt, TRƯỚC khi bấm Confirm.
#
# Nguyên tắc (Roadmap mục 5 và Final_DataFormat mục 4):
#   - Pending move KHÔNG nằm trong GameState.board.
#   - Chỉ apply_move() mới được ghi tile vào board thật.
#   - Nước đi sai KHÔNG xóa pending move — người chơi giữ nguyên để sửa.
#
# Cách dùng phía Công:
#   var pending := PendingMove.new(state.current_player)
#   pending.changed.connect(_on_pending_changed)   # để render lại board
#   pending.add_tile(pos, MonoTile.TileType.STRAIGHT, 0)
#   var result := MoveValidator.validate_move(state, pending.to_move())
#
# Object này KHÔNG tự validate luật đường ray hay luật thẳng hàng.
# Nó chỉ giữ đúng bất biến "tối đa 3 tile, không trùng ô".
# validate_move() mới là nơi phán quyết cuối cùng.
# ============================================================================

## Phát ra mỗi khi danh sách tile thay đổi (thêm, xóa, xoay, lật, di chuyển, clear).
## Công nối signal này để render lại lớp pending trên board.
signal changed

const MAX_TILES: int = 3

var player_id: int = -1
var tiles: Array[Dictionary] = []


func _init(owner_player_id: int = -1) -> void:
	player_id = owner_player_id


# ----------------------------------------------------------------------------
# 1. Truy vấn
# ----------------------------------------------------------------------------

func size() -> int:
	return tiles.size()


func is_empty() -> bool:
	return tiles.is_empty()


func is_full() -> bool:
	return tiles.size() >= MAX_TILES


## Còn chỗ để thêm tile không. Không xét luật kề cạnh — cái đó dùng PlacementHelper.
func can_add() -> bool:
	return not is_full()


func has_tile_at(position: Vector2i) -> bool:
	return _index_of(position) != -1


## Bản sao của tile ở một ô, hoặc Dictionary rỗng nếu không có.
## Trả về bản sao để bên ngoài không sửa trực tiếp được state bên trong.
func get_tile_at(position: Vector2i) -> Dictionary:
	var i: int = _index_of(position)
	if i == -1:
		return {}
	return tiles[i].duplicate()


## Bản sao danh sách tile — dùng cho PlacementHelper và để render.
func get_tiles() -> Array:
	var result: Array = []
	for tile in tiles:
		result.append(tile.duplicate())
	return result


# ----------------------------------------------------------------------------
# 2. Thêm và xóa
# ----------------------------------------------------------------------------

## Thêm một pending tile.
## Trả về false nếu đã đủ 3 tile hoặc ô đó đã có pending tile.
## KHÔNG kiểm tra ô có bị board chiếm không — gọi PlacementHelper.can_place_at()
## trước khi gọi hàm này.
func add_tile(position: Vector2i, type: int, rotation: int = 0) -> bool:
	if is_full():
		return false
	if has_tile_at(position):
		return false

	tiles.append({
		"position": position,
		"type": type,
		"rotation": MonoTile.normalize_rotation(rotation),
	})
	changed.emit()
	return true


## Xóa pending tile ở một ô. Trả về false nếu ô đó không có tile.
func remove_at(position: Vector2i) -> bool:
	var i: int = _index_of(position)
	if i == -1:
		return false
	tiles.remove_at(i)
	changed.emit()
	return true


## Xóa toàn bộ pending move (nút Clear / Cancel).
func clear() -> void:
	if tiles.is_empty():
		return
	tiles.clear()
	changed.emit()


# ----------------------------------------------------------------------------
# 3. Biến đổi tile đang chờ
# ----------------------------------------------------------------------------

## Xoay pending tile ở một ô 90° theo chiều kim đồng hồ.
func rotate_at(position: Vector2i) -> bool:
	var i: int = _index_of(position)
	if i == -1:
		return false
	tiles[i]["rotation"] = MonoTile.normalize_rotation(tiles[i]["rotation"] + 1)
	changed.emit()
	return true


## Lật mặt pending tile: STRAIGHT <-> CORNER, giữ nguyên rotation.
func flip_at(position: Vector2i) -> bool:
	var i: int = _index_of(position)
	if i == -1:
		return false
	var current_type: int = tiles[i]["type"]
	tiles[i]["type"] = (
		MonoTile.TileType.CORNER
		if current_type == MonoTile.TileType.STRAIGHT
		else MonoTile.TileType.STRAIGHT
	)
	changed.emit()
	return true


## Di chuyển một pending tile sang ô khác, giữ nguyên type và rotation.
## Trả về false nếu ô nguồn trống hoặc ô đích đã có pending tile khác.
func move_tile(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return false
	var i: int = _index_of(from)
	if i == -1:
		return false
	if has_tile_at(to):
		return false
	tiles[i]["position"] = to
	changed.emit()
	return true


# ----------------------------------------------------------------------------
# 4. Xuất ra Move
# ----------------------------------------------------------------------------

## Chuyển thành Move đúng định dạng ở Final_DataFormat mục 2.
##
## Kết quả là dữ liệu thuần, tách rời khỏi object này — sửa Move
## sẽ không ảnh hưởng pending move và ngược lại.
func to_move() -> Dictionary:
	var move_tiles: Array = []
	for tile in tiles:
		move_tiles.append({
			"position": tile["position"],
			"type": tile["type"],
			"rotation": tile["rotation"],
		})
	return {
		"player_id": player_id,
		"tiles": move_tiles,
	}


## Dựng lại pending move từ một Move — tiện khi khôi phục hoặc test.
static func from_move(move: Dictionary) -> PendingMove:
	var pending := PendingMove.new(move.get("player_id", -1))
	for tile in move.get("tiles", []):
		pending.add_tile(tile["position"], tile["type"], tile.get("rotation", 0))
	return pending


## Đổi người chơi sở hữu pending move này (dùng khi bắt đầu lượt mới).
## Tự động xóa sạch tile cũ để không mang tile của lượt trước sang lượt sau.
func reset_for_player(new_player_id: int) -> void:
	player_id = new_player_id
	tiles.clear()
	changed.emit()


## Vị trí của tile trong mảng, -1 nếu không có.
func _index_of(position: Vector2i) -> int:
	for i in range(tiles.size()):
		if tiles[i]["position"] == position:
			return i
	return -1
