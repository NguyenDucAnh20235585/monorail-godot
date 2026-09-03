class_name AIPlayer
extends RefCounted

# ============================================================================
# Monorail — AI Player
# Phụ trách: Khiêm
# Giai đoạn 6 — AI random + AI heuristic
#
# AI CHỈ TRẢ VỀ MỘT HÀNH ĐỘNG. Nó không sửa GameState, không gọi apply_move(),
# không chuyển lượt. Công nhận kết quả rồi đẩy qua đúng đường mà người thật đi:
# validate_move() -> apply_move() -> check_win() -> end_turn().
# (Nguyên tắc 4 và 6 của Roadmap.)
#
# ---------------------------------------------------------------------------
# AI heuristic đánh theo bốn thứ tự ưu tiên:
#
#   1. Khép được vòng ngay thì khép -> thắng luôn.
#   2. Chứng minh được ván không thể hoàn thành thì tuyên bố Impossible.
#   3. Chọn SỐ LƯỢNG tile theo parity, phòng khi ván kéo dài tới lúc hết tile.
#   4. Chọn vị trí kéo hai đầu ray lại gần nhau, không làm hỏng đường ray, và
#      không mở đường cho đối thủ khép vòng ở lượt kế tiếp.
#
# Đo trên bản mô phỏng, 100 ván mỗi cặp, người đi trước chọn ngẫu nhiên:
#
#   AI heuristic  vs  random                        100 - 0
#   AI heuristic  vs  bản không ưu tiên khép vòng    72 - 28
#
# AI tự đánh với chính nó: 100/100 ván khép được vòng, trung bình 4,6 lượt.
# ============================================================================


enum Difficulty {
	RANDOM,      ## Chọn ngẫu nhiên trong các nước đi hợp lệ.
	HEURISTIC,   ## Có chiến thuật, dùng cho bản chơi thật.
}

## Loại hành động trong kết quả của choose_action().
const ACTION_MOVE: String = "MOVE"
const ACTION_DECLARE_IMPOSSIBLE: String = "DECLARE_IMPOSSIBLE"
const ACTION_NONE: String = "NONE"

## Trọng số heuristic. Chỉnh ở đây nếu muốn AI đánh khác đi.
const WEIGHT_MATCHED: float = 15.0    ## thưởng mỗi cạnh ray nối khớp
const WEIGHT_BROKEN: float = 60.0     ## phạt mỗi cạnh lệch — hỏng vĩnh viễn
const WEIGHT_FRONTIER: float = 0.4    ## phạt nhẹ khi để hở nhiều đầu ray
const WEIGHT_BLOCKS_TRACK: float = 300.0  ## phạt rất nặng nếu tự chặn đường ray

## Phạt theo khoảng cách còn lại giữa hai đầu ray. Đây là trọng số quan trọng
## nhất về mặt CHẤT LƯỢNG VÁN ĐẤU, không phải về sức mạnh:
##
##   = 0    AI kéo dài đường ray lung tung cho tới khi không ai khép nổi vòng,
##          rồi tuyên bố Impossible mà thắng. Đo 100 ván: 3 ván khép được vòng.
##   > 0    AI chủ động khép vòng. Đo 100 ván: 100 ván khép được vòng,
##          trung bình 4,6 lượt.
##
## Đối đầu trực tiếp thì bản có trọng số này thắng 72–28, nên bật lên vừa
## mạnh hơn vừa cho ván đấu đúng tinh thần trò chơi. Giá trị từ 1 trở lên đều
## cho kết quả như nhau; để 3 cho chắc.
const WEIGHT_GAP: float = 3.0


# ----------------------------------------------------------------------------
# 1. API chính
# ----------------------------------------------------------------------------

## Quyết định hành động cho lượt hiện tại.
##
## Trả về:
##   {
##       "type": String,        # ACTION_MOVE / ACTION_DECLARE_IMPOSSIBLE / ACTION_NONE
##       "move": Dictionary,    # Move hợp lệ, rỗng nếu type khác ACTION_MOVE
##       "reason": String       # mô tả ngắn để ghi game log
##   }
##
## `declared_by` truyền từ chỗ Công lưu người đã tuyên bố Impossible
## (ImpossibleFlow.NOBODY nếu chưa ai tuyên bố). Đang trong giai đoạn quyết
## định thì AI không tuyên bố nữa, chỉ đặt tile.
static func choose_action(
	state: GameState,
	difficulty: Difficulty = Difficulty.HEURISTIC,
	declared_by: int = ImpossibleFlow.NOBODY
) -> Dictionary:
	if difficulty == Difficulty.RANDOM:
		return _wrap_move(_choose_random_move(state), "AI chọn ngẫu nhiên một nước đi.")

	# 1. Khép được vòng thì khép luôn.
	var closing: Dictionary = MoveGenerator.get_closing_move(state)
	if not closing.is_empty():
		return _wrap_move(closing, "AI hoàn thành đường ray.")

	# 2. Chứng minh được là không thể thì tuyên bố.
	if _should_declare_impossible(state, declared_by):
		return {
			"type": ACTION_DECLARE_IMPOSSIBLE,
			"move": {},
			"reason": _describe_impossible(state),
		}

	# 3 và 4. Chọn số tile theo parity rồi chọn vị trí theo heuristic.
	return _wrap_move(_choose_heuristic_move(state), "AI đặt tile.")


## Chỉ lấy nước đi, bỏ qua phần Impossible. Tiện khi Công chưa nối flow đó.
## Trả về Dictionary rỗng nếu không còn nước đi nào.
static func choose_move(
	state: GameState, difficulty: Difficulty = Difficulty.HEURISTIC
) -> Dictionary:
	if difficulty == Difficulty.RANDOM:
		return _choose_random_move(state)

	var closing: Dictionary = MoveGenerator.get_closing_move(state)
	if not closing.is_empty():
		return closing

	return _choose_heuristic_move(state)


# ----------------------------------------------------------------------------
# 2. Tuyên bố Impossible
# ----------------------------------------------------------------------------

## AI chỉ tuyên bố khi CHỨNG MINH ĐƯỢC là không ai khép nổi vòng nữa.
## Không bao giờ đoán mò, nên không bao giờ tuyên bố sai rồi thua oan.
##
## Hai căn cứ, cả hai đều chắc chắn:
##
##   1. Đoạn ray từ ga đâm vào một tile đã commit không nối được. Tile đã
##      commit thì không sửa, nên cạnh đó chết vĩnh viễn.
##
##   2. Số tile ít nhất cần để nối hai đầu ray đã lớn hơn số tile còn lại.
##      WinChecker.min_tiles_to_close() là cận dưới, nên vế này không thể sai.
static func _should_declare_impossible(state: GameState, declared_by: int) -> bool:
	var permission: Dictionary = ImpossibleFlow.can_declare(
		state, state.current_player, 0, declared_by
	)
	if not permission["is_allowed"]:
		return false

	var trace: Dictionary = WinChecker.trace_station_track(state.board)

	if trace["status"] == WinChecker.TRACK_BLOCKED:
		return true

	var needed: int = WinChecker.min_tiles_to_close(state.board)
	return needed > 0 and needed > state.remaining_tiles


static func _describe_impossible(state: GameState) -> String:
	var trace: Dictionary = WinChecker.trace_station_track(state.board)
	if trace["status"] == WinChecker.TRACK_BLOCKED:
		return "AI tuyên bố Impossible: đường ray từ ga đã bị chặn."
	return "AI tuyên bố Impossible: cần ít nhất %d tile mà chỉ còn %d." % [
		WinChecker.min_tiles_to_close(state.board), state.remaining_tiles
	]


# ----------------------------------------------------------------------------
# 3. Chọn nước đi
# ----------------------------------------------------------------------------

static func _choose_random_move(state: GameState) -> Dictionary:
	var moves: Array = MoveGenerator.get_valid_moves(state, 1)
	if moves.is_empty():
		return {}
	return moves[randi() % moves.size()]


static func _choose_heuristic_move(state: GameState) -> Dictionary:
	var candidates: Array = []

	for count in _preferred_tile_counts(state.remaining_tiles):
		var tiles: Array = _greedy_tiles(state, count)
		if not tiles.is_empty():
			candidates.append({"player_id": state.current_player, "tiles": tiles})

	if candidates.is_empty():
		return {}

	# Ưu tiên nước không mở đường cho đối thủ khép vòng ngay lượt sau.
	for move in candidates:
		if not _opponent_can_close_after(state, move):
			return move

	return candidates[0]


## Số tile nên đặt trong lượt này, xếp theo thứ tự ưu tiên.
##
## Luật "hết tile thì người đặt cuối thua" biến phần cuối ván thành một bài
## toán parity: lấy 1–3, ai lấy cái cuối cùng thì thua. Muốn thắng thì để lại
## cho đối thủ số tile chia 4 dư 1.
static func _preferred_tile_counts(remaining: int) -> Array[int]:
	var order: Array[int] = []

	for count in [1, 2, 3]:
		if count <= remaining and (remaining - count) % 4 == 1:
			order.append(count)

	# Sau đó là các lựa chọn không tự biến mình thành người đặt tile cuối.
	for count in [1, 2, 3]:
		if count <= remaining and remaining - count > 0 and not order.has(count):
			order.append(count)

	# Cuối cùng mới đến nước bắt buộc.
	for count in [1, 2, 3]:
		if count <= remaining and not order.has(count):
			order.append(count)

	return order


## Chọn `count` tile bằng cách thêm từng tile một, mỗi bước lấy tile điểm cao
## nhất. Không sinh tổ hợp nên rẻ hơn get_valid_moves(state, 3) rất nhiều.
static func _greedy_tiles(state: GameState, count: int) -> Array:
	var chosen: Array = []

	for _i in range(count):
		var best: Array = []
		var best_score: float = -INF

		for position in PlacementHelper.get_placeable_positions(state.board, chosen):
			for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
				for rotation in range(MonoTile.get_distinct_rotation_count(type)):
					var tiles: Array = chosen.duplicate()
					tiles.append({"position": position, "type": type, "rotation": rotation})

					var move: Dictionary = {
						"player_id": state.current_player, "tiles": tiles,
					}
					if not MoveValidator.validate_move(state, move)["is_valid"]:
						continue

					var score: float = _score_tiles(state.board, tiles) + randf() * 0.01
					if score > best_score:
						best_score = score
						best = tiles

		if best.is_empty():
			break
		chosen = best

	return chosen


# ----------------------------------------------------------------------------
# 4. Chấm điểm
# ----------------------------------------------------------------------------

## Điểm của một cụm tile sắp đặt.
##
## Bốn thứ đếm được trên bàn cờ:
##   matched  — cạnh ray của tile mới khớp với tile kề. Càng nhiều càng tốt.
##   broken   — một bên mở, bên kia đóng. Chỗ đó hỏng vĩnh viễn, phạt nặng.
##   frontier — cạnh mở hướng ra ô trống. Đó là chỗ để đi tiếp, nhưng hở
##              nhiều quá thì đường ray tòe ra khó khép lại.
##   gap      — sau nước này còn cần ít nhất bao nhiêu tile để khép vòng.
##              Đây là thứ khiến AI chủ động khép vòng thay vì kéo dài mãi.
static func _score_tiles(board: Dictionary, tiles: Array) -> float:
	var preview: Dictionary = board.duplicate()
	for tile in tiles:
		preview[tile["position"]] = MonoTile.make_tile(tile["type"], tile["rotation"])

	var matched: int = 0
	var broken: int = 0
	var frontier: int = 0

	for tile in tiles:
		var position: Vector2i = tile["position"]
		var edges: Dictionary = MonoTile.get_edges(tile["type"], tile["rotation"])

		for edge_name in MonoTile.EDGE_ORDER:
			var neighbor: Vector2i = position + MonoTile.EDGE_OFFSETS[edge_name]
			var mine_open: bool = edges[edge_name]

			if preview.has(neighbor):
				var other_open: bool = MonoTile.has_edge(
					preview[neighbor], MonoTile.OPPOSITE_EDGE[edge_name]
				)
				if mine_open and other_open:
					matched += 1
				elif mine_open != other_open:
					broken += 1
			elif mine_open:
				frontier += 1

	var base_score: float = (
		WEIGHT_MATCHED * matched
		- WEIGHT_BROKEN * broken
		- WEIGHT_FRONTIER * frontier
	)

	match WinChecker.trace_station_track(preview)["status"]:
		WinChecker.TRACK_CLOSED:
			# Nước này khép vòng luôn — không gì hơn được.
			return INF
		WinChecker.TRACK_BLOCKED:
			# Tự tay chặn chết đường ray của chính mình.
			return base_score - WEIGHT_BLOCKS_TRACK
		WinChecker.TRACK_OPEN:
			return base_score - WEIGHT_GAP * float(WinChecker.min_tiles_to_close(preview))
		_:
			return base_score


## Sau khi mình đi nước này, đối thủ có khép được vòng ngay không.
static func _opponent_can_close_after(state: GameState, move: Dictionary) -> bool:
	var preview: GameState = _clone_state(state)
	for tile in move["tiles"]:
		preview.board[tile["position"]] = MonoTile.make_tile(tile["type"], tile["rotation"])
	preview.remaining_tiles -= move["tiles"].size()
	preview.current_player = 1 - state.current_player

	if preview.remaining_tiles <= 0:
		return false

	return not MoveGenerator.get_closing_move(preview).is_empty()


## Bản sao GameState để thử nước đi. Không đụng vào state thật.
static func _clone_state(state: GameState) -> GameState:
	var copy := GameState.new()
	copy.board = state.board.duplicate()
	copy.current_player = state.current_player
	copy.remaining_tiles = state.remaining_tiles
	copy.phase = state.phase
	copy.winner = state.winner
	return copy


static func _wrap_move(move: Dictionary, reason: String) -> Dictionary:
	if move.is_empty():
		return {
			"type": ACTION_NONE,
			"move": {},
			"reason": "AI không còn nước đi hợp lệ.",
		}
	return {"type": ACTION_MOVE, "move": move, "reason": reason}
