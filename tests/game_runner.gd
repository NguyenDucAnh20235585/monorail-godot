class_name GameRunner
extends RefCounted

# ============================================================================
# Monorail — Chạy trọn một ván bằng AI
# Phụ trách: Khiêm
#
# Vòng lặp một ván đấu, đi qua đúng pipeline mà controller của Công dùng:
#
#     AIPlayer.choose_action() -> validate_move() -> apply_move()
#         -> check_win() / resolve_after_move() -> end_turn()
#
# Hai chỗ cần cho AI chơi hết ván đều gọi vào đây thay vì tự viết lại:
#   tests/test_ai.gd     — AI tự chơi, kiểm tra không kẹt không sai
#   tests/ai_arena.gd    — AI tự chơi, in bàn cờ từng lượt
#
# tests/test_playthrough.gd KHÔNG dùng vòng lặp này: nó chạy một kịch bản nước
# đi định sẵn và kiểm tra từng bước một, nên cần vòng lặp riêng. Nó vẫn dùng
# chung build_move() ở dưới.
# ============================================================================

## Phát ra ngay khi AI chọn xong hành động, trước khi thực hiện.
signal action_chosen(turn: int, player: int, action: Dictionary)

## Phát ra sau khi một nước đi đã được apply vào state.
signal move_applied(turn: int, player: int, move: Dictionary)

## Phát ra khi có người tuyên bố Impossible.
signal impossible_declared(turn: int, player: int, declaration: Dictionary)


## Lý do ván kết thúc, ngoài các lý do của WinChecker và ImpossibleFlow.
const REASON_NO_MOVE: String = "NO_MOVE"                    ## không còn nước đi hợp lệ
const REASON_INVALID_MOVE: String = "INVALID_MOVE"          ## nước đi bị validator từ chối
const REASON_DECLARE_REJECTED: String = "DECLARE_REJECTED"  ## tuyên bố bị từ chối
const REASON_TOO_MANY_TURNS: String = "TOO_MANY_TURNS"      ## quá số lượt cho phép

## Chặn ván chạy vô hạn nếu có bug.
const DEFAULT_MAX_TURNS: int = 80

## Mức khó của từng người chơi, dạng { player_id: AIPlayer.Difficulty }.
## Người chơi không có trong đây thì dùng HEURISTIC.
var difficulties: Dictionary = {}

## Số lượt tối đa trước khi bỏ cuộc.
var max_turns: int = DEFAULT_MAX_TURNS

## Bật lên thì phát signal sau mỗi bước để bên ngoài in log.
var verbose: bool = false


## Chơi trọn một ván.
##
## `state` SẼ bị sửa, nên truyền vào một state riêng cho mỗi ván.
##
## Trả về:
##   {
##       "winner": int,        # -1 nếu ván không kết thúc bình thường
##       "reason": String,
##       "turns": int,
##       "declared_by": int
##   }
func play(state: GameState) -> Dictionary:
	var declared_by: int = ImpossibleFlow.NOBODY
	var turn: int = 0

	while turn < max_turns:
		turn += 1
		var mover: int = state.current_player
		var difficulty: AIPlayer.Difficulty = difficulties.get(
			mover, AIPlayer.Difficulty.HEURISTIC
		)
		var action: Dictionary = AIPlayer.choose_action(state, difficulty, declared_by)

		if verbose:
			action_chosen.emit(turn, mover, action)

		if action["type"] == AIPlayer.ACTION_NONE:
			return _finish(1 - mover, REASON_NO_MOVE, turn, declared_by)

		if action["type"] == AIPlayer.ACTION_DECLARE_IMPOSSIBLE:
			var declaration: Dictionary = ImpossibleFlow.declare_impossible(
				state, mover, 0, declared_by
			)
			if not declaration["is_valid"]:
				return _finish(-1, REASON_DECLARE_REJECTED, turn, declared_by)
			declared_by = declaration["declared_by"]
			state.current_player = declaration["challenger"]
			if verbose:
				impossible_declared.emit(turn, mover, declaration)
			continue

		var move: Dictionary = action["move"]
		if not MoveValidator.validate_move(state, move)["is_valid"]:
			return _finish(-1, REASON_INVALID_MOVE, turn, declared_by)

		RulesEngine.apply_move(state, move)
		if verbose:
			move_applied.emit(turn, mover, move)

		# Trong giai đoạn quyết định thì luật thắng khác, và KHÔNG đổi lượt.
		if ImpossibleFlow.is_in_review(declared_by):
			var outcome: Dictionary = ImpossibleFlow.resolve_after_move(
				state, move, declared_by
			)
			if outcome["is_finished"]:
				return _finish(outcome["winner"], outcome["reason"], turn, declared_by)
			continue

		var result: Dictionary = WinChecker.check_win(state, move)
		if result["is_win"]:
			return _finish(result["winner"], result["reason"], turn, declared_by)

		RulesEngine.end_turn(state)

	return _finish(-1, REASON_TOO_MANY_TURNS, turn, declared_by)


## Dựng Move từ dạng viết tắt `[[position, type, rotation], ...]`.
static func build_move(player_id: int, entries: Array) -> Dictionary:
	var tiles: Array = []
	for entry in entries:
		tiles.append({
			"position": entry[0], "type": entry[1], "rotation": entry[2],
		})
	return {"player_id": player_id, "tiles": tiles}


func _finish(winner: int, reason: String, turn: int, declared_by: int) -> Dictionary:
	return {
		"winner": winner,
		"reason": reason,
		"turns": turn,
		"declared_by": declared_by,
	}
