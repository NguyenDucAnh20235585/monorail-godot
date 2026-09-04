class_name WinChecker
extends RefCounted

# ============================================================================
# Monorail — Win Checker
# Phụ trách: Khiêm
# Week 3 — Win Logic
#
# Hai cách ván kết thúc (đã chốt):
#
#   1. LOOP_COMPLETED — có một đường ray KHÉP KÍN xuất phát từ nhà ga và quay
#      trở lại chính nhà ga. Người đặt tile hoàn thành vòng đó THẮNG ngay.
#
#   2. OUT_OF_TILES — hết tile mà chưa có vòng nào và không ai tuyên bố
#      Impossible. Người đặt tile cuối cùng THUA, đối thủ thắng.
#
# Tile lẻ hoặc nhánh cụt nằm NGOÀI vòng không làm mất chiến thắng.
# (Rules.pdf mục 8 có thể đọc chặt hơn — xem docs/win_and_impossible.md mục 6.)
#
# Toàn bộ hàm là STATIC và CHỈ ĐỌC:
#   không sửa board, không ghi winner, không đổi phase, không đụng UI.
#   Việc ghi kết quả vào GameState là của Công.
# ============================================================================

# ----------------------------------------------------------------------------
# Lý do ván kết thúc
# ----------------------------------------------------------------------------

## Ván chưa kết thúc.
const REASON_NONE: String = "NONE"

## Hoàn thành vòng ray qua ga — người vừa đặt tile thắng.
const REASON_LOOP_COMPLETED: String = "LOOP_COMPLETED"

## Hết tile mà chưa có vòng — người vừa đặt tile thua.
const REASON_OUT_OF_TILES: String = "OUT_OF_TILES"

# ----------------------------------------------------------------------------
# Trạng thái đoạn ray tính từ nhà ga
# ----------------------------------------------------------------------------

const TRACK_NO_STATION: String = "NO_STATION"   ## board chưa có đủ tile ga
const TRACK_BLOCKED: String = "BLOCKED"         ## ray đâm vào tile không nối được
const TRACK_CLOSED: String = "CLOSED"           ## đã khép thành vòng
const TRACK_OPEN: String = "OPEN"               ## còn hai đầu hở, nối tiếp được

# ----------------------------------------------------------------------------
# 1. Hàm chính
# ----------------------------------------------------------------------------

## Kiểm tra sau khi một nước đi đã được apply.
##
## Trả về:
##   {
##       "is_win": bool,                       # ván đã kết thúc và có người thắng
##       "winner": int,                        # -1 nếu chưa kết thúc
##       "reason": String,                     # REASON_* ở trên
##       "loop_positions": Array[Vector2i]      # rỗng nếu chưa có vòng
##   }
##
## Lưu ý: `is_win` nghĩa là "ván đã có người thắng", KHÔNG phải "người vừa đi
## đã thắng". Ở trường hợp OUT_OF_TILES thì người thắng là ĐỐI THỦ của người
## vừa đặt tile. Luôn đọc `winner`, đừng suy ra từ lượt hiện tại.
##
## `last_move` dùng để xác định ai vừa đặt tile. Nếu không truyền,
## hàm lấy `state.current_player` — đúng khi Công gọi check_win()
## SAU apply_move() nhưng TRƯỚC end_turn(), theo Turn_Flow.
static func check_win(state: GameState, last_move: Dictionary = {}) -> Dictionary:
	var mover: int = _get_mover(state, last_move)
	var loop: Array[Vector2i] = find_station_loop(state.board)

	if not loop.is_empty() and loop.size() == state.board.size():
		return {
			"is_win": true,
			"winner": mover,
			"reason": REASON_LOOP_COMPLETED,
			"loop_positions": loop,
		}

	# Hết tile mà chưa khép được vòng: người đặt tile cuối cùng thua.
	if state.remaining_tiles <= 0:
		return {
			"is_win": true,
			"winner": 1 - mover,
			"reason": REASON_OUT_OF_TILES,
			"loop_positions": _empty_path(),
		}

	return _no_win()


## Vị trí hai tile ga. Đọc từ hằng số của Công để chỉ có một nguồn sự thật.
static func get_station_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.append(RulesEngine.LEFT_START_POS)
	result.append(RulesEngine.RIGHT_START_POS)
	return result


# ----------------------------------------------------------------------------
# 2. Duyệt đường ray
# ----------------------------------------------------------------------------

## Tìm vòng khép kín có chứa nhà ga.
## Trả về danh sách ô theo đúng thứ tự đi vòng, hoặc mảng rỗng nếu chưa có.
static func find_station_loop(board: Dictionary) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	var stations: Array[Vector2i] = get_station_positions()

	for station in stations:
		if not board.has(station):
			return empty

	var loop: Array[Vector2i] = find_loop(board, stations[0])
	if loop.is_empty():
		return empty

	# Vòng phải chứa cả hai tile ga.
	for station in stations:
		if not loop.has(station):
			return empty

	return loop


## Đi theo đường ray bắt đầu từ `start`, xem có quay về đúng chỗ cũ không.
##
## Mỗi tile luôn có đúng 2 cạnh mở, nên từ một tile đi vào bằng một cạnh thì
## chỉ có duy nhất một cạnh để đi ra. Đường đi là xác định, không cần quay lui.
##
## Trả về mảng rỗng khi:
##   - đi vào ô trống (nhánh cụt);
##   - tile kề không mở về phía mình (ray bị đứt);
##   - quay về ga nhưng bằng sai cạnh.
static func find_loop(board: Dictionary, start: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	if not board.has(start):
		return path

	var start_edges: Array[String] = MonoTile.get_open_edges(
		board[start]["type"], board[start]["rotation"]
	)
	if start_edges.size() != 2:
		return path

	path.append(start)

	var current: Vector2i = start
	var exit_edge: String = start_edges[0]

	while true:
		var next_position: Vector2i = current + MonoTile.EDGE_OFFSETS[exit_edge]

		# Ray chạy vào ô trống -> nhánh cụt.
		if not board.has(next_position):
			return _empty_path()

		var entry_edge: String = MonoTile.OPPOSITE_EDGE[exit_edge]
		var next_edges: Array[String] = MonoTile.get_open_edges(
			board[next_position]["type"], board[next_position]["rotation"]
		)

		# Tile kề không mở về phía mình -> ray bị đứt.
		if not next_edges.has(entry_edge):
			return _empty_path()

		if next_position == start:
			# Về được tới ga, nhưng phải vào bằng ĐÚNG cạnh còn lại thì mới khép kín.
			if entry_edge == start_edges[1]:
				return path
			return _empty_path()

		# Với tile 2 cạnh thì không thể gặp lại ô giữa đường, nhưng chặn cho chắc.
		if path.has(next_position):
			return _empty_path()

		path.append(next_position)

		# Đi vào bằng entry_edge thì đi ra bằng cạnh còn lại.
		exit_edge = next_edges[1] if next_edges[0] == entry_edge else next_edges[0]
		current = next_position

	return path


# ----------------------------------------------------------------------------
# 3. Trạng thái đoạn ray chứa ga
# ----------------------------------------------------------------------------

## Đi từ nhà ga theo cả hai hướng cho tới khi gặp ô trống.
##
## Trả về:
##   {
##       "status": String,     # TRACK_* ở trên
##       "ends": Array         # [{ "position": Vector2i, "edge": String }, ...]
##   }
##
## `ends` chỉ có dữ liệu khi status là OPEN — đó là hai đầu hở của đoạn ray,
## mỗi đầu gồm ô cuối cùng và cạnh đang mở ra chỗ trống.
##
## `BLOCKED` nghĩa là một cạnh của đoạn ray đâm vào tile đã commit mà tile đó
## không mở về phía mình. Tile đã commit không sửa được, nên từ lúc này KHÔNG
## ai còn có thể khép vòng qua ga nữa. AI dùng tín hiệu này để tuyên bố
## Impossible mà chắc chắn đúng.
static func trace_station_track(board: Dictionary) -> Dictionary:
	var stations: Array[Vector2i] = get_station_positions()
	for station in stations:
		if not board.has(station):
			return {"status": TRACK_NO_STATION, "ends": []}

	var start: Vector2i = stations[0]
	var start_edges: Array[String] = MonoTile.get_open_edges(
		board[start]["type"], board[start]["rotation"]
	)

	var ends: Array = []

	for start_edge in start_edges:
		var current: Vector2i = start
		var exit_edge: String = start_edge
		var guard: int = 0

		while true:
			guard += 1
			if guard > board.size() + 2:
				# Không thể xảy ra với tile 2 cạnh, chặn cho chắc.
				return {"status": TRACK_BLOCKED, "ends": []}

			var next_position: Vector2i = current + MonoTile.EDGE_OFFSETS[exit_edge]

			if not board.has(next_position):
				ends.append({"position": current, "edge": exit_edge})
				break

			var entry_edge: String = MonoTile.OPPOSITE_EDGE[exit_edge]
			var next_edges: Array[String] = MonoTile.get_open_edges(
				board[next_position]["type"], board[next_position]["rotation"]
			)

			if not next_edges.has(entry_edge):
				return {"status": TRACK_BLOCKED, "ends": []}

			if next_position == start:
				return {"status": TRACK_CLOSED, "ends": []}

			exit_edge = next_edges[1] if next_edges[0] == entry_edge else next_edges[0]
			current = next_position

	if ends.size() != 2:
		return {"status": TRACK_BLOCKED, "ends": []}

	return {"status": TRACK_OPEN, "ends": ends}


## Số tile ÍT NHẤT còn phải đặt để khép được vòng, hoặc -1 nếu không tính được
## (ray đã khép, đã bị chặn, hoặc chưa có ga).
##
## Đây là CẬN DƯỚI, không phải con số chính xác: nó chỉ tính khoảng cách
## Manhattan giữa hai ô trống ở hai đầu ray. Đường thật luôn dài hơn hoặc bằng.
## Nhờ vậy, nếu cận dưới đã lớn hơn số tile còn lại thì chắc chắn không ai
## khép nổi vòng — dùng làm căn cứ tuyên bố Impossible.
static func min_tiles_to_close(board: Dictionary) -> int:
	var trace: Dictionary = trace_station_track(board)
	if trace["status"] != TRACK_OPEN:
		return -1

	var ends: Array = trace["ends"]
	var first: Vector2i = ends[0]["position"] + MonoTile.EDGE_OFFSETS[ends[0]["edge"]]
	var second: Vector2i = ends[1]["position"] + MonoTile.EDGE_OFFSETS[ends[1]["edge"]]

	if first == second:
		return 1

	return absi(first.x - second.x) + absi(first.y - second.y) + 1


# ----------------------------------------------------------------------------
# 4. Nội bộ
# ----------------------------------------------------------------------------

static func _empty_path() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	return empty


static func _no_win() -> Dictionary:
	return {
		"is_win": false,
		"winner": -1,
		"reason": REASON_NONE,
		"loop_positions": _empty_path(),
	}


## Ai là người vừa đặt tile.
static func _get_mover(state: GameState, last_move: Dictionary) -> int:
	if last_move.has("player_id"):
		return int(last_move["player_id"])
	return state.current_player
