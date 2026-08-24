extends TestCase

# ============================================================================
# Monorail — Test win checker / impossible flow
# Phụ trách: Khiêm
# Week 3
#
# Cách chạy: mở scenes/TileTestRunner.tscn rồi bấm F6.
# ============================================================================

var straight: int = MonoTile.TileType.STRAIGHT
var corner: int = MonoTile.TileType.CORNER


func _ready() -> void:
	_begin("MONORAIL — WIN CHECKER / IMPOSSIBLE")

	_test_no_loop_yet()
	_test_complete_loop_wins()
	_test_incomplete_loop()
	_test_broken_track()
	_test_loop_without_station()
	_test_extra_tiles_outside_loop()
	_test_winner_is_last_mover()
	_test_out_of_tiles()
	_test_check_win_reads_only()

	_test_can_declare()
	_test_declare_result()
	_test_resolve_challenger_wins()
	_test_resolve_declarer_wins()
	_test_resolve_continue()
	_test_review_helpers()

	_print_summary()


# ----------------------------------------------------------------------------
# Dựng board test
# ----------------------------------------------------------------------------

func _make_state() -> GameState:
	var state := GameState.new()
	state.board = {
		RulesEngine.LEFT_START_POS: MonoTile.make_tile(straight, 1),
		RulesEngine.RIGHT_START_POS: MonoTile.make_tile(straight, 1),
	}
	state.current_player = 0
	state.remaining_tiles = 24
	state.phase = GameState.GamePhase.PLACING
	state.winner = -1
	return state


## Board có một vòng khép kín 10 tile đi qua cả hai ga.
##
##   (-1,0) ─ (0,0)ga ─ (1,0)ga ─ (2,0)
##     │                            │
##   (-1,1)                      (2,1)
##     │                            │
##   (-1,2) ─ (0,2) ─── (1,2) ─── (2,2)
func _make_loop_state() -> GameState:
	var state: GameState = _make_state()
	state.board[Vector2i(-1, 0)] = MonoTile.make_tile(corner, 1)    # right + bottom
	state.board[Vector2i(2, 0)] = MonoTile.make_tile(corner, 2)     # bottom + left
	state.board[Vector2i(2, 1)] = MonoTile.make_tile(straight, 0)
	state.board[Vector2i(2, 2)] = MonoTile.make_tile(corner, 3)     # left + top
	state.board[Vector2i(1, 2)] = MonoTile.make_tile(straight, 1)
	state.board[Vector2i(0, 2)] = MonoTile.make_tile(straight, 1)
	state.board[Vector2i(-1, 2)] = MonoTile.make_tile(corner, 0)    # top + right
	state.board[Vector2i(-1, 1)] = MonoTile.make_tile(straight, 0)
	state.remaining_tiles = 24 - 8
	return state


## Vòng 4 tile ở xa, không dính gì tới ga.
func _add_far_loop(state: GameState) -> void:
	state.board[Vector2i(5, 5)] = MonoTile.make_tile(corner, 1)
	state.board[Vector2i(6, 5)] = MonoTile.make_tile(corner, 2)
	state.board[Vector2i(6, 6)] = MonoTile.make_tile(corner, 3)
	state.board[Vector2i(5, 6)] = MonoTile.make_tile(corner, 0)


func _move(player_id: int, entries: Array) -> Dictionary:
	var tiles: Array = []
	for e in entries:
		tiles.append({"position": e[0], "type": e[1], "rotation": e[2]})
	return {"player_id": player_id, "tiles": tiles}


# ----------------------------------------------------------------------------
# check_win
# ----------------------------------------------------------------------------

func _test_no_loop_yet() -> void:
	_group("Board ban đầu — chưa có vòng")

	var state: GameState = _make_state()
	var result: Dictionary = WinChecker.check_win(state, _move(0, []))

	_assert_false(result["is_win"], "hai tile ga chưa tạo thành vòng")
	_assert_eq(result["winner"], -1, "chưa có người thắng")
	_assert_true(result["loop_positions"].is_empty(), "không có vòng nào")

	_assert_true(
		WinChecker.find_loop(state.board, RulesEngine.LEFT_START_POS).is_empty(),
		"đi từ ga trái thì cụt, không quay lại được"
	)


func _test_complete_loop_wins() -> void:
	_group("Vòng khép kín qua ga — THẮNG")

	var state: GameState = _make_loop_state()
	var result: Dictionary = WinChecker.check_win(state, _move(1, []))

	_assert_true(result["is_win"], "vòng khép kín qua ga -> thắng")
	_assert_eq(result["winner"], 1, "winner là người vừa đặt tile")
	_assert_eq(result["loop_positions"].size(), 10, "vòng gồm đúng 10 tile")

	var loop: Array = result["loop_positions"]
	_assert_true(loop.has(RulesEngine.LEFT_START_POS), "ga trái nằm trong vòng")
	_assert_true(loop.has(RulesEngine.RIGHT_START_POS), "ga phải nằm trong vòng")


func _test_incomplete_loop() -> void:
	_group("Vòng chưa khép kín")

	# Thiếu một tile ở ba vị trí khác nhau đều phải cho ra "chưa thắng"
	for missing in [Vector2i(-1, 0), Vector2i(2, 1), Vector2i(0, 2)]:
		var state: GameState = _make_loop_state()
		state.board.erase(missing)
		_assert_false(
			WinChecker.check_win(state, _move(0, []))["is_win"],
			"thiếu tile ở %s -> chưa thắng" % str(missing)
		)

	# Thiếu hẳn một tile ga
	var no_station: GameState = _make_loop_state()
	no_station.board.erase(RulesEngine.RIGHT_START_POS)
	_assert_false(
		WinChecker.check_win(no_station, _move(0, []))["is_win"],
		"thiếu tile ga -> không thắng"
	)


func _test_broken_track() -> void:
	_group("Đường ray bị đứt")

	var wrong_rotation: GameState = _make_loop_state()
	wrong_rotation.board[Vector2i(2, 1)] = MonoTile.make_tile(straight, 1)
	_assert_false(
		WinChecker.check_win(wrong_rotation, _move(0, []))["is_win"],
		"tile xoay sai hướng -> ray đứt -> chưa thắng"
	)

	var wrong_type: GameState = _make_loop_state()
	wrong_type.board[Vector2i(0, 2)] = MonoTile.make_tile(corner, 0)
	_assert_false(
		WinChecker.check_win(wrong_type, _move(0, []))["is_win"],
		"đổi STRAIGHT thành CORNER -> ray đứt -> chưa thắng"
	)


func _test_loop_without_station() -> void:
	_group("Vòng khép kín nhưng không qua ga")

	var state: GameState = _make_state()
	_add_far_loop(state)

	_assert_false(
		WinChecker.find_loop(state.board, Vector2i(5, 5)).is_empty(),
		"đúng là có vòng 4 tile ở xa"
	)
	_assert_false(
		WinChecker.check_win(state, _move(0, []))["is_win"],
		"vòng không chứa ga -> KHÔNG thắng"
	)


func _test_extra_tiles_outside_loop() -> void:
	_group("Tile nằm ngoài vòng")

	var stray: GameState = _make_loop_state()
	stray.board[Vector2i(4, 4)] = MonoTile.make_tile(straight, 0)
	_assert_true(
		WinChecker.check_win(stray, _move(0, []))["is_win"],
		"tile lẻ ngoài vòng không làm mất chiến thắng"
	)

	var two_loops: GameState = _make_loop_state()
	_add_far_loop(two_loops)
	_assert_true(
		WinChecker.check_win(two_loops, _move(0, []))["is_win"],
		"có thêm vòng khác ở xa vẫn thắng"
	)


func _test_winner_is_last_mover() -> void:
	_group("Winner là người đặt tile cuối cùng")

	var state: GameState = _make_loop_state()

	state.current_player = 0
	_assert_eq(
		WinChecker.check_win(state, _move(1, []))["winner"], 1,
		"lấy player_id từ last_move, không lấy current_player"
	)

	state.current_player = 1
	_assert_eq(
		WinChecker.check_win(state, {})["winner"], 1,
		"không có last_move thì lấy current_player"
	)


func _test_out_of_tiles() -> void:
	_group("Hết tile mà chưa có vòng — người đặt cuối THUA")

	var state: GameState = _make_state()
	state.remaining_tiles = 0

	var result: Dictionary = WinChecker.check_win(state, _move(0, []))

	_assert_true(result["is_win"], "ván kết thúc khi hết tile")
	_assert_eq(
		result["reason"], WinChecker.REASON_OUT_OF_TILES,
		"lý do: hết tile mà chưa khép vòng"
	)
	_assert_eq(result["winner"], 1, "Người chơi 1 đặt cuối -> Người chơi 2 thắng")

	var other_mover: Dictionary = WinChecker.check_win(state, _move(1, []))
	_assert_eq(other_mover["winner"], 0, "đổi người đặt cuối thì đổi người thắng")

	# Còn tile thì chưa kết thúc
	var still_playing: GameState = _make_state()
	still_playing.remaining_tiles = 1
	_assert_false(
		WinChecker.check_win(still_playing, _move(0, []))["is_win"],
		"còn 1 tile -> chưa kết thúc"
	)

	# Khép được vòng bằng tile cuối cùng thì luật thắng được ưu tiên
	var last_tile_wins: GameState = _make_loop_state()
	last_tile_wins.remaining_tiles = 0
	var win: Dictionary = WinChecker.check_win(last_tile_wins, _move(0, []))
	_assert_eq(
		win["reason"], WinChecker.REASON_LOOP_COMPLETED,
		"khép vòng bằng tile cuối -> ưu tiên luật thắng"
	)
	_assert_eq(win["winner"], 0, "người khép vòng thắng dù đã hết tile")

	_assert_eq(
		WinChecker.check_win(_make_state(), _move(0, []))["reason"],
		WinChecker.REASON_NONE,
		"chưa kết thúc thì reason = NONE"
	)


func _test_check_win_reads_only() -> void:
	_group("check_win chỉ đọc, không sửa state")

	var state: GameState = _make_loop_state()
	var board_before: int = state.board.size()
	var tiles_before: int = state.remaining_tiles
	var winner_before: int = state.winner
	var phase_before: int = state.phase

	WinChecker.check_win(state, _move(0, []))

	_assert_eq(state.board.size(), board_before, "board không đổi")
	_assert_eq(state.remaining_tiles, tiles_before, "remaining_tiles không đổi")
	_assert_eq(state.winner, winner_before, "winner không bị ghi")
	_assert_eq(state.phase, phase_before, "phase không bị đổi")


# ----------------------------------------------------------------------------
# Impossible — tuyên bố
# ----------------------------------------------------------------------------

func _test_can_declare() -> void:
	_group("ImpossibleFlow — khi nào được tuyên bố")

	var state: GameState = _make_state()

	_assert_true(
		ImpossibleFlow.can_declare(state, 0)["is_allowed"],
		"đầu lượt, chưa đặt tile -> được tuyên bố"
	)

	_assert_error_code(
		ImpossibleFlow.can_declare(state, 1),
		ImpossibleFlow.WRONG_PLAYER, "không phải lượt mình"
	)
	_assert_error_code(
		ImpossibleFlow.can_declare(state, 0, 2),
		ImpossibleFlow.PENDING_NOT_EMPTY, "đã đặt pending tile"
	)
	_assert_error_code(
		ImpossibleFlow.can_declare(state, 0, 0, 1),
		ImpossibleFlow.ALREADY_DECLARED, "đã có người tuyên bố"
	)

	var finished: GameState = _make_state()
	finished.phase = GameState.GamePhase.GAME_FINISHED
	_assert_error_code(
		ImpossibleFlow.can_declare(finished, 0),
		ImpossibleFlow.GAME_ALREADY_FINISHED, "ván đã kết thúc"
	)

	var no_tiles: GameState = _make_state()
	no_tiles.remaining_tiles = 0
	_assert_error_code(
		ImpossibleFlow.can_declare(no_tiles, 0),
		ImpossibleFlow.NO_TILES_LEFT, "hết tile thì tuyên bố vô nghĩa"
	)


func _test_declare_result() -> void:
	_group("ImpossibleFlow — kết quả tuyên bố")

	var state: GameState = _make_state()
	state.current_player = 1

	var result: Dictionary = ImpossibleFlow.declare_impossible(state, 1)

	_assert_true(result["is_valid"], "tuyên bố hợp lệ")
	_assert_eq(result["declared_by"], 1, "ghi đúng người tuyên bố")
	_assert_eq(result["challenger"], 0, "đối thủ là người phải hoàn thành")
	_assert_false(result["message"].is_empty(), "có message cho game log")

	var rejected: Dictionary = ImpossibleFlow.declare_impossible(state, 0)
	_assert_false(rejected["is_valid"], "sai lượt -> bị từ chối")
	_assert_eq(
		rejected["declared_by"], ImpossibleFlow.NOBODY,
		"bị từ chối thì không trả về người tuyên bố"
	)

	# declare_impossible không được sửa state
	_assert_eq(state.current_player, 1, "state.current_player không bị đổi")
	_assert_eq(state.phase, GameState.GamePhase.PLACING, "state.phase không bị đổi")


# ----------------------------------------------------------------------------
# Impossible — giải quyết
# ----------------------------------------------------------------------------

func _test_resolve_challenger_wins() -> void:
	_group("Đối thủ hoàn thành được -> đối thủ thắng")

	# Player 1 tuyên bố, player 0 là người phải hoàn thành và làm được.
	var state: GameState = _make_loop_state()
	var result: Dictionary = ImpossibleFlow.resolve_after_move(state, _move(0, []), 1)

	_assert_true(result["is_finished"], "ván kết thúc")
	_assert_eq(result["winner"], 0, "đối thủ thắng vì chứng minh tuyên bố sai")
	_assert_eq(
		result["reason"], ImpossibleFlow.CHALLENGER_COMPLETED_LOOP,
		"lý do: hoàn thành được vòng"
	)
	_assert_eq(result["loop_positions"].size(), 10, "trả về vòng để UI tô sáng")


func _test_resolve_declarer_wins() -> void:
	_group("Đối thủ hết tile mà chưa xong -> người tuyên bố thắng")

	var state: GameState = _make_state()
	state.remaining_tiles = 0

	var result: Dictionary = ImpossibleFlow.resolve_after_move(state, _move(0, []), 1)

	_assert_true(result["is_finished"], "ván kết thúc")
	_assert_eq(result["winner"], 1, "người tuyên bố thắng")
	_assert_eq(
		result["reason"], ImpossibleFlow.CHALLENGER_OUT_OF_TILES,
		"lý do: hết tile"
	)

	# Hoàn thành đúng lúc tile cuối cùng thì vẫn tính là đối thủ thắng
	var last_tile: GameState = _make_loop_state()
	last_tile.remaining_tiles = 0
	var edge_case: Dictionary = ImpossibleFlow.resolve_after_move(last_tile, _move(0, []), 1)
	_assert_eq(
		edge_case["winner"], 0,
		"hoàn thành bằng tile cuối cùng -> đối thủ vẫn thắng"
	)


func _test_resolve_continue() -> void:
	_group("Đối thủ còn tile -> tiếp tục đi")

	var state: GameState = _make_state()
	state.remaining_tiles = 5

	var result: Dictionary = ImpossibleFlow.resolve_after_move(state, _move(0, []), 1)

	_assert_false(result["is_finished"], "chưa kết thúc")
	_assert_eq(result["winner"], ImpossibleFlow.NOBODY, "chưa có người thắng")
	_assert_eq(result["reason"], ImpossibleFlow.CONTINUE, "lý do: còn đi tiếp")

	# Ngoài giai đoạn quyết định thì hàm này không phán gì cả
	var normal: Dictionary = ImpossibleFlow.resolve_after_move(
		_make_loop_state(), _move(0, []), ImpossibleFlow.NOBODY
	)
	_assert_false(normal["is_finished"], "chưa ai tuyên bố -> không xử lý")


func _test_review_helpers() -> void:
	_group("ImpossibleFlow — hàm phụ trợ")

	_assert_false(ImpossibleFlow.is_in_review(ImpossibleFlow.NOBODY), "chưa ai tuyên bố")
	_assert_true(ImpossibleFlow.is_in_review(0), "player 0 đã tuyên bố")

	_assert_eq(ImpossibleFlow.get_challenger(0), 1, "đối thủ của player 0 là player 1")
	_assert_eq(ImpossibleFlow.get_challenger(1), 0, "đối thủ của player 1 là player 0")
	_assert_eq(
		ImpossibleFlow.get_challenger(ImpossibleFlow.NOBODY), ImpossibleFlow.NOBODY,
		"chưa tuyên bố thì không có challenger"
	)

	_assert_true(
		ImpossibleFlow.should_switch_player(ImpossibleFlow.NOBODY),
		"lượt bình thường -> đổi người chơi"
	)
	_assert_false(
		ImpossibleFlow.should_switch_player(1),
		"giai đoạn quyết định -> đối thủ đi liên tiếp, không đổi lượt"
	)


# ----------------------------------------------------------------------------
# Hạ tầng riêng của nhóm test này
# (phần đếm PASS/FAIL nằm ở tests/test_case.gd)
# ----------------------------------------------------------------------------

func _assert_error_code(result: Dictionary, expected: String, label: String) -> void:
	if not result["is_allowed"] and result["error_code"] == expected:
		_pass("%s -> %s" % [label, expected])
	else:
		_fail("%s (mong đợi %s, nhận %s)" % [label, expected, result["error_code"]])
