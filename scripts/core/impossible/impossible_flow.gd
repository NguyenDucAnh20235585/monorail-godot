class_name ImpossibleFlow
extends RefCounted

# ============================================================================
# Monorail — Impossible Flow
# Phụ trách: Khiêm
# Week 3 — Impossible Logic
#
# Luật (đã chốt):
#   1. Đầu lượt của mình, người chơi có thể tuyên bố "không thể hoàn thành".
#   2. Ván bước vào giai đoạn quyết định: ĐỐI THỦ dùng số tile còn lại để cố
#      hoàn thành đường ray. Người tuyên bố không đặt tile nữa.
#   3. Đối thủ hoàn thành được vòng  -> ĐỐI THỦ thắng.
#      Đối thủ dùng hết tile mà không xong -> NGƯỜI TUYÊN BỐ thắng.
#
# Engine KHÔNG tự phán đoán tuyên bố đúng hay sai. Nó chỉ kiểm tra state có
# hợp lệ để tuyên bố không, rồi để đối thủ chứng minh bằng cách chơi.
# (Tự dò xem có hoàn thành được không là bài toán tìm kiếm rất lớn với 24 tile.)
#
# Toàn bộ hàm là STATIC và CHỈ ĐỌC — không sửa GameState.
# Kết quả trả về nói cho Công biết cần ghi gì; việc ghi là của Công.
# ============================================================================


# ----------------------------------------------------------------------------
# Mã lỗi
# ----------------------------------------------------------------------------

const OK: String = "OK"
const GAME_ALREADY_FINISHED: String = "GAME_ALREADY_FINISHED"
const WRONG_PLAYER: String = "WRONG_PLAYER"
const ALREADY_DECLARED: String = "ALREADY_DECLARED"
const PENDING_NOT_EMPTY: String = "PENDING_NOT_EMPTY"
const NO_TILES_LEFT: String = "NO_TILES_LEFT"

# Lý do kết thúc giai đoạn quyết định
const CONTINUE: String = "CONTINUE"
const CHALLENGER_COMPLETED_LOOP: String = "CHALLENGER_COMPLETED_LOOP"
const CHALLENGER_OUT_OF_TILES: String = "CHALLENGER_OUT_OF_TILES"

## Giá trị của `impossible_declared_by` khi chưa ai tuyên bố.
const NOBODY: int = -1


# ----------------------------------------------------------------------------
# 1. Truy vấn trạng thái
# ----------------------------------------------------------------------------

## Ván có đang ở giai đoạn quyết định không.
static func is_in_review(declared_by: int) -> bool:
	return declared_by != NOBODY


## Người phải hoàn thành đường ray — tức đối thủ của người tuyên bố.
static func get_challenger(declared_by: int) -> int:
	if not is_in_review(declared_by):
		return NOBODY
	return 1 - declared_by


## Sau mỗi nước đi, có đổi lượt không.
##
## Trong giai đoạn quyết định thì KHÔNG đổi: đối thủ đi liên tiếp cho tới khi
## hoàn thành vòng hoặc hết tile. Công gọi hàm này thay cho việc gọi thẳng
## end_turn().
static func should_switch_player(declared_by: int) -> bool:
	return not is_in_review(declared_by)


# ----------------------------------------------------------------------------
# 2. Tuyên bố
# ----------------------------------------------------------------------------

## Người chơi có được phép tuyên bố lúc này không.
##
## Dùng để bật/tắt nút Declare Impossible trên UI, gọi bao nhiêu lần cũng được
## vì hàm không đổi gì cả.
##
## Trả về:
##   { "is_allowed": bool, "error_code": String, "message": String }
static func can_declare(
	state: GameState,
	player_id: int,
	pending_tile_count: int = 0,
	declared_by: int = NOBODY
) -> Dictionary:
	if state.phase == GameState.GamePhase.GAME_FINISHED:
		return _not_allowed(GAME_ALREADY_FINISHED, "Ván đấu đã kết thúc.")

	if is_in_review(declared_by):
		return _not_allowed(
			ALREADY_DECLARED,
			"Đã có người tuyên bố không thể hoàn thành trong ván này."
		)

	if player_id != state.current_player:
		return _not_allowed(WRONG_PLAYER, "Chưa đến lượt của người chơi này.")

	if pending_tile_count > 0:
		return _not_allowed(
			PENDING_NOT_EMPTY,
			"Chỉ được tuyên bố ở đầu lượt, khi chưa đặt tile nào."
		)

	if state.remaining_tiles <= 0:
		return _not_allowed(
			NO_TILES_LEFT,
			"Đã hết tile, đối thủ không còn gì để đặt."
		)

	return {"is_allowed": true, "error_code": OK, "message": ""}


## Thực hiện tuyên bố.
##
## KHÔNG sửa state. Trả về những gì Công cần ghi:
##   {
##       "is_valid": bool,
##       "error_code": String,
##       "message": String,
##       "declared_by": int,     # ghi vào state.impossible_declared_by
##       "challenger": int       # đặt làm state.current_player
##   }
##
## Khi không hợp lệ, `declared_by` và `challenger` đều là NOBODY.
static func declare_impossible(
	state: GameState,
	player_id: int,
	pending_tile_count: int = 0,
	declared_by: int = NOBODY
) -> Dictionary:
	var check: Dictionary = can_declare(state, player_id, pending_tile_count, declared_by)

	if not check["is_allowed"]:
		return {
			"is_valid": false,
			"error_code": check["error_code"],
			"message": check["message"],
			"declared_by": NOBODY,
			"challenger": NOBODY,
		}

	return {
		"is_valid": true,
		"error_code": OK,
		"message": "Người chơi %d tuyên bố không thể hoàn thành." % (player_id + 1),
		"declared_by": player_id,
		"challenger": 1 - player_id,
	}


# ----------------------------------------------------------------------------
# 3. Giải quyết giai đoạn quyết định
# ----------------------------------------------------------------------------

## Gọi sau mỗi apply_move() trong giai đoạn quyết định.
##
## Trả về:
##   {
##       "is_finished": bool,
##       "winner": int,             # NOBODY nếu chưa xong
##       "reason": String,
##       "message": String,
##       "loop_positions": Array[Vector2i]
##   }
##
## `reason` là một trong:
##   CONTINUE                  — đối thủ còn tile, tiếp tục đi
##   CHALLENGER_COMPLETED_LOOP — đối thủ hoàn thành vòng, đối thủ thắng
##   CHALLENGER_OUT_OF_TILES   — hết tile mà chưa xong, người tuyên bố thắng
static func resolve_after_move(
	state: GameState,
	last_move: Dictionary,
	declared_by: int
) -> Dictionary:
	if not is_in_review(declared_by):
		return _unfinished(CONTINUE, "Ván không ở giai đoạn quyết định.")

	var challenger: int = get_challenger(declared_by)
	var win: Dictionary = WinChecker.check_win(state, last_move)

	# Chỉ nhận trường hợp hoàn thành vòng. Trường hợp hết tile do WinChecker báo
	# được xử lý riêng ở dưới, vì trong giai đoạn quyết định luật thắng khác.
	if win["reason"] == WinChecker.REASON_LOOP_COMPLETED:
		return {
			"is_finished": true,
			"winner": challenger,
			"reason": CHALLENGER_COMPLETED_LOOP,
			"message": "Người chơi %d hoàn thành đường ray và thắng." % (challenger + 1),
			"loop_positions": win["loop_positions"],
		}

	if state.remaining_tiles <= 0:
		return {
			"is_finished": true,
			"winner": declared_by,
			"reason": CHALLENGER_OUT_OF_TILES,
			"message": "Hết tile mà chưa hoàn thành. Người chơi %d thắng." % (declared_by + 1),
			"loop_positions": _empty_positions(),
		}

	return _unfinished(
		CONTINUE,
		"Người chơi %d còn %d tile để hoàn thành đường ray." % [
			challenger + 1, state.remaining_tiles
		]
	)


# ----------------------------------------------------------------------------
# 4. Nội bộ
# ----------------------------------------------------------------------------

static func _not_allowed(code: String, message: String) -> Dictionary:
	return {"is_allowed": false, "error_code": code, "message": message}


static func _unfinished(reason: String, message: String) -> Dictionary:
	return {
		"is_finished": false,
		"winner": NOBODY,
		"reason": reason,
		"message": message,
		"loop_positions": _empty_positions(),
	}


static func _empty_positions() -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	return empty
