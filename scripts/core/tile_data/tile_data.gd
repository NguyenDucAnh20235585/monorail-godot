class_name MonoTile
extends RefCounted

# ============================================================================
# Monorail — TileData
# Phụ trách: Khiêm
# Giai đoạn 1 — Tile Foundation
#
# LƯU Ý TÊN CLASS:
#   Godot 4 đã có sẵn một class built-in tên `TileData` (thuộc hệ TileMap).
#   Nếu khai báo `class_name TileData` thì engine báo lỗi parser ngay.
#   Vì vậy class ở đây tên là `MonoTile`, gọi là: MonoTile.get_edges(...).
#   Khái niệm "TileData" trong tài liệu vẫn giữ nguyên — nó chỉ định dạng
#   Dictionary { "type", "rotation" }, không phải tên class.
#
# Toàn bộ hàm trong file này là STATIC và PURE:
#   - không giữ state,
#   - không sửa dữ liệu đầu vào,
#   - không đụng tới GameState, board, UI hay Node.
#
# Quy ước dữ liệu (theo Final_DataFormat):
#   tile = { "type": TileType, "rotation": int }
#   edges KHÔNG được lưu trong tile, luôn tính bằng get_edges(type, rotation).
# ============================================================================


# ----------------------------------------------------------------------------
# 1. Kiểu tile
# ----------------------------------------------------------------------------

enum TileType {
	STRAIGHT,  # mặt thẳng
	CORNER,    # mặt góc 'ㄱ'
}

## Số rotation hợp lệ: 0, 1, 2, 3 (tương ứng 0°, 90°, 180°, 270° theo chiều kim đồng hồ).
const ROTATION_COUNT: int = 4

## Thứ tự cạnh chuẩn, xoay theo chiều kim đồng hồ.
## Index này được dùng cho toàn bộ phép xoay bên dưới — không đổi thứ tự.
const EDGE_ORDER: Array = ["top", "right", "bottom", "left"]

## Vector lệch tương ứng với mỗi cạnh.
## Grid dùng quy ước Godot: y tăng khi đi xuống dưới.
const EDGE_OFFSETS: Dictionary = {
	"top": Vector2i(0, -1),
	"right": Vector2i(1, 0),
	"bottom": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
}

## Cạnh đối diện — dùng khi kiểm tra hai tile kề nhau có nối đường ray không.
const OPPOSITE_EDGE: Dictionary = {
	"top": "bottom",
	"right": "left",
	"bottom": "top",
	"left": "right",
}

## Cạnh mở của tile ở rotation 0.
##   STRAIGHT rotation 0 = đường ray dọc  (top + bottom)
##   CORNER   rotation 0 = đường ray gấp lên-phải (top + right)
## Mọi rotation khác được suy ra từ đây, không hardcode thêm bảng nào.
const BASE_EDGES: Dictionary = {
	TileType.STRAIGHT: ["top", "bottom"],
	TileType.CORNER: ["top", "right"],
}


# ----------------------------------------------------------------------------
# 2. Khởi tạo và chuẩn hóa
# ----------------------------------------------------------------------------

## Tạo một tile mới. Đây là cách duy nhất nên dùng để sinh tile.
static func make_tile(type: int, rotation: int = 0) -> Dictionary:
	return {
		"type": type,
		"rotation": normalize_rotation(rotation),
	}


## Đưa rotation về khoảng 0..3. Chấp nhận cả số âm và số lớn hơn 3.
static func normalize_rotation(rotation: int) -> int:
	return ((rotation % ROTATION_COUNT) + ROTATION_COUNT) % ROTATION_COUNT


## Kiểm tra một Dictionary có đúng định dạng tile không.
## Dùng để bắt lỗi sớm ở ranh giới giữa UI và rules engine.
static func is_valid_tile(tile: Dictionary) -> bool:
	if not tile.has("type") or not tile.has("rotation"):
		return false
	if typeof(tile["type"]) != TYPE_INT or typeof(tile["rotation"]) != TYPE_INT:
		return false
	if tile["type"] != TileType.STRAIGHT and tile["type"] != TileType.CORNER:
		return false
	return tile["rotation"] >= 0 and tile["rotation"] < ROTATION_COUNT


# ----------------------------------------------------------------------------
# 3. Cạnh đường ray
# ----------------------------------------------------------------------------

## Trả về các cạnh mở của tile.
##
## Kết quả luôn có đủ 4 khóa:
##   { "top": bool, "right": bool, "bottom": bool, "left": bool }
##
## Rotation quay theo chiều kim đồng hồ, nên một cạnh ở index i của tile gốc
## sẽ nằm ở index (i + rotation) % 4 sau khi xoay.
static func get_edges(type: int, rotation: int) -> Dictionary:
	var r: int = normalize_rotation(rotation)
	var edges: Dictionary = {
		"top": false,
		"right": false,
		"bottom": false,
		"left": false,
	}

	var base: Array = BASE_EDGES.get(type, [])
	for edge_name in base:
		var base_index: int = EDGE_ORDER.find(edge_name)
		var rotated_index: int = (base_index + r) % ROTATION_COUNT
		edges[EDGE_ORDER[rotated_index]] = true

	return edges


## Phiên bản tiện dụng: nhận thẳng một tile Dictionary.
static func get_tile_edges(tile: Dictionary) -> Dictionary:
	return get_edges(tile["type"], tile["rotation"])


## Danh sách tên cạnh đang mở, ví dụ ["top", "bottom"].
## Hữu ích cho debug, ghost preview và win checker.
static func get_open_edges(type: int, rotation: int) -> Array[String]:
	var result: Array[String] = []
	var edges: Dictionary = get_edges(type, rotation)
	for edge_name in EDGE_ORDER:
		if edges[edge_name]:
			result.append(edge_name)
	return result


## Tile có mở về hướng `edge` không.
static func has_edge(tile: Dictionary, edge: String) -> bool:
	return get_tile_edges(tile).get(edge, false)


# ----------------------------------------------------------------------------
# 4. Biến đổi tile
# ----------------------------------------------------------------------------

## Xoay tile 90° theo chiều kim đồng hồ.
## Trả về tile MỚI, không sửa tile đầu vào.
static func rotate_tile(tile: Dictionary) -> Dictionary:
	return make_tile(tile["type"], tile["rotation"] + 1)


## Xoay ngược chiều kim đồng hồ — dùng cho phím tắt Shift+R nếu cần.
static func rotate_tile_ccw(tile: Dictionary) -> Dictionary:
	return make_tile(tile["type"], tile["rotation"] - 1)


## Lật tile: đổi mặt STRAIGHT <-> CORNER, giữ nguyên rotation.
## Trả về tile MỚI.
static func flip_tile(tile: Dictionary) -> Dictionary:
	var flipped_type: int = (
		TileType.CORNER if tile["type"] == TileType.STRAIGHT else TileType.STRAIGHT
	)
	return make_tile(flipped_type, tile["rotation"])


# ----------------------------------------------------------------------------
# 5. Kề cạnh và kết nối đường ray
# ----------------------------------------------------------------------------

## Bốn ô kề cạnh (trên, phải, dưới, trái). Không tính kề chéo.
static func get_neighbor_positions(position: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge_name in EDGE_ORDER:
		result.append(position + EDGE_OFFSETS[edge_name])
	return result


## Nếu hai ô kề cạnh nhau, trả về tên cạnh của `from` hướng về `to`.
## Nếu không kề cạnh, trả về chuỗi rỗng.
static func get_edge_between(from: Vector2i, to: Vector2i) -> String:
	var delta: Vector2i = to - from
	for edge_name in EDGE_ORDER:
		if EDGE_OFFSETS[edge_name] == delta:
			return edge_name
	return ""


## Hai ô có kề cạnh nhau không (không tính chéo).
static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return get_edge_between(a, b) != ""


## Hai tile kề nhau có nối đường ray không.
##
## Nối được khi CẢ HAI tile đều mở về phía nhau.
## Nếu hai ô không kề cạnh, luôn trả về false.
##
## Lưu ý: theo Rules mục 6/7, tile mới KHÔNG bắt buộc phải nối ray ngay khi đặt.
## Hàm này phục vụ check_win() và feedback UI, không phải luật đặt tile.
static func edges_connect(
	tile_a: Dictionary, pos_a: Vector2i,
	tile_b: Dictionary, pos_b: Vector2i
) -> bool:
	var edge_a: String = get_edge_between(pos_a, pos_b)
	if edge_a == "":
		return false
	var edge_b: String = OPPOSITE_EDGE[edge_a]
	return has_edge(tile_a, edge_a) and has_edge(tile_b, edge_b)


# ----------------------------------------------------------------------------
# 6. Chuẩn hóa rotation trùng lặp
# ----------------------------------------------------------------------------

## STRAIGHT ở rotation 0 và 2 cho ra cùng một tập cạnh (1 và 3 cũng vậy).
## Hàm này gộp về rotation nhỏ nhất cho cùng hình dạng.
##
## Dùng cho get_valid_moves() / AI để không sinh ra hai move trùng nhau.
## KHÔNG bắt buộc UI hay validator phải chuẩn hóa — validate_move() chấp nhận
## cả 4 rotation của STRAIGHT.
static func get_canonical_rotation(type: int, rotation: int) -> int:
	var r: int = normalize_rotation(rotation)
	if type == TileType.STRAIGHT:
		return r % 2
	return r


## Số rotation thực sự khác nhau của một loại tile.
## STRAIGHT: 2 — CORNER: 4
static func get_distinct_rotation_count(type: int) -> int:
	return 2 if type == TileType.STRAIGHT else ROTATION_COUNT


# ----------------------------------------------------------------------------
# 7. Serialize
# ----------------------------------------------------------------------------

## Chuyển tile về dạng JSON-safe (chỉ int và String).
## Không serialize Node, texture hay scene — theo Giai đoạn 7.
static func to_dict(tile: Dictionary) -> Dictionary:
	return {
		"type": int(tile["type"]),
		"rotation": int(tile["rotation"]),
	}


## Khôi phục tile từ dữ liệu đã serialize.
static func from_dict(data: Dictionary) -> Dictionary:
	return make_tile(int(data["type"]), int(data["rotation"]))


## Chuỗi ngắn để debug và ghi game log.
static func to_string_debug(tile: Dictionary) -> String:
	var type_name: String = "STRAIGHT" if tile["type"] == TileType.STRAIGHT else "CORNER"
	return "%s@%d [%s]" % [
		type_name,
		tile["rotation"],
		", ".join(get_open_edges(tile["type"], tile["rotation"])),
	]
