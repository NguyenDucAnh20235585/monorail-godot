class_name PlacementHelper
extends RefCounted

# ============================================================================
# Monorail — Placement Helper
# Phụ trách: Khiêm
# Giai đoạn 2 — hỗ trợ tile interaction và ghost preview
#
# Toàn bộ hàm là STATIC và CHỈ ĐỌC:
#   - không sửa board,
#   - không sửa pending move,
#   - không giảm remaining_tiles,
#   - không đụng Node hay UI.
#
# Mục đích: Công gọi các hàm này để biết một ô có đặt được không và
# ghost preview nên hiện màu gì, mà không phải tự viết lại luật.
#
# LƯU Ý: đây KHÔNG phải validator chính thức.
# Preview trả lời cho từng ô một; validate_move() mới là nơi phán quyết
# cả nước đi khi người chơi bấm Confirm.
# ============================================================================


## Trạng thái của một ô khi người chơi rê chuột qua.
enum PreviewState {
	VALID,             # đặt được — ghost xanh
	OCCUPIED,          # đã có tile committed — ghost đỏ
	PENDING_OCCUPIED,  # đã có pending tile ở đây — ghost đỏ
	NOT_ADJACENT,      # không chạm board / không chạm cụm pending — ghost đỏ
	LIMIT_REACHED,     # đã đủ 3 tile pending — ghost đỏ
}

## Số tile tối đa trong một lượt (Rules mục 5).
const MAX_TILES_PER_MOVE: int = 3


# ----------------------------------------------------------------------------
# 1. Kiểm tra ô đơn lẻ
# ----------------------------------------------------------------------------

## Ô đã có tile được Confirm chưa (bao gồm cả 2 tile ga).
static func is_occupied(board: Dictionary, position: Vector2i) -> bool:
	return board.has(position)


## Ô đang có một pending tile chưa.
## `pending_tiles` là Array các Dictionary có khóa "position".
static func is_pending_at(pending_tiles: Array, position: Vector2i) -> bool:
	for tile in pending_tiles:
		if tile["position"] == position:
			return true
	return false


## Ô hoàn toàn trống: không có tile committed và cũng không có pending tile.
static func is_free(board: Dictionary, pending_tiles: Array, position: Vector2i) -> bool:
	return not is_occupied(board, position) and not is_pending_at(pending_tiles, position)


# ----------------------------------------------------------------------------
# 2. Kề board / kề cụm pending
# ----------------------------------------------------------------------------

## Ô có kề cạnh với ít nhất một tile đã có trên board không (Rules mục 6).
## Không tính kề chéo.
static func is_adjacent_to_board(board: Dictionary, position: Vector2i) -> bool:
	for neighbor in MonoTile.get_neighbor_positions(position):
		if board.has(neighbor):
			return true
	return false


## Ô có kề cạnh với ít nhất một pending tile không (Rules mục 8).
static func is_adjacent_to_pending(pending_tiles: Array, position: Vector2i) -> bool:
	for neighbor in MonoTile.get_neighbor_positions(position):
		if is_pending_at(pending_tiles, neighbor):
			return true
	return false


## Ô có được phép nhận thêm một pending tile không, xét riêng luật kề cạnh.
##
## Quy tắc:
##   - Chưa có pending tile nào  -> ô phải kề board.
##   - Đã có pending tile        -> ô phải kề CỤM PENDING.
##
## Vế thứ hai là vì Rules mục 8: các tile mới trong cùng một lượt phải kề nhau.
## Nếu chỉ kề board mà rời khỏi cụm pending thì cả nước đi sẽ hỏng ở
## validate_move(), nên chặn ngay từ preview cho người chơi dễ hiểu.
static func is_adjacency_ok(
	board: Dictionary,
	pending_tiles: Array,
	position: Vector2i,
	allow_board_when_pending: bool = false
) -> bool:
	if pending_tiles.is_empty():
		return is_adjacent_to_board(board, position)

	if allow_board_when_pending:
		return (
			is_adjacent_to_board(board, position)
			or is_adjacent_to_pending(pending_tiles, position)
		)

	return is_adjacent_to_pending(pending_tiles, position)

# ----------------------------------------------------------------------------
# 3. Ghost preview
# ----------------------------------------------------------------------------

## Trạng thái ghost cho một ô. Công dùng kết quả này để tô màu và hiện thông báo.
static func get_preview_state(
	board: Dictionary, pending_tiles: Array, position: Vector2i
) -> PreviewState:
	if is_occupied(board, position):
		return PreviewState.OCCUPIED
	if is_pending_at(pending_tiles, position):
		return PreviewState.PENDING_OCCUPIED
	if pending_tiles.size() >= MAX_TILES_PER_MOVE:
		return PreviewState.LIMIT_REACHED
	if not is_adjacency_ok(board, pending_tiles, position):
		return PreviewState.NOT_ADJACENT
	return PreviewState.VALID


## Rút gọn: ghost nên xanh hay đỏ.
static func can_place_at(
	board: Dictionary, pending_tiles: Array, position: Vector2i
) -> bool:
	return get_preview_state(board, pending_tiles, position) == PreviewState.VALID


## Thông báo tiếng Việt cho từng trạng thái, để Công hiện thẳng lên UI.
static func describe_preview_state(state: PreviewState) -> String:
	match state:
		PreviewState.VALID:
			return ""
		PreviewState.OCCUPIED:
			return "Ô này đã có tile."
		PreviewState.PENDING_OCCUPIED:
			return "Ô này đã có tile đang chờ xác nhận."
		PreviewState.NOT_ADJACENT:
			return "Tile phải đặt kề cạnh tile đã có trên bàn."
		PreviewState.LIMIT_REACHED:
			return "Mỗi lượt chỉ được đặt tối đa %d tile." % MAX_TILES_PER_MOVE
		_:
			return "Không đặt được ở đây."


## Danh sách mọi ô đặt được ngay lúc này.
## Dùng để tô sáng gợi ý cho người chơi, và sau này cho get_valid_moves().
static func get_placeable_positions(
	board: Dictionary,
	pending_tiles: Array,
	max_tiles: int = MAX_TILES_PER_MOVE,
	allow_board_when_pending: bool = false
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if pending_tiles.size() >= max_tiles:
		return result

	var candidates: Dictionary = {}

	for position in board.keys():
		for neighbor in MonoTile.get_neighbor_positions(position):
			candidates[neighbor] = true

	for tile in pending_tiles:
		for neighbor in MonoTile.get_neighbor_positions(tile["position"]):
			candidates[neighbor] = true

	for position in candidates.keys():
		if not is_free(board, pending_tiles, position):
			continue

		if not is_adjacency_ok(
			board,
			pending_tiles,
			position,
			allow_board_when_pending
		):
			continue

		result.append(position)

	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	return result
	
	if pending_tiles.size() >= MAX_TILES_PER_MOVE:
		return result

# ----------------------------------------------------------------------------
# 4. Cụm tile
# ----------------------------------------------------------------------------

## Các vị trí có tạo thành một cụm liền nhau không (Rules mục 8).
## Duyệt theo 4 hướng, không tính kề chéo.
## Mảng rỗng hoặc chỉ 1 ô luôn được coi là liền cụm.
static func is_cluster_contiguous(positions: Array) -> bool:
	if positions.size() <= 1:
		return true

	var remaining: Dictionary = {}
	for position in positions:
		remaining[position] = true

	# Nếu có vị trí trùng nhau thì cụm không hợp lệ — để validate_move() báo lỗi riêng.
	if remaining.size() != positions.size():
		return false

	var queue: Array[Vector2i] = []
	queue.append(positions[0])
	remaining.erase(positions[0])

	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for neighbor in MonoTile.get_neighbor_positions(current):
			if remaining.has(neighbor):
				remaining.erase(neighbor)
				queue.append(neighbor)

	return remaining.is_empty()


## Các vị trí có nằm trên cùng một hàng hoặc cùng một cột không.
##
## CHƯA ĐƯỢC ÁP DỤNG trong validator. Rules.pdf mục 7 chỉ yêu cầu các tile mới
## kề nhau, còn Roadmap tuần 3 lại thêm "phải thẳng hàng". Hai tài liệu đang lệch
## nhau — xem docs/tile_interaction.md mục "Cần chốt". Hàm để sẵn ở đây để khi
## chốt xong chỉ cần bật lên.
static func is_cluster_aligned(positions: Array) -> bool:
	if positions.size() <= 1:
		return true

	var same_row: bool = true
	var same_column: bool = true
	var first: Vector2i = positions[0]

	for position in positions:
		if position.y != first.y:
			same_row = false
		if position.x != first.x:
			same_column = false

	return same_row or same_column


## Cụm có chạm board không — chỉ cần MỘT tile chạm là đủ (Rules mục 6).
static func cluster_touches_board(board: Dictionary, positions: Array) -> bool:
	for position in positions:
		if is_adjacent_to_board(board, position):
			return true
	return false


# ----------------------------------------------------------------------------
# 5. Nối đường ray (phục vụ feedback, chưa phải luật)
# ----------------------------------------------------------------------------

## Các hướng mà tile ở `position` nối được với tile kề bên trên board.
##
## Theo Rules mục 7, tile mới KHÔNG bắt buộc phải nối ray ngay khi đặt.
## Hàm này chỉ để UI hiện gợi ý, ví dụ tô sáng cạnh nối được.
static func get_connected_edges(
	board: Dictionary, position: Vector2i, tile: Dictionary
) -> Array[String]:
	var result: Array[String] = []
	for edge_name in MonoTile.EDGE_ORDER:
		var neighbor: Vector2i = position + MonoTile.EDGE_OFFSETS[edge_name]
		if not board.has(neighbor):
			continue
		if MonoTile.edges_connect(tile, position, board[neighbor], neighbor):
			result.append(edge_name)
	return result


## Số cạnh nối được — tiện cho AI heuristic ở Giai đoạn 6.
static func count_connections(
	board: Dictionary, position: Vector2i, tile: Dictionary
) -> int:
	return get_connected_edges(board, position, tile).size()
