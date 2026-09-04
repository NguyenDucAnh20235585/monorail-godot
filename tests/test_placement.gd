extends TestCase

# ============================================================================
# Monorail — Test placement helper / pending move / move validator
# Phụ trách: Khiêm
# Giai đoạn 2
#
# Cách chạy: mở scenes/TileTestRunner.tscn rồi bấm F6.
# ============================================================================

## Viết tắt cho gọn trong test.
var straight: int = MonoTile.TileType.STRAIGHT
var corner: int = MonoTile.TileType.CORNER


func _ready() :
	_begin("MONORAIL — PLACEMENT / PENDING / VALIDATOR")

	_test_initial_state_contract()
	_test_occupancy()
	_test_adjacency()
	_test_preview_state()
	_test_placeable_positions()
	_test_cluster()
	_test_connected_edges()
	_test_pending_add_remove()
	_test_pending_transform()
	_test_pending_move_tile()
	_test_pending_to_move()
	_test_validator_valid_moves()
	_test_validator_invalid_moves()
	_test_validator_does_not_touch_state()

	_print_summary()


# ----------------------------------------------------------------------------
# Dựng state cố định để test không phụ thuộc randi_range()
# ----------------------------------------------------------------------------

func _make_state() -> GameState:
	var state := GameState.new()
	state.board = {
		Vector2i(0, 0): MonoTile.make_tile(straight, 1),
		Vector2i(1, 0): MonoTile.make_tile(straight, 1),
	}
	state.current_player = 0
	state.remaining_tiles = 24
	state.phase = GameState.GamePhase.PLACING
	state.winner = -1
	return state


func _move(player_id: int, entries: Array) -> Dictionary:
	# entries: [[Vector2i, type, rotation], ...]
	var tiles: Array = []
	for e in entries:
		tiles.append({"position": e[0], "type": e[1], "rotation": e[2]})
	return {"player_id": player_id, "tiles": tiles}


func _pending(entries: Array) -> Array:
	var result: Array = []
	for e in entries:
		result.append({"position": e[0], "type": e[1], "rotation": e[2]})
	return result


# ----------------------------------------------------------------------------
# Contract với code của Công
# ----------------------------------------------------------------------------

func _test_initial_state_contract() :
	_group("Contract với RulesEngine.create_initial_state()")

	var state: GameState = RulesEngine.create_initial_state()

	_assert_eq(state.board.size(), 2, "board có đúng 2 tile ga")
	_assert_true(
		state.board.has(RulesEngine.LEFT_START_POS)
			and state.board.has(RulesEngine.RIGHT_START_POS),
		"ga nằm đúng 2 vị trí đã khai báo"
	)
	_assert_eq(state.remaining_tiles, 24, "ga KHÔNG trừ vào remaining_tiles")
	_assert_true(
		state.current_player == 0 or state.current_player == 1,
		"current_player là 0 hoặc 1"
	)
	_assert_eq(state.winner, -1, "chưa có người thắng")
	_assert_eq(state.phase, GameState.GamePhase.PLACING, "phase = PLACING")

	# Tile ga phải đọc được bằng API tile của mình
	var station: Dictionary = state.board[RulesEngine.LEFT_START_POS]
	_assert_true(MonoTile.is_valid_tile(station), "tile ga đúng định dạng TileData")
	_assert_true(
		MonoTile.edges_connect(
			station, RulesEngine.LEFT_START_POS,
			state.board[RulesEngine.RIGHT_START_POS], RulesEngine.RIGHT_START_POS
		),
		"hai tile ga nối ray được với nhau"
	)


# ----------------------------------------------------------------------------
# PlacementHelper
# ----------------------------------------------------------------------------

func _test_occupancy() :
	_group("PlacementHelper — ô trống / ô bị chiếm")

	var board: Dictionary = _make_state().board
	var pending: Array = _pending([[Vector2i(2, 0), straight, 1]])

	_assert_true(PlacementHelper.is_occupied(board, Vector2i(0, 0)), "ô ga bị chiếm")
	_assert_false(PlacementHelper.is_occupied(board, Vector2i(2, 0)), "(2,0) chưa có tile")
	_assert_true(PlacementHelper.is_free(board, [], Vector2i(2, 0)), "(2,0) trống")
	_assert_true(PlacementHelper.is_pending_at(pending, Vector2i(2, 0)), "có pending ở (2,0)")
	_assert_false(
		PlacementHelper.is_free(board, pending, Vector2i(2, 0)),
		"pending cũng chiếm ô"
	)


func _test_adjacency() :
	_group("PlacementHelper — kề board")

	var board: Dictionary = _make_state().board

	_assert_true(PlacementHelper.is_adjacent_to_board(board, Vector2i(2, 0)), "(2,0) kề ga phải")
	_assert_true(PlacementHelper.is_adjacent_to_board(board, Vector2i(-1, 0)), "(-1,0) kề ga trái")
	_assert_true(PlacementHelper.is_adjacent_to_board(board, Vector2i(0, 1)), "(0,1) kề dưới ga")
	_assert_false(PlacementHelper.is_adjacent_to_board(board, Vector2i(3, 0)), "(3,0) cách 1 ô")
	_assert_false(
		PlacementHelper.is_adjacent_to_board(board, Vector2i(2, 1)),
		"(2,1) chỉ chéo với ga -> không kề"
	)


func _test_preview_state() :
	_group("PlacementHelper — ghost preview")

	var board: Dictionary = _make_state().board
	var one: Array = _pending([[Vector2i(2, 0), straight, 1]])
	var three: Array = _pending([
		[Vector2i(2, 0), straight, 1], [Vector2i(3, 0), straight, 1], [Vector2i(4, 0), straight, 1]
	])

	_assert_eq(
		PlacementHelper.get_preview_state(board, [], Vector2i(2, 0)),
		PlacementHelper.PreviewState.VALID, "ô kề board -> VALID"
	)
	_assert_eq(
		PlacementHelper.get_preview_state(board, [], Vector2i(0, 0)),
		PlacementHelper.PreviewState.OCCUPIED, "ô ga -> OCCUPIED"
	)
	_assert_eq(
		PlacementHelper.get_preview_state(board, [], Vector2i(5, 5)),
		PlacementHelper.PreviewState.NOT_ADJACENT, "ô xa board -> NOT_ADJACENT"
	)
	_assert_eq(
		PlacementHelper.get_preview_state(board, one, Vector2i(2, 0)),
		PlacementHelper.PreviewState.PENDING_OCCUPIED, "ô đã có pending -> PENDING_OCCUPIED"
	)
	_assert_eq(
		PlacementHelper.get_preview_state(board, three, Vector2i(5, 0)),
		PlacementHelper.PreviewState.LIMIT_REACHED, "đủ 3 tile -> LIMIT_REACHED"
	)

	# Khi đã có pending, tile tiếp theo phải bám vào CỤM PENDING
	_assert_eq(
		PlacementHelper.get_preview_state(board, one, Vector2i(3, 0)),
		PlacementHelper.PreviewState.VALID, "kề cụm pending -> VALID"
	)
	_assert_eq(
		PlacementHelper.get_preview_state(board, one, Vector2i(0, 1)),
		PlacementHelper.PreviewState.NOT_ADJACENT,
		"kề board nhưng rời cụm pending -> NOT_ADJACENT"
	)

	_assert_true(PlacementHelper.can_place_at(board, [], Vector2i(2, 0)), "can_place_at true")
	_assert_false(PlacementHelper.can_place_at(board, [], Vector2i(0, 0)), "can_place_at false")
	_assert_true(
		PlacementHelper.describe_preview_state(PlacementHelper.PreviewState.VALID).is_empty(),
		"VALID không có thông báo lỗi"
	)
	_assert_false(
		PlacementHelper.describe_preview_state(
			PlacementHelper.PreviewState.OCCUPIED
		).is_empty(),
		"OCCUPIED có thông báo cho UI"
	)


func _test_placeable_positions() :
	_group("PlacementHelper — danh sách ô đặt được")

	var board: Dictionary = _make_state().board
	var positions: Array[Vector2i] = PlacementHelper.get_placeable_positions(board, [])

	_assert_eq(positions.size(), 6, "quanh 2 ga có đúng 6 ô đặt được")

	var expected: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1),
	]
	var all_found: bool = true
	for position in expected:
		if not positions.has(position):
			all_found = false
	_assert_true(all_found, "đủ 6 ô trên/dưới/hai đầu ga")
	_assert_true(positions == expected, "kết quả được sắp xếp ổn định")

	var three: Array = _pending([
		[Vector2i(2, 0), straight, 1], [Vector2i(3, 0), straight, 1], [Vector2i(4, 0), straight, 1]
	])
	_assert_true(
		PlacementHelper.get_placeable_positions(board, three).is_empty(),
		"đủ 3 pending -> không còn ô nào đặt được"
	)


func _test_cluster() :
	_group("PlacementHelper — cụm tile")

	_assert_true(PlacementHelper.is_cluster_contiguous([]), "cụm rỗng")
	_assert_true(PlacementHelper.is_cluster_contiguous([Vector2i(0, 0)]), "cụm 1 ô")
	_assert_true(
		PlacementHelper.is_cluster_contiguous([Vector2i(2, 0), Vector2i(3, 0)]),
		"2 ô ngang liền nhau"
	)
	_assert_true(
		PlacementHelper.is_cluster_contiguous([Vector2i(2, 0), Vector2i(2, 1)]),
		"2 ô dọc liền nhau"
	)
	_assert_false(
		PlacementHelper.is_cluster_contiguous([Vector2i(2, 0), Vector2i(4, 0)]),
		"2 ô cách nhau"
	)
	_assert_false(
		PlacementHelper.is_cluster_contiguous([Vector2i(2, 0), Vector2i(3, 1)]),
		"2 ô chéo nhau không tính liền"
	)
	_assert_true(
		PlacementHelper.is_cluster_contiguous([
			Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)
		]),
		"hình L vẫn là cụm liền"
	)
	_assert_false(
		PlacementHelper.is_cluster_contiguous([Vector2i(2, 0), Vector2i(2, 0)]),
		"trùng ô -> không hợp lệ"
	)

	# Luật thẳng hàng: hàm đã có nhưng CHƯA bật trong validator
	_assert_true(
		PlacementHelper.is_cluster_aligned([
			Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)
		]),
		"3 ô cùng hàng -> thẳng hàng"
	)
	_assert_true(
		PlacementHelper.is_cluster_aligned([Vector2i(2, 0), Vector2i(2, 1)]),
		"2 ô cùng cột -> thẳng hàng"
	)
	_assert_false(
		PlacementHelper.is_cluster_aligned([
			Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1)
		]),
		"hình L -> không thẳng hàng"
	)

	var board: Dictionary = _make_state().board
	_assert_true(
		PlacementHelper.cluster_touches_board(board, [Vector2i(2, 0), Vector2i(3, 0)]),
		"cụm có 1 ô chạm board là đủ"
	)
	_assert_false(
		PlacementHelper.cluster_touches_board(board, [Vector2i(4, 0), Vector2i(5, 0)]),
		"cụm rời hẳn board"
	)


func _test_connected_edges() :
	_group("PlacementHelper — nối ray với board")

	var board: Dictionary = _make_state().board

	var connected: Array[String] = PlacementHelper.get_connected_edges(
		board, Vector2i(2, 0), MonoTile.make_tile(straight, 1)
	)
	_assert_eq(connected.size(), 1, "tile ngang ở (2,0) nối được 1 cạnh")
	_assert_eq(connected[0], "left", "cạnh nối là bên trái, về phía ga")
	_assert_eq(
		PlacementHelper.count_connections(board, Vector2i(2, 0), MonoTile.make_tile(straight, 0)),
		0,
		"tile dọc ở (2,0) không nối được"
	)
	_assert_eq(
		PlacementHelper.count_connections(board, Vector2i(0, 1), MonoTile.make_tile(straight, 0)),
		0,
		"ga nằm ngang nên không mở xuống dưới"
	)


# ----------------------------------------------------------------------------
# PendingMove
# ----------------------------------------------------------------------------

func _test_pending_add_remove() :
	_group("PendingMove — thêm / xóa / giới hạn 3")

	var pending := PendingMove.new(0)
	_assert_true(pending.is_empty(), "khởi tạo rỗng")
	_assert_eq(pending.player_id, 0, "nhớ player_id")

	_assert_true(pending.add_tile(Vector2i(2, 0), straight, 1), "thêm tile 1")
	_assert_true(pending.add_tile(Vector2i(3, 0), corner, 0), "thêm tile 2")
	_assert_true(pending.add_tile(Vector2i(4, 0), straight, 0), "thêm tile 3")
	_assert_eq(pending.size(), 3, "có 3 tile")
	_assert_true(pending.is_full(), "đã đầy")
	_assert_false(pending.can_add(), "không thêm được nữa")
	_assert_false(pending.add_tile(Vector2i(5, 0), straight, 0), "tile thứ 4 bị chặn")
	_assert_eq(pending.size(), 3, "vẫn là 3 tile")

	_assert_false(pending.add_tile(Vector2i(2, 0), corner, 0), "không thêm trùng ô")

	_assert_true(pending.has_tile_at(Vector2i(3, 0)), "có tile ở (3,0)")
	_assert_eq(pending.get_tile_at(Vector2i(3, 0))["type"], corner, "đọc đúng type")
	_assert_true(pending.get_tile_at(Vector2i(9, 9)).is_empty(), "ô không có -> dict rỗng")

	# get_tile_at trả bản sao, sửa bên ngoài không ảnh hưởng bên trong
	var copy: Dictionary = pending.get_tile_at(Vector2i(3, 0))
	copy["rotation"] = 3
	_assert_eq(pending.get_tile_at(Vector2i(3, 0))["rotation"], 0, "get_tile_at trả bản sao")

	# get_tiles() là dữ liệu Công truyền thẳng vào PlacementHelper
	var snapshot: Array = pending.get_tiles()
	_assert_eq(snapshot.size(), 3, "get_tiles trả đủ 3 tile")

	var first_position: Vector2i = snapshot[0]["position"]
	var rotation_before: int = pending.get_tile_at(first_position)["rotation"]
	snapshot[0]["rotation"] = MonoTile.normalize_rotation(rotation_before + 1)
	_assert_eq(
		pending.get_tile_at(first_position)["rotation"], rotation_before,
		"get_tiles trả bản sao, sửa bên ngoài không ảnh hưởng pending"
	)

	_assert_true(pending.remove_at(Vector2i(3, 0)), "xóa được")
	_assert_eq(pending.size(), 2, "còn 2 tile")
	_assert_false(pending.remove_at(Vector2i(3, 0)), "xóa ô trống -> false")

	pending.clear()
	_assert_true(pending.is_empty(), "clear xóa hết")


func _test_pending_transform() :
	_group("PendingMove — xoay / lật")

	var pending := PendingMove.new(0)
	pending.add_tile(Vector2i(2, 0), straight, 0)

	_assert_true(pending.rotate_at(Vector2i(2, 0)), "xoay được")
	_assert_eq(pending.get_tile_at(Vector2i(2, 0))["rotation"], 1, "rotation = 1")

	pending.rotate_at(Vector2i(2, 0))
	pending.rotate_at(Vector2i(2, 0))
	pending.rotate_at(Vector2i(2, 0))
	_assert_eq(
		pending.get_tile_at(Vector2i(2, 0))["rotation"], 0,
		"xoay 4 lần về rotation 0"
	)

	pending.rotate_at(Vector2i(2, 0))
	pending.rotate_at(Vector2i(2, 0))
	pending.rotate_at(Vector2i(2, 0))
	_assert_eq(
		pending.get_tile_at(Vector2i(2, 0))["rotation"], 3,
		"xoay tiếp 3 lần -> rotation 3"
	)

	_assert_true(pending.flip_at(Vector2i(2, 0)), "lật được")
	_assert_eq(pending.get_tile_at(Vector2i(2, 0))["type"], corner, "STRAIGHT -> CORNER")
	_assert_eq(pending.get_tile_at(Vector2i(2, 0))["rotation"], 3, "lật giữ nguyên rotation")
	pending.flip_at(Vector2i(2, 0))
	_assert_eq(pending.get_tile_at(Vector2i(2, 0))["type"], straight, "lật lại về STRAIGHT")

	_assert_false(pending.rotate_at(Vector2i(9, 9)), "xoay ô trống -> false")
	_assert_false(pending.flip_at(Vector2i(9, 9)), "lật ô trống -> false")


func _test_pending_move_tile() :
	_group("PendingMove — di chuyển tile")

	var pending := PendingMove.new(0)
	pending.add_tile(Vector2i(2, 0), corner, 2)
	pending.add_tile(Vector2i(3, 0), straight, 0)

	_assert_true(pending.move_tile(Vector2i(2, 0), Vector2i(2, 1)), "chuyển sang ô trống")
	_assert_false(pending.has_tile_at(Vector2i(2, 0)), "ô cũ đã trống")
	_assert_eq(pending.get_tile_at(Vector2i(2, 1))["type"], corner, "giữ nguyên type")
	_assert_eq(pending.get_tile_at(Vector2i(2, 1))["rotation"], 2, "giữ nguyên rotation")

	_assert_false(
		pending.move_tile(Vector2i(2, 1), Vector2i(3, 0)),
		"không chuyển đè lên pending khác"
	)
	_assert_false(pending.move_tile(Vector2i(9, 9), Vector2i(5, 5)), "ô nguồn trống -> false")
	_assert_false(pending.move_tile(Vector2i(2, 1), Vector2i(2, 1)), "chuyển vào chính nó -> false")


func _test_pending_to_move() :
	_group("PendingMove — xuất ra Move")

	var pending := PendingMove.new(1)
	pending.add_tile(Vector2i(2, 0), straight, 1)
	pending.add_tile(Vector2i(3, 0), corner, 2)

	var move: Dictionary = pending.to_move()
	_assert_eq(move["player_id"], 1, "player_id đúng")
	_assert_eq(move["tiles"].size(), 2, "2 tile trong move")
	_assert_true(
		move["tiles"][0].has("position")
			and move["tiles"][0].has("type")
			and move["tiles"][0].has("rotation"),
		"tile trong move đủ 3 khóa"
	)

	# Move là dữ liệu tách rời — sửa Move không ảnh hưởng pending
	move["tiles"][0]["rotation"] = 3
	_assert_eq(
		pending.get_tile_at(Vector2i(2, 0))["rotation"], 1,
		"sửa Move không ảnh hưởng pending move"
	)

	var rebuilt: PendingMove = PendingMove.from_move(pending.to_move())
	_assert_eq(rebuilt.size(), 2, "from_move dựng lại đủ tile")
	_assert_eq(rebuilt.player_id, 1, "from_move giữ player_id")

	pending.reset_for_player(0)
	_assert_true(pending.is_empty(), "reset_for_player xóa hết tile")
	_assert_eq(pending.player_id, 0, "reset_for_player đổi player")


# ----------------------------------------------------------------------------
# MoveValidator
# ----------------------------------------------------------------------------

func _test_validator_valid_moves() :
	_group("MoveValidator — nước đi hợp lệ")

	var state: GameState = _make_state()

	_assert_valid(state, _move(0, [[Vector2i(2, 0), straight, 1]]), "1 tile kề ga")
	_assert_valid(state, _move(0, [[Vector2i(-1, 0), corner, 0]]), "1 tile phía trái ga")
	_assert_valid(state, _move(0, [[Vector2i(0, 1), straight, 0]]), "1 tile dưới ga")
	_assert_valid(
		state, _move(0, [[Vector2i(2, 0), straight, 1], [Vector2i(3, 0), corner, 2]]),
		"2 tile liền nhau"
	)
	_assert_valid(
		state,
		_move(0, [
			[Vector2i(2, 0), straight, 1],
			[Vector2i(3, 0), straight, 1],
			[Vector2i(4, 0), straight, 1],
		]),
		"3 tile thẳng hàng"
	)
	_assert_valid(
		state,
		_move(0, [
			[Vector2i(2, 0), straight, 1],
			[Vector2i(2, 1), straight, 0],
			[Vector2i(3, 1), straight, 0],
		]),
		"3 tile hình L (luật thẳng hàng CHƯA bật)"
	)

	# Ray không cần nối ngay khi đặt (Rules mục 7)
	_assert_valid(
		state, _move(0, [[Vector2i(2, 0), straight, 0]]),
		"tile dọc cạnh ga ngang: không nối ray nhưng vẫn hợp lệ"
	)

	var state_one_left: GameState = _make_state()
	state_one_left.remaining_tiles = 1
	_assert_valid(
		state_one_left, _move(0, [[Vector2i(2, 0), straight, 1]]),
		"còn 1 tile, đặt 1 tile"
	)


func _test_validator_invalid_moves() :
	_group("MoveValidator — nước đi không hợp lệ")

	var state: GameState = _make_state()

	_assert_error(
		state, _move(1, [[Vector2i(2, 0), straight, 1]]),
		MoveValidator.WRONG_PLAYER, "sai lượt"
	)
	_assert_error(
		state, _move(0, []),
		MoveValidator.INVALID_TILE_COUNT, "0 tile"
	)
	_assert_error(
		state,
		_move(0, [
			[Vector2i(2, 0), straight, 1], [Vector2i(3, 0), straight, 1],
			[Vector2i(4, 0), straight, 1], [Vector2i(5, 0), straight, 1]
		]),
		MoveValidator.INVALID_TILE_COUNT, "4 tile"
	)
	_assert_error(
		state, _move(0, [[Vector2i(0, 0), straight, 1]]),
		MoveValidator.CELL_OCCUPIED, "đặt đè lên ga"
	)
	_assert_error(
		state, _move(0, [[Vector2i(2, 0), straight, 1], [Vector2i(2, 0), corner, 0]]),
		MoveValidator.DUPLICATE_POSITION, "2 tile cùng một ô"
	)
	_assert_error(
		state, _move(0, [[Vector2i(5, 5), straight, 1]]),
		MoveValidator.NOT_TOUCHING_BOARD, "tile không chạm board"
	)
	_assert_error(
		state, _move(0, [[Vector2i(2, 0), straight, 1], [Vector2i(4, 0), straight, 1]]),
		MoveValidator.TILES_NOT_ADJACENT, "2 tile rời nhau"
	)
	_assert_error(
		state, _move(0, [[Vector2i(2, 0), straight, 1], [Vector2i(3, 1), straight, 1]]),
		MoveValidator.TILES_NOT_ADJACENT, "2 tile chỉ chéo nhau"
	)
	_assert_error(
		state, _move(0, [[Vector2i(2, 0), straight, 9]]),
		MoveValidator.INVALID_TILE_DATA, "rotation ngoài khoảng"
	)
	_assert_error(
		state, _move(0, [[Vector2i(2, 0), 7, 0]]),
		MoveValidator.INVALID_TILE_DATA, "type không tồn tại"
	)

	var finished: GameState = _make_state()
	finished.phase = GameState.GamePhase.GAME_FINISHED
	_assert_error(
		finished, _move(0, [[Vector2i(2, 0), straight, 1]]),
		MoveValidator.GAME_FINISHED, "game đã kết thúc"
	)

	var almost_empty: GameState = _make_state()
	almost_empty.remaining_tiles = 1
	_assert_error(
		almost_empty, _move(0, [[Vector2i(2, 0), straight, 1], [Vector2i(3, 0), straight, 1]]),
		MoveValidator.NOT_ENOUGH_TILES, "đặt 2 tile khi chỉ còn 1"
	)

	# invalid_positions phải chỉ đúng ô sai để UI highlight
	var result: Dictionary = MoveValidator.validate_move(
		state, _move(0, [[Vector2i(0, 0), straight, 1]])
	)
	var invalid: Array = result["invalid_positions"]
	_assert_eq(invalid.size(), 1, "invalid_positions có đúng 1 ô")
	_assert_eq(invalid[0], Vector2i(0, 0), "invalid_positions chỉ đúng ô bị đè")
	_assert_false(result["message"].is_empty(), "có message tiếng Việt cho UI")


func _test_validator_does_not_touch_state() :
	_group("MoveValidator — chỉ đọc, không sửa state")

	var state: GameState = _make_state()
	var board_before: int = state.board.size()
	var tiles_before: int = state.remaining_tiles
	var player_before: int = state.current_player

	MoveValidator.validate_move(state, _move(0, [[Vector2i(2, 0), straight, 1]]))
	MoveValidator.validate_move(state, _move(0, [[Vector2i(5, 5), straight, 1]]))

	_assert_eq(state.board.size(), board_before, "board không đổi")
	_assert_eq(state.remaining_tiles, tiles_before, "remaining_tiles không đổi")
	_assert_eq(state.current_player, player_before, "current_player không đổi")


# ----------------------------------------------------------------------------
# Hạ tầng riêng của nhóm test này
# (phần đếm PASS/FAIL nằm ở tests/test_case.gd)
# ----------------------------------------------------------------------------

func _assert_valid(state: GameState, move: Dictionary, label: String) :
	var result: Dictionary = MoveValidator.validate_move(state, move)
	if result["is_valid"]:
		_pass(label)
	else:
		_fail("%s (bị chặn bởi %s: %s)" % [label, result["error_code"], result["message"]])


func _assert_error(
	state: GameState, move: Dictionary, expected_code: String, label: String
) :
	var result: Dictionary = MoveValidator.validate_move(state, move)
	if not result["is_valid"] and result["error_code"] == expected_code:
		_pass("%s -> %s" % [label, expected_code])
	else:
		_fail("%s (mong đợi %s, nhận %s)" % [label, expected_code, result["error_code"]])
