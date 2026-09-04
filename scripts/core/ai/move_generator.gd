class_name MoveGenerator
extends RefCounted

# ============================================================================
# Monorail — Move Generator
# Phụ trách: Khiêm
# Giai đoạn 6 — Get Valid Moves
#
# Sinh danh sách nước đi hợp lệ, LỌC BẰNG CHÍNH MoveValidator.
# Không có luật riêng cho AI (nguyên tắc 4 của Roadmap): nếu validator đổi thì
# danh sách này tự đổi theo, không bao giờ lệch nhau.
#
# Toàn bộ hàm là STATIC và CHỈ ĐỌC.
#
# ---------------------------------------------------------------------------
# VỀ HIỆU NĂNG — đọc trước khi tăng max_tiles
#
# Số nước đi tăng rất nhanh theo số tile trong một lượt. Đo trên board 10 tile:
#
#     max_tiles = 1  ->      90 nước đi
#     max_tiles = 2  ->   1.314 nước đi
#     max_tiles = 3  ->  24.858 nước đi
#
# Vì vậy mặc định là 1. AI vẫn đặt được 2–3 tile khi cần, nhưng bằng cách
# chọn từng tile một (AIPlayer) hoặc bằng get_closing_move() — cả hai đều rẻ,
# không phải sinh toàn bộ tổ hợp.
# ============================================================================


## Sinh mọi nước đi hợp lệ gồm 1 đến `max_tiles` tile.
##
## Rotation được khử trùng lặp: STRAIGHT chỉ sinh rotation 0 và 1, vì rotation
## 2 và 3 cho ra đúng tập cạnh đó.
##
## Đọc kỹ ghi chú hiệu năng ở đầu file trước khi truyền max_tiles > 1.
static func get_valid_moves(state: GameState, max_tiles: int = 1) -> Array:
	var limit: int = mini(mini(max_tiles, PlacementHelper.MAX_TILES_PER_MOVE), state.remaining_tiles)
	var result: Array = []
	if limit < 1:
		return result

	var seen: Dictionary = {}
	_extend(state, [], limit, result, seen)
	return result


## Tìm nước đi khép được vòng NGAY trong lượt này, hoặc Dictionary rỗng.
##
## Không duyệt toàn bộ nước đi. Nó đi thẳng từ một đầu đoạn ray chứa ga, mỗi
## bước chỉ có 3 lựa chọn (tile được xác định bởi cạnh vào và cạnh ra), nên
## tối đa 3 + 9 + 27 = 39 đường cần thử. Rẻ hơn sinh 24.858 nước đi rất nhiều.
static func get_closing_move(state: GameState, max_tiles: int = 3) -> Dictionary:
	var trace: Dictionary = WinChecker.trace_station_track(state.board)
	if trace["status"] != WinChecker.TRACK_OPEN:
		return {}

	var limit: int = mini(mini(max_tiles, PlacementHelper.MAX_TILES_PER_MOVE), state.remaining_tiles)
	if limit < 1:
		return {}

	var ends: Array = trace["ends"]
	var from_position: Vector2i = ends[0]["position"]
	var from_edge: String = ends[0]["edge"]
	var target_position: Vector2i = ends[1]["position"]
	var target_edge: String = ends[1]["edge"]

	var found: Array = []
	var first_cell: Vector2i = from_position + MonoTile.EDGE_OFFSETS[from_edge]
	if state.board.has(first_cell):
		return {}

	_walk_to_target(
		state.board, first_cell, MonoTile.OPPOSITE_EDGE[from_edge],
		target_position, target_edge, [], limit, found
	)

	# Ưu tiên đường ngắn nhất — tốn ít tile nhất.
	found.sort_custom(func(a: Array, b: Array) -> bool: return a.size() < b.size())

	for tiles in found:
		var move: Dictionary = {"player_id": state.current_player, "tiles": tiles}
		if not MoveValidator.validate_move(state, move)["is_valid"]:
			continue
		if _completes_loop(state.board, tiles):
			return move

	return {}


# ----------------------------------------------------------------------------
# Nội bộ
# ----------------------------------------------------------------------------

## Thêm dần từng tile vào cụm đang dựng, ghi lại mọi nước đi hợp lệ gặp trên đường.
static func _extend(
	state: GameState, pending: Array, limit: int, result: Array, seen: Dictionary
):
	for position in PlacementHelper.get_placeable_positions(state.board, pending):
		for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
			for rotation in range(MonoTile.get_distinct_rotation_count(type)):
				var tiles: Array = pending.duplicate()
				tiles.append({"position": position, "type": type, "rotation": rotation})

				var key: String = _move_key(tiles)
				if not seen.has(key):
					seen[key] = true
					var move: Dictionary = {"player_id": state.current_player, "tiles": tiles}
					if MoveValidator.validate_move(state, move)["is_valid"]:
						result.append(move)

				if tiles.size() < limit:
					_extend(state, tiles, limit, result, seen)


## Khóa nhận dạng một nước đi, không phụ thuộc thứ tự tile trong mảng.
static func _move_key(tiles: Array) -> String:
	var parts: Array = []
	for tile in tiles:
		parts.append("%d,%d,%d,%d" % [
			tile["position"].x, tile["position"].y, tile["type"], tile["rotation"]
		])
	parts.sort()
	return "|".join(parts)


## Dựng đoạn ray từ ô hiện tại tới đầu ray bên kia.
## Mỗi bước chọn cạnh ra; cạnh vào đã biết nên tile là duy nhất.
static func _walk_to_target(
	board: Dictionary, position: Vector2i, entry_edge: String,
	target_position: Vector2i, target_edge: String,
	used: Array, limit: int, found: Array
):
	if used.size() >= limit:
		return

	for exit_edge in MonoTile.EDGE_ORDER:
		if exit_edge == entry_edge:
			continue

		var tile: Dictionary = MonoTile.tile_with_edges(entry_edge, exit_edge)
		if tile.is_empty():
			continue

		var tiles: Array = used.duplicate()
		tiles.append({
			"position": position, "type": tile["type"], "rotation": tile["rotation"],
		})

		# Đặt đúng vào ô kề đầu ray kia, và mở đúng về phía nó -> khép vòng.
		if position == target_position + MonoTile.EDGE_OFFSETS[target_edge]:
			if exit_edge == MonoTile.OPPOSITE_EDGE[target_edge]:
				found.append(tiles)
				continue

		var next_position: Vector2i = position + MonoTile.EDGE_OFFSETS[exit_edge]
		if board.has(next_position):
			continue
		if _has_position(tiles, next_position):
			continue

		_walk_to_target(
			board, next_position, MonoTile.OPPOSITE_EDGE[exit_edge],
			target_position, target_edge, tiles, limit, found
		)


static func _has_position(tiles: Array, position: Vector2i) -> bool:
	for tile in tiles:
		if tile["position"] == position:
			return true
	return false


## Thử đặt các tile lên một bản sao của board rồi xem đã có vòng qua ga chưa.
static func _completes_loop(board: Dictionary, tiles: Array) -> bool:
	var preview: Dictionary = board.duplicate()
	for tile in tiles:
		preview[tile["position"]] = MonoTile.make_tile(tile["type"], tile["rotation"])
	var loop: Array[Vector2i] = WinChecker.find_station_loop(preview)
	return not loop.is_empty() and loop.size() == preview.size()
