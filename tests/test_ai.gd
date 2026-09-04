extends TestCase

# ============================================================================
# Monorail — Test move generator / AI
# Phụ trách: Khiêm
# Giai đoạn 6
#
# Ngoài các assertion thường lệ, file này còn cho AI TỰ CHƠI nhiều ván trọn
# vẹn để bắt ba lỗi mà unit test khó thấy:
#   - AI sinh ra nước đi mà validator từ chối;
#   - AI làm turn flow kẹt (không trả nước nào mà ván chưa kết thúc);
#   - ván chạy mãi không kết thúc.
#
# Cách chạy: mở scenes/TileTestRunner.tscn rồi bấm F6.
# ============================================================================

## Số ván AI tự chơi. Tăng lên nếu muốn soi kỹ, đổi lại chạy lâu hơn —
## mỗi ván tốn khoảng một giây.
const SELF_PLAY_GAMES: int = 10
const MAX_TURNS_PER_GAME: int = 60

var straight: int = MonoTile.TileType.STRAIGHT
var corner: int = MonoTile.TileType.CORNER


func _ready() :
	_begin("MONORAIL — MOVE GENERATOR / AI")

	_test_generator_basics()
	_test_generator_respects_validator()
	_test_generator_max_tiles()
	_test_closing_move()
	_test_no_closing_move_when_impossible()
	_test_track_trace()
	_test_min_tiles_to_close()
	_test_parity_choice()
	_test_ai_declares_only_when_certain()
	_test_ai_takes_the_win()
	_self_play()

	_print_summary()


# ----------------------------------------------------------------------------
# Dựng board
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


## Vòng 10 tile, nhưng thiếu đúng một tile ở (-1,0) để AI khép nốt.
func _make_almost_closed_state() -> GameState:
	var state: GameState = _make_state()
	state.board[Vector2i(2, 0)] = MonoTile.make_tile(corner, 2)
	state.board[Vector2i(2, 1)] = MonoTile.make_tile(straight, 0)
	state.board[Vector2i(2, 2)] = MonoTile.make_tile(corner, 3)
	state.board[Vector2i(1, 2)] = MonoTile.make_tile(straight, 1)
	state.board[Vector2i(0, 2)] = MonoTile.make_tile(straight, 1)
	state.board[Vector2i(-1, 2)] = MonoTile.make_tile(corner, 0)
	state.board[Vector2i(-1, 1)] = MonoTile.make_tile(straight, 0)
	state.remaining_tiles = 24 - 7
	return state


# ----------------------------------------------------------------------------
# MoveGenerator
# ----------------------------------------------------------------------------

func _test_generator_basics() :
	_group("MoveGenerator — sinh nước đi 1 tile")

	var state: GameState = _make_state()
	var moves: Array = MoveGenerator.get_valid_moves(state, 1)

	_assert_false(moves.is_empty(), "board ban đầu có nước đi")
	_assert_eq(moves.size(), 36, "6 ô đặt được x 6 hình dạng tile = 36 nước")

	var all_one_tile: bool = true
	var all_right_player: bool = true
	for move in moves:
		if move["tiles"].size() != 1:
			all_one_tile = false
		if move["player_id"] != state.current_player:
			all_right_player = false
	_assert_true(all_one_tile, "mọi nước đi đều đúng 1 tile")
	_assert_true(all_right_player, "player_id khớp current_player")

	# Không có nước trùng nhau
	var keys: Dictionary = {}
	for move in moves:
		var tile: Dictionary = move["tiles"][0]
		keys["%s|%d|%d" % [str(tile["position"]), tile["type"], tile["rotation"]]] = true
	_assert_eq(keys.size(), moves.size(), "không có nước đi trùng lặp")

	# STRAIGHT chỉ sinh rotation 0 và 1 vì 2, 3 cho ra cùng tập cạnh
	var straight_rotations: Dictionary = {}
	for move in moves:
		var tile: Dictionary = move["tiles"][0]
		if tile["type"] == straight:
			straight_rotations[tile["rotation"]] = true
	_assert_eq(straight_rotations.size(), 2, "STRAIGHT chỉ sinh 2 rotation khác nhau")


func _test_generator_respects_validator() :
	_group("MoveGenerator — mọi nước sinh ra đều qua được validator")

	var state: GameState = _make_state()
	state.board[Vector2i(2, 0)] = MonoTile.make_tile(corner, 2)
	state.board[Vector2i(2, 1)] = MonoTile.make_tile(straight, 0)

	var bad: int = 0
	for move in MoveGenerator.get_valid_moves(state, 2):
		if not MoveValidator.validate_move(state, move)["is_valid"]:
			bad += 1
	_assert_eq(bad, 0, "không nước nào bị validator từ chối")


func _test_generator_max_tiles() :
	_group("MoveGenerator — giới hạn số tile")

	var state: GameState = _make_state()

	var one: Array = MoveGenerator.get_valid_moves(state, 1)
	var two: Array = MoveGenerator.get_valid_moves(state, 2)
	_assert_true(two.size() > one.size(), "cho 2 tile thì sinh ra nhiều nước hơn")

	var max_size: int = 0
	for move in two:
		max_size = maxi(max_size, move["tiles"].size())
	_assert_eq(max_size, 2, "không nước nào quá 2 tile")

	# Không bao giờ sinh nhiều tile hơn số còn lại
	var almost_empty: GameState = _make_state()
	almost_empty.remaining_tiles = 1
	var limited: Array = MoveGenerator.get_valid_moves(almost_empty, 3)
	var over: int = 0
	for move in limited:
		if move["tiles"].size() > 1:
			over += 1
	_assert_eq(over, 0, "còn 1 tile thì chỉ sinh nước 1 tile")

	var no_tiles: GameState = _make_state()
	no_tiles.remaining_tiles = 0
	_assert_true(
		MoveGenerator.get_valid_moves(no_tiles, 3).is_empty(),
		"hết tile thì không sinh nước nào"
	)


func _test_closing_move() :
	_group("MoveGenerator — tìm nước khép vòng")

	var state: GameState = _make_almost_closed_state()
	var closing: Dictionary = MoveGenerator.get_closing_move(state)

	_assert_false(closing.is_empty(), "tìm được nước khép vòng")
	_assert_eq(closing["tiles"].size(), 1, "chỉ cần 1 tile để khép")
	_assert_eq(
		closing["tiles"][0]["position"], Vector2i(-1, 0),
		"đúng ô còn thiếu"
	)

	# Đặt thử vào thì phải thắng thật
	var preview: GameState = _make_almost_closed_state()
	RulesEngine.apply_move(preview, closing)
	var result: Dictionary = WinChecker.check_win(preview, closing)
	_assert_true(result["is_win"], "đặt nước đó vào là thắng")
	_assert_eq(
		result["reason"], WinChecker.REASON_LOOP_COMPLETED,
		"thắng bằng cách khép vòng"
	)


func _test_no_closing_move_when_impossible() :
	_group("MoveGenerator — không bịa ra nước khép vòng")

	_assert_true(
		MoveGenerator.get_closing_move(_make_state()).is_empty(),
		"board ban đầu chưa khép được (cần 8 tile, quá 3)"
	)

	# Hết tile thì không khép được dù chỉ thiếu 1 ô
	var no_tiles: GameState = _make_almost_closed_state()
	no_tiles.remaining_tiles = 0
	_assert_true(
		MoveGenerator.get_closing_move(no_tiles).is_empty(),
		"hết tile thì không có nước khép"
	)


# ----------------------------------------------------------------------------
# WinChecker — trạng thái đoạn ray
# ----------------------------------------------------------------------------

func _test_track_trace() :
	_group("WinChecker — trạng thái đoạn ray từ ga")

	var state: GameState = _make_state()
	var trace: Dictionary = WinChecker.trace_station_track(state.board)
	_assert_eq(trace["status"], WinChecker.TRACK_OPEN, "board ban đầu: ray còn hở")
	_assert_eq(trace["ends"].size(), 2, "có đúng hai đầu hở")

	# Đặt tile dọc cạnh ga: ga mở sang phải nhưng tile này đóng -> chặn vĩnh viễn
	var blocked: GameState = _make_state()
	blocked.board[Vector2i(2, 0)] = MonoTile.make_tile(straight, 0)
	_assert_eq(
		WinChecker.trace_station_track(blocked.board)["status"],
		WinChecker.TRACK_BLOCKED,
		"tile không nối được -> ray bị chặn"
	)

	# Cùng ô đó nhưng đặt corner nối được thì vẫn bình thường
	var fine: GameState = _make_state()
	fine.board[Vector2i(2, 0)] = MonoTile.make_tile(corner, 2)
	_assert_eq(
		WinChecker.trace_station_track(fine.board)["status"],
		WinChecker.TRACK_OPEN,
		"corner nối được -> ray vẫn hở, chưa chặn"
	)

	# Board đã khép vòng
	var closed: GameState = _make_almost_closed_state()
	closed.board[Vector2i(-1, 0)] = MonoTile.make_tile(corner, 1)
	_assert_eq(
		WinChecker.trace_station_track(closed.board)["status"],
		WinChecker.TRACK_CLOSED,
		"đã khép vòng"
	)

	var no_station := GameState.new()
	no_station.board = {}
	_assert_eq(
		WinChecker.trace_station_track(no_station.board)["status"],
		WinChecker.TRACK_NO_STATION,
		"chưa có ga"
	)


func _test_min_tiles_to_close() :
	_group("WinChecker — cận dưới số tile cần để khép vòng")

	_assert_eq(
		WinChecker.min_tiles_to_close(_make_state().board), 4,
		"board ban đầu: cận dưới 4 tile"
	)
	_assert_eq(
		WinChecker.min_tiles_to_close(_make_almost_closed_state().board), 1,
		"thiếu 1 ô: cận dưới 1 tile"
	)

	var blocked: GameState = _make_state()
	blocked.board[Vector2i(2, 0)] = MonoTile.make_tile(straight, 0)
	_assert_eq(
		WinChecker.min_tiles_to_close(blocked.board), -1,
		"ray bị chặn thì không tính được"
	)

	# Cận dưới không bao giờ được lớn hơn số tile thật sự cần.
	# Vòng thật quanh hai ga tốn 8 tile, cận dưới phải nhỏ hơn hoặc bằng.
	_assert_true(
		WinChecker.min_tiles_to_close(_make_state().board) <= 8,
		"cận dưới không vượt quá số tile thật sự cần"
	)


# ----------------------------------------------------------------------------
# AIPlayer
# ----------------------------------------------------------------------------

func _test_parity_choice() :
	_group("AIPlayer — chọn số tile theo parity")

	# Còn 24 tile: đặt 3 để lại 21, mà 21 chia 4 dư 1
	var state: GameState = _make_state()
	var action: Dictionary = AIPlayer.choose_action(state)
	_assert_eq(action["type"], AIPlayer.ACTION_MOVE, "AI trả về một nước đi")
	_assert_eq(
		action["move"]["tiles"].size(), 3,
		"còn 24 tile -> đặt 3, để lại 21 (chia 4 dư 1)"
	)

	# Còn 21 tile: mọi lựa chọn đều xấu, AI không được tự sát bằng cách để lại 0
	var twenty_one: GameState = _make_state()
	twenty_one.remaining_tiles = 21
	var forced: Dictionary = AIPlayer.choose_action(twenty_one)
	_assert_true(
		forced["move"]["tiles"].size() >= 1 and forced["move"]["tiles"].size() <= 3,
		"vẫn đặt 1-3 tile khi không có lựa chọn parity tốt"
	)

	# Còn đúng 2 tile: đặt 1 để đối thủ phải đặt tile cuối
	var two_left: GameState = _make_state()
	two_left.remaining_tiles = 2
	var endgame: Dictionary = AIPlayer.choose_action(two_left)
	_assert_eq(
		endgame["move"]["tiles"].size(), 1,
		"còn 2 tile -> đặt 1, đẩy tile cuối cho đối thủ"
	)


func _test_ai_declares_only_when_certain() :
	_group("AIPlayer — chỉ tuyên bố Impossible khi chắc chắn")

	# Đầu ván thì không có lý do gì để tuyên bố
	var fresh: GameState = _make_state()
	_assert_eq(
		AIPlayer.choose_action(fresh)["type"], AIPlayer.ACTION_MOVE,
		"đầu ván: đặt tile, không tuyên bố"
	)

	# Ray bị chặn vĩnh viễn -> tuyên bố
	var blocked: GameState = _make_state()
	blocked.board[Vector2i(2, 0)] = MonoTile.make_tile(straight, 0)
	var blocked_action: Dictionary = AIPlayer.choose_action(blocked)
	_assert_eq(
		blocked_action["type"], AIPlayer.ACTION_DECLARE_IMPOSSIBLE,
		"ray bị chặn -> tuyên bố Impossible"
	)
	_assert_false(blocked_action["reason"].is_empty(), "có lý do để ghi game log")
	_assert_true(
		blocked_action["move"].is_empty(),
		"tuyên bố thì không kèm nước đi"
	)

	# Không đủ tile để nối hai đầu -> tuyên bố
	var short_on_tiles: GameState = _make_state()
	short_on_tiles.remaining_tiles = 2
	short_on_tiles.board[Vector2i(2, 0)] = MonoTile.make_tile(corner, 2)
	_assert_eq(
		AIPlayer.choose_action(short_on_tiles)["type"],
		AIPlayer.ACTION_DECLARE_IMPOSSIBLE,
		"cần nhiều tile hơn số còn lại -> tuyên bố"
	)

	# Đã có người tuyên bố rồi thì không tuyên bố nữa, phải đi tiếp
	var in_review: GameState = _make_state()
	in_review.board[Vector2i(2, 0)] = MonoTile.make_tile(straight, 0)
	var review_action: Dictionary = AIPlayer.choose_action(
		in_review, AIPlayer.Difficulty.HEURISTIC, 1
	)
	_assert_eq(
		review_action["type"], AIPlayer.ACTION_MOVE,
		"trong giai đoạn quyết định thì chỉ đặt tile"
	)


func _test_ai_takes_the_win() :
	_group("AIPlayer — thấy đường thắng là đi ngay")

	var state: GameState = _make_almost_closed_state()
	var action: Dictionary = AIPlayer.choose_action(state)

	_assert_eq(action["type"], AIPlayer.ACTION_MOVE, "chọn đi chứ không tuyên bố")
	_assert_eq(
		action["move"]["tiles"][0]["position"], Vector2i(-1, 0),
		"đi đúng nước khép vòng, không tham parity"
	)

	# choose_move() là bản rút gọn, phải cho ra cùng kết luận
	var short_form: Dictionary = AIPlayer.choose_move(_make_almost_closed_state())
	_assert_eq(
		short_form["tiles"][0]["position"], Vector2i(-1, 0),
		"choose_move() cũng thấy nước khép vòng"
	)

	# AI random tuy đánh bừa nhưng nước đi phải luôn hợp lệ
	var random_move: Dictionary = AIPlayer.choose_move(
		_make_state(), AIPlayer.Difficulty.RANDOM
	)
	_assert_true(
		MoveValidator.validate_move(_make_state(), random_move)["is_valid"],
		"AI random vẫn sinh nước đi hợp lệ"
	)

	RulesEngine.apply_move(state, action["move"])
	_assert_true(
		WinChecker.check_win(state, action["move"])["is_win"],
		"đi xong là thắng"
	)


# ----------------------------------------------------------------------------
# AI tự chơi trọn ván
# ----------------------------------------------------------------------------

func _self_play() :
	_group("AI tự chơi %d ván trọn vẹn" % SELF_PLAY_GAMES)

	var runner := GameRunner.new()
	runner.max_turns = MAX_TURNS_PER_GAME

	var counts: Dictionary = {}
	var declared: int = 0
	var total_turns: int = 0
	var broken: Array[String] = []

	for game in range(SELF_PLAY_GAMES):
		var result: Dictionary = runner.play(RulesEngine.create_initial_state())
		var reason: String = result["reason"]

		counts[reason] = int(counts.get(reason, 0)) + 1
		total_turns += result["turns"]
		if ImpossibleFlow.is_in_review(result["declared_by"]):
			declared += 1

		if reason in [
			GameRunner.REASON_INVALID_MOVE,
			GameRunner.REASON_NO_MOVE,
			GameRunner.REASON_DECLARE_REJECTED,
			GameRunner.REASON_TOO_MANY_TURNS,
		]:
			broken.append("ván %d dừng bất thường ở lượt %d: %s" % [
				game + 1, result["turns"], reason
			])

	print("  Trung bình %.1f lượt mỗi ván, %d ván có tuyên bố Impossible" % [
		float(total_turns) / float(SELF_PLAY_GAMES), declared
	])
	for reason in counts:
		print("    %-28s %d ván" % [reason, counts[reason]])

	for problem in broken:
		_fail(problem)

	_assert_true(broken.is_empty(), "cả %d ván đều kết thúc bình thường" % SELF_PLAY_GAMES)
	_assert_eq(
		counts.get(GameRunner.REASON_INVALID_MOVE, 0), 0,
		"AI không bao giờ sinh nước đi bị validator từ chối"
	)
	_assert_eq(
		counts.get(GameRunner.REASON_NO_MOVE, 0), 0,
		"AI không làm turn flow bị kẹt"
	)
	_assert_eq(
		counts.get(GameRunner.REASON_TOO_MANY_TURNS, 0), 0,
		"không ván nào chạy mãi không kết thúc"
	)
