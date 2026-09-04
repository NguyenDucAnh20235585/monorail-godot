extends Node

# ============================================================================
# Monorail — AI Arena
# Phụ trách: Khiêm
#
# ĐÂY LÀ CÔNG CỤ XEM, KHÔNG PHẢI TEST. Nó không assert gì cả, chỉ cho AI đánh
# rồi in ra để người đọc tự đánh giá. Chạy riêng, không nằm trong TileTestRunner
# để bộ test thường vẫn nhanh.
#
# Cách chạy: mở scenes/AIArena.tscn rồi bấm F6, xem panel Output.
#
# Hai phần:
#   1. Một ván đánh chậm, in bàn cờ sau MỖI lượt để nhìn đường ray mọc dần.
#   2. Thống kê đối đầu giữa các mức khó, mỗi cặp nhiều ván.
#
# Vòng lặp ván đấu nằm ở tests/game_runner.gd, dùng chung với test_ai.gd.
#
# Bàn cờ vẽ bằng ký tự, suy thẳng từ get_edges() nên nhìn hình là biết tile
# logic đúng hay sai:
#
#     ═ ║   tile ga
#     ─ │   tile thẳng
#     └ ┌ ┐ ┘   tile góc
#     ·     ô trống
# ============================================================================

## Số ván cho mỗi cặp đối đầu ở phần thống kê.
const GAMES_PER_MATCHUP: int = 10

## Ký tự cho từng cặp cạnh mở, khóa là tên hai cạnh đã sắp xếp.
const GLYPHS: Dictionary = {
	"bottom,top": "│",
	"left,right": "─",
	"right,top": "└",
	"bottom,right": "┌",
	"bottom,left": "┐",
	"left,top": "┘",
}
const STATION_GLYPHS: Dictionary = {
	"bottom,top": "║",
	"left,right": "═",
}

## State của ván đang xem, để hàm in bàn cờ đọc được từ signal.
var _watched: GameState


func _ready() :
	print("\n#########################################")
	print("  MONORAIL — AI ARENA")
	print("#########################################")

	_show_one_game()
	_run_matchups()

	print("\n#########################################")
	print("  HẾT")
	print("#########################################")


# ----------------------------------------------------------------------------
# 1. Xem một ván đánh từng lượt
# ----------------------------------------------------------------------------

func _show_one_game() :
	print("\n\n=========================================")
	print("  MỘT VÁN AI vs AI, IN TỪNG LƯỢT")
	print("=========================================")

	_watched = RulesEngine.create_initial_state()
	_watched.current_player = 0

	print("\nBàn cờ ban đầu — hai tile ga:")
	_print_board(_watched.board)

	var runner := GameRunner.new()
	runner.verbose = true
	runner.action_chosen.connect(_on_action_chosen)
	runner.move_applied.connect(_on_move_applied)
	runner.impossible_declared.connect(_on_impossible_declared)

	var result: Dictionary = runner.play(_watched)

	if result["reason"] == WinChecker.REASON_LOOP_COMPLETED:
		print("\n  Vòng đã khép:")
		_print_board(_watched.board, WinChecker.find_station_loop(_watched.board))

	print("\n=========================================")
	if result["winner"] < 0:
		print("  VÁN DỪNG BẤT THƯỜNG: %s" % result["reason"])
	else:
		print("  KẾT THÚC Ở LƯỢT %d — NGƯỜI CHƠI %d THẮNG" % [
			result["turns"], result["winner"] + 1
		])
		print("  Lý do: %s" % result["reason"])
	print("=========================================")


func _on_action_chosen(turn: int, player: int, action: Dictionary) :
	print("\n--- Lượt %d — Người chơi %d ---" % [turn, player + 1])
	print("  %s" % action["reason"])


func _on_impossible_declared(_turn: int, _player: int, declaration: Dictionary) :
	print("  -> Người chơi %d phải dùng %d tile còn lại để hoàn thành." % [
		declaration["challenger"] + 1, _watched.remaining_tiles
	])


func _on_move_applied(_turn: int, _player: int, move: Dictionary) :
	print("  Đặt %d tile: %s" % [move["tiles"].size(), _describe_tiles(move["tiles"])])
	_print_board(_watched.board, _positions_of(move))
	print("  Còn %d tile | trạng thái ray: %s | cần ít nhất %d tile nữa" % [
		_watched.remaining_tiles,
		WinChecker.trace_station_track(_watched.board)["status"],
		WinChecker.min_tiles_to_close(_watched.board),
	])


# ----------------------------------------------------------------------------
# 2. Thống kê đối đầu
# ----------------------------------------------------------------------------

func _run_matchups() :
	print("\n\n=========================================")
	print("  THỐNG KÊ ĐỐI ĐẦU (%d ván mỗi cặp)" % GAMES_PER_MATCHUP)
	print("=========================================")

	_matchup("Heuristic vs Random", AIPlayer.Difficulty.HEURISTIC, AIPlayer.Difficulty.RANDOM)
	_matchup(
		"Heuristic vs Heuristic",
		AIPlayer.Difficulty.HEURISTIC, AIPlayer.Difficulty.HEURISTIC
	)
	_matchup("Random vs Random", AIPlayer.Difficulty.RANDOM, AIPlayer.Difficulty.RANDOM)


func _matchup(label: String, first: AIPlayer.Difficulty, second: AIPlayer.Difficulty) :
	var runner := GameRunner.new()
	runner.difficulties = {0: first, 1: second}

	var wins: Array[int] = [0, 0]
	var reasons: Dictionary = {}
	var total_turns: int = 0
	var unfinished: int = 0

	for game in range(GAMES_PER_MATCHUP):
		var state: GameState = RulesEngine.create_initial_state()
		# Đổi lượt đi đầu giữa các ván cho công bằng.
		state.current_player = game % 2

		var result: Dictionary = runner.play(state)
		if result["winner"] < 0:
			unfinished += 1
		else:
			wins[result["winner"]] += 1
		reasons[result["reason"]] = int(reasons.get(result["reason"], 0)) + 1
		total_turns += result["turns"]

	print("\n%s" % label)
	print("  Tỉ số: Người chơi 1 thắng %d — Người chơi 2 thắng %d" % [wins[0], wins[1]])
	print("  Trung bình %.1f lượt mỗi ván" % (float(total_turns) / float(GAMES_PER_MATCHUP)))
	for reason in reasons:
		print("    %-28s %d ván" % [reason, reasons[reason]])
	if unfinished > 0:
		print("  CẢNH BÁO: %d ván không kết thúc bình thường" % unfinished)


# ----------------------------------------------------------------------------
# 3. Vẽ bàn cờ bằng ký tự
# ----------------------------------------------------------------------------

## Ký tự suy thẳng từ get_edges(), không hardcode theo rotation, nên nếu tile
## logic sai thì hình vẽ ra cũng sai theo.
func _tile_glyph(tile: Dictionary, is_station: bool) -> String:
	var open_edges: Array[String] = MonoTile.get_open_edges(
		tile["type"], tile["rotation"]
	)
	open_edges.sort()
	var key: String = ",".join(open_edges)

	if is_station and STATION_GLYPHS.has(key):
		return STATION_GLYPHS[key]
	return GLYPHS.get(key, "?")


func _print_board(board: Dictionary, highlight: Array = []) :
	if board.is_empty():
		print("  (bàn cờ trống)")
		return

	var min_x: int = 1 << 30
	var max_x: int = -(1 << 30)
	var min_y: int = 1 << 30
	var max_y: int = -(1 << 30)
	for position in board.keys():
		min_x = mini(min_x, position.x)
		max_x = maxi(max_x, position.x)
		min_y = mini(min_y, position.y)
		max_y = maxi(max_y, position.y)

	var stations: Array[Vector2i] = WinChecker.get_station_positions()

	for y in range(min_y - 1, max_y + 2):
		var line: String = "    "
		for x in range(min_x - 1, max_x + 2):
			var position := Vector2i(x, y)
			if not board.has(position):
				line += " · "
				continue
			var glyph: String = _tile_glyph(board[position], stations.has(position))
			# Tile vừa đặt hoặc thuộc vòng thắng thì kẹp trong ngoặc cho dễ thấy.
			if highlight.has(position):
				line += "[%s]" % glyph
			else:
				line += " %s " % glyph
		print(line)


func _positions_of(move: Dictionary) -> Array:
	var result: Array = []
	for tile in move["tiles"]:
		result.append(tile["position"])
	return result


func _describe_tiles(tiles: Array) -> String:
	var parts: Array = []
	for tile in tiles:
		var type_name: String = (
			"thẳng" if tile["type"] == MonoTile.TileType.STRAIGHT else "góc"
		)
		parts.append("%s %s xoay %d" % [str(tile["position"]), type_name, tile["rotation"]])
	return ", ".join(parts)
