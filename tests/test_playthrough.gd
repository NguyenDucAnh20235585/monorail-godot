extends TestCase

# ============================================================================
# Monorail — Test chơi hết ván
# Phụ trách: Khiêm
# Week 3
#
# Khác với các file test kia (kiểm tra từng hàm riêng lẻ), file này mô phỏng
# TRỌN VẸN bốn ván đấu, đi qua đúng pipeline mà controller của Công dùng:
#
#     validate_move()  ->  apply_move()  ->  check_win()  ->  end_turn()
#
# Nếu ba phần của hai người ghép sai với nhau thì sẽ lộ ra ở đây chứ không
# phải lúc playtest bằng tay.
#
# Cách chạy: mở scenes/TileTestRunner.tscn rồi bấm F6, xem log ở Output.
# ============================================================================

var straight: int = MonoTile.TileType.STRAIGHT
var corner: int = MonoTile.TileType.CORNER


func _ready() -> void:
	_begin("MONORAIL — CHƠI HẾT VÁN (INTEGRATION)")

	_play_normal_game()
	_play_impossible_challenger_wins()
	_play_impossible_declarer_wins()
	_play_out_of_tiles()

	_print_summary()


# ----------------------------------------------------------------------------
# Kịch bản chung: 8 tile khép thành vòng quanh hai ga
# ----------------------------------------------------------------------------

## Từng lượt một, theo đúng thứ tự người chơi đặt.
## Mỗi phần tử: [[position, type, rotation], ...] — 1 đến 3 tile.
func _loop_turns() -> Array:
	return [
		[[Vector2i(2, 0), corner, 2]],
		[[Vector2i(2, 1), straight, 0], [Vector2i(2, 2), corner, 3]],
		[[Vector2i(1, 2), straight, 1], [Vector2i(0, 2), straight, 1]],
		[[Vector2i(-1, 2), corner, 0], [Vector2i(-1, 1), straight, 0]],
		[[Vector2i(-1, 0), corner, 1]],
	]


# ----------------------------------------------------------------------------
# Ván 1 — chơi bình thường tới khi khép vòng
# ----------------------------------------------------------------------------

func _play_normal_game() -> void:
	_group("VÁN 1 — hai người thay phiên nhau tới khi khép vòng")

	var state: GameState = RulesEngine.create_initial_state()
	state.current_player = 0

	var tiles_at_start: int = state.remaining_tiles
	var turns: Array = _loop_turns()
	var placed: int = 0
	var finished_at: int = -1
	var final_result: Dictionary = {}

	for i in range(turns.size()):
		var entries: Array = turns[i]
		var mover: int = state.current_player
		var move: Dictionary = _move(mover, entries)

		var validation: Dictionary = MoveValidator.validate_move(state, move)
		if not validation["is_valid"]:
			_fail("Lượt %d bị validator chặn: %s (%s)" % [
				i + 1, validation["message"], validation["error_code"]
			])
			return

		RulesEngine.apply_move(state, move)
		placed += entries.size()

		var result: Dictionary = WinChecker.check_win(state, move)
		_log_turn(i + 1, mover, entries.size(), state, result)

		if result["is_win"]:
			finished_at = i
			final_result = result
			break

		RulesEngine.end_turn(state)

	_assert_eq(finished_at, turns.size() - 1, "ván kết thúc đúng ở lượt cuối, không sớm hơn")
	_assert_eq(
		final_result.get("reason", ""), WinChecker.REASON_LOOP_COMPLETED,
		"lý do kết thúc: hoàn thành vòng"
	)
	_assert_eq(final_result.get("winner", -1), 0, "người đặt tile cuối (Người chơi 1) thắng")
	_assert_eq(
		final_result.get("loop_positions", []).size(), 10,
		"vòng gồm 10 tile (8 tile đặt + 2 ga)"
	)
	_assert_eq(placed, 8, "đã đặt đúng 8 tile")
	_assert_eq(
		state.remaining_tiles, tiles_at_start - 8,
		"remaining_tiles giảm đúng 8"
	)
	_assert_eq(state.board.size(), 10, "board có 10 tile")


# ----------------------------------------------------------------------------
# Ván 2 — tuyên bố Impossible, đối thủ hoàn thành được
# ----------------------------------------------------------------------------

func _play_impossible_challenger_wins() -> void:
	_group("VÁN 2 — Impossible, đối thủ chứng minh tuyên bố sai")

	var state: GameState = RulesEngine.create_initial_state()
	state.current_player = 0
	var declared_by: int = ImpossibleFlow.NOBODY

	var turns: Array = _loop_turns()

	# Lượt 1: Người chơi 1 đặt bình thường.
	if not _apply_turn(state, _move(0, turns[0]), "lượt 1"):
		return
	_assert_false(
		WinChecker.check_win(state, _move(0, turns[0]))["is_win"],
		"sau lượt 1 chưa ai thắng"
	)
	RulesEngine.end_turn(state)

	# Lượt 2: tới lượt Người chơi 2, nhưng bấm Declare Impossible.
	var declaration: Dictionary = ImpossibleFlow.declare_impossible(
		state, state.current_player, 0, declared_by
	)
	_assert_true(declaration["is_valid"], "Người chơi 2 tuyên bố được ở đầu lượt")
	_assert_eq(declaration["declared_by"], 1, "người tuyên bố là Người chơi 2")
	_assert_eq(declaration["challenger"], 0, "Người chơi 1 phải hoàn thành đường ray")

	declared_by = declaration["declared_by"]
	state.current_player = declaration["challenger"]
	print("  >> Người chơi 2 tuyên bố KHÔNG THỂ HOÀN THÀNH")

	# Người chơi 1 đi liên tiếp, không đổi lượt.
	var outcome: Dictionary = {}
	for i in range(1, turns.size()):
		_assert_false(
			ImpossibleFlow.should_switch_player(declared_by),
			"giai đoạn quyết định: không đổi lượt sau lượt %d" % (i + 1)
		)

		var move: Dictionary = _move(state.current_player, turns[i])
		if not _apply_turn(state, move, "lượt %d" % (i + 1)):
			return

		outcome = ImpossibleFlow.resolve_after_move(state, move, declared_by)
		print("  >> %s" % outcome["message"])

		if outcome["is_finished"]:
			_assert_eq(i, turns.size() - 1, "ván chỉ kết thúc ở lượt cuối")
			break

		_assert_eq(outcome["reason"], ImpossibleFlow.CONTINUE, "chưa xong thì tiếp tục")

	_assert_true(outcome.get("is_finished", false), "ván kết thúc")
	_assert_eq(
		outcome.get("reason", ""), ImpossibleFlow.CHALLENGER_COMPLETED_LOOP,
		"lý do: đối thủ hoàn thành được vòng"
	)
	_assert_eq(outcome.get("winner", -1), 0, "Người chơi 1 thắng vì chứng minh tuyên bố sai")


# ----------------------------------------------------------------------------
# Ván 3 — tuyên bố Impossible, đối thủ hết tile mà không xong
# ----------------------------------------------------------------------------

func _play_impossible_declarer_wins() -> void:
	_group("VÁN 3 — Impossible, đối thủ hết tile mà không hoàn thành")

	var state: GameState = RulesEngine.create_initial_state()
	state.current_player = 1
	state.remaining_tiles = 2

	var declaration: Dictionary = ImpossibleFlow.declare_impossible(
		state, 1, 0, ImpossibleFlow.NOBODY
	)
	_assert_true(declaration["is_valid"], "Người chơi 2 tuyên bố ở đầu lượt của mình")

	var declared_by: int = declaration["declared_by"]
	state.current_player = declaration["challenger"]
	print("  >> Người chơi 2 tuyên bố, Người chơi 1 còn 2 tile để chứng minh")

	var move: Dictionary = _move(0, [
		[Vector2i(2, 0), straight, 1],
		[Vector2i(3, 0), straight, 1],
	])
	if not _apply_turn(state, move, "lượt cuối của đối thủ"):
		return

	_assert_eq(state.remaining_tiles, 0, "đã dùng hết tile")

	var outcome: Dictionary = ImpossibleFlow.resolve_after_move(state, move, declared_by)
	print("  >> %s" % outcome["message"])

	_assert_true(outcome["is_finished"], "ván kết thúc")
	_assert_eq(
		outcome["reason"], ImpossibleFlow.CHALLENGER_OUT_OF_TILES,
		"lý do: đối thủ hết tile"
	)
	_assert_eq(outcome["winner"], 1, "Người chơi 2 (người tuyên bố) thắng")


# ----------------------------------------------------------------------------
# Ván 4 — hết tile mà không ai tuyên bố
# ----------------------------------------------------------------------------

func _play_out_of_tiles() -> void:
	_group("VÁN 4 — hết tile, không ai tuyên bố: người đặt cuối THUA")

	var state: GameState = RulesEngine.create_initial_state()
	state.current_player = 0
	state.remaining_tiles = 1

	var move: Dictionary = _move(0, [[Vector2i(2, 0), straight, 1]])
	if not _apply_turn(state, move, "lượt cuối"):
		return

	_assert_eq(state.remaining_tiles, 0, "đã dùng hết tile")

	var result: Dictionary = WinChecker.check_win(state, move)
	print("  >> %s" % (
		"Người chơi %d thắng" % (result["winner"] + 1) if result["is_win"] else "chưa kết thúc"
	))

	_assert_true(result["is_win"], "ván kết thúc khi hết tile")
	_assert_eq(
		result["reason"], WinChecker.REASON_OUT_OF_TILES,
		"lý do: hết tile mà chưa có vòng"
	)
	_assert_eq(
		result["winner"], 1,
		"Người chơi 1 đặt tile cuối nên THUA, Người chơi 2 thắng"
	)

	# Hết tile nhưng khép được vòng thì vẫn là người đặt cuối THẮNG
	var winning: GameState = RulesEngine.create_initial_state()
	winning.current_player = 0
	winning.remaining_tiles = 24
	for entries in _loop_turns():
		var turn_move: Dictionary = _move(0, entries)
		winning.current_player = 0
		RulesEngine.apply_move(winning, turn_move)
	winning.remaining_tiles = 0

	var last: Dictionary = _move(0, [[Vector2i(-1, 0), corner, 1]])
	var winning_result: Dictionary = WinChecker.check_win(winning, last)
	_assert_eq(
		winning_result["reason"], WinChecker.REASON_LOOP_COMPLETED,
		"khép vòng bằng tile cuối cùng: ưu tiên luật thắng, không phải luật hết tile"
	)
	_assert_eq(winning_result["winner"], 0, "người khép vòng thắng dù đã hết tile")


# ----------------------------------------------------------------------------
# Tiện ích
# ----------------------------------------------------------------------------

func _move(player_id: int, entries: Array) -> Dictionary:
	return GameRunner.build_move(player_id, entries)


## Validate rồi apply. Trả về false và báo lỗi nếu validator chặn.
func _apply_turn(state: GameState, move: Dictionary, label: String) -> bool:
	var validation: Dictionary = MoveValidator.validate_move(state, move)
	if not validation["is_valid"]:
		_fail("%s bị validator chặn: %s (%s)" % [
			label, validation["message"], validation["error_code"]
		])
		return false
	RulesEngine.apply_move(state, move)
	_pass("%s hợp lệ, đã apply" % label)
	return true


func _log_turn(
	turn: int, mover: int, tile_count: int, state: GameState, result: Dictionary
) -> void:
	var status: String = "chưa kết thúc"
	if result["is_win"]:
		status = "KẾT THÚC — Người chơi %d thắng (%s)" % [
			result["winner"] + 1, result["reason"]
		]
	print("  Lượt %d — Người chơi %d đặt %d tile | còn %d tile | %s" % [
		turn, mover + 1, tile_count, state.remaining_tiles, status
	])
