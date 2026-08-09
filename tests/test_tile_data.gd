extends Node

# ============================================================================
# Monorail — Test tile logic
# Phụ trách: Khiêm
#
# Cách chạy:
#   Mở project trong Godot, bấm F5 (scene chính là TileTestRunner.tscn).
#   Kết quả PASS/FAIL in ra Output panel.
#
# Không cần cài addon nào. Không đụng tới GameState hay UI.
# ============================================================================

var _passed: int = 0
var _failed: int = 0
var _current_group: String = ""


func _ready() -> void:
	print("=========================================")
	print("  MONORAIL — TILE LOGIC TEST")
	print("=========================================")

	_test_straight_edges()
	_test_corner_edges()
	_test_rotation_normalize()
	_test_rotate_returns_new_tile()
	_test_rotate_four_times_returns_to_origin()
	_test_flip()
	_test_flip_twice_returns_to_origin()
	_test_edge_count_always_two()
	_test_adjacency()
	_test_edges_connect()
	_test_canonical_rotation()
	_test_serialize()
	_test_is_valid_tile()

	_print_summary()


# ----------------------------------------------------------------------------
# Test: STRAIGHT
# ----------------------------------------------------------------------------

func _test_straight_edges() -> void:
	_group("STRAIGHT — đủ 4 rotation")

	# rotation 0 và 2: dọc (top + bottom)
	_check_edges(MonoTile.TileType.STRAIGHT, 0, ["top", "bottom"])
	_check_edges(MonoTile.TileType.STRAIGHT, 2, ["top", "bottom"])

	# rotation 1 và 3: ngang (right + left)
	_check_edges(MonoTile.TileType.STRAIGHT, 1, ["right", "left"])
	_check_edges(MonoTile.TileType.STRAIGHT, 3, ["right", "left"])


# ----------------------------------------------------------------------------
# Test: CORNER
# ----------------------------------------------------------------------------

func _test_corner_edges() -> void:
	_group("CORNER — đủ 4 rotation")

	# rotation 0: lên-phải
	_check_edges(MonoTile.TileType.CORNER, 0, ["top", "right"])
	# rotation 1: phải-xuống
	_check_edges(MonoTile.TileType.CORNER, 1, ["right", "bottom"])
	# rotation 2: xuống-trái
	_check_edges(MonoTile.TileType.CORNER, 2, ["bottom", "left"])
	# rotation 3: trái-lên
	_check_edges(MonoTile.TileType.CORNER, 3, ["left", "top"])


# ----------------------------------------------------------------------------
# Test: rotation
# ----------------------------------------------------------------------------

func _test_rotation_normalize() -> void:
	_group("normalize_rotation")

	_assert_eq(MonoTile.normalize_rotation(0), 0, "0 -> 0")
	_assert_eq(MonoTile.normalize_rotation(3), 3, "3 -> 3")
	_assert_eq(MonoTile.normalize_rotation(4), 0, "4 -> 0")
	_assert_eq(MonoTile.normalize_rotation(7), 3, "7 -> 3")
	_assert_eq(MonoTile.normalize_rotation(-1), 3, "-1 -> 3 (không âm)")
	_assert_eq(MonoTile.normalize_rotation(-5), 3, "-5 -> 3")

	# get_edges cũng phải chịu được rotation ngoài khoảng
	var a: Dictionary = MonoTile.get_edges(MonoTile.TileType.CORNER, 5)
	var b: Dictionary = MonoTile.get_edges(MonoTile.TileType.CORNER, 1)
	_assert_true(a == b, "get_edges(CORNER, 5) == get_edges(CORNER, 1)")


func _test_rotate_returns_new_tile() -> void:
	_group("rotate_tile không sửa tile gốc")

	var original: Dictionary = MonoTile.make_tile(MonoTile.TileType.CORNER, 0)
	var rotated: Dictionary = MonoTile.rotate_tile(original)

	_assert_eq(original["rotation"], 0, "tile gốc giữ nguyên rotation 0")
	_assert_eq(rotated["rotation"], 1, "tile mới có rotation 1")


func _test_rotate_four_times_returns_to_origin() -> void:
	_group("Xoay 4 lần quay về trạng thái ban đầu")

	for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
		for start_rot in range(MonoTile.ROTATION_COUNT):
			var tile: Dictionary = MonoTile.make_tile(type, start_rot)
			var moved: Dictionary = tile
			for _i in range(4):
				moved = MonoTile.rotate_tile(moved)
			_assert_true(
				moved == tile,
				"%s rot %d: xoay CW 4 lần == ban đầu" % [_type_name(type), start_rot]
			)

			# xoay CW rồi CCW cũng phải về chỗ cũ
			var round_trip: Dictionary = MonoTile.rotate_tile_ccw(MonoTile.rotate_tile(tile))
			_assert_true(
				round_trip == tile,
				"%s rot %d: CW rồi CCW == ban đầu" % [_type_name(type), start_rot]
			)


# ----------------------------------------------------------------------------
# Test: flip
# ----------------------------------------------------------------------------

func _test_flip() -> void:
	_group("flip_tile đổi mặt, giữ rotation")

	var straight: Dictionary = MonoTile.make_tile(MonoTile.TileType.STRAIGHT, 2)
	var flipped: Dictionary = MonoTile.flip_tile(straight)

	_assert_eq(flipped["type"], MonoTile.TileType.CORNER, "STRAIGHT -> CORNER")
	_assert_eq(flipped["rotation"], 2, "rotation giữ nguyên = 2")
	_assert_eq(straight["type"], MonoTile.TileType.STRAIGHT, "tile gốc không bị sửa")

	var back: Dictionary = MonoTile.flip_tile(flipped)
	_assert_eq(back["type"], MonoTile.TileType.STRAIGHT, "CORNER -> STRAIGHT")


func _test_flip_twice_returns_to_origin() -> void:
	_group("Lật 2 lần quay về ban đầu")

	for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
		for rot in range(MonoTile.ROTATION_COUNT):
			var tile: Dictionary = MonoTile.make_tile(type, rot)
			var twice: Dictionary = MonoTile.flip_tile(MonoTile.flip_tile(tile))
			_assert_true(
				twice == tile,
				"%s rot %d: lật 2 lần == ban đầu" % [_type_name(type), rot]
			)


# ----------------------------------------------------------------------------
# Test: bất biến chung
# ----------------------------------------------------------------------------

func _test_edge_count_always_two() -> void:
	_group("Mọi tile luôn có đúng 2 cạnh mở")

	for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
		for rot in range(MonoTile.ROTATION_COUNT):
			var open_edges: Array[String] = MonoTile.get_open_edges(type, rot)
			_assert_eq(
				open_edges.size(), 2,
				"%s rot %d có 2 cạnh mở" % [_type_name(type), rot]
			)

			# và kết quả get_edges luôn đủ 4 khóa
			var edges: Dictionary = MonoTile.get_edges(type, rot)
			_assert_eq(
				edges.size(), 4,
				"%s rot %d: get_edges trả đủ 4 khóa" % [_type_name(type), rot]
			)


# ----------------------------------------------------------------------------
# Test: kề cạnh
# ----------------------------------------------------------------------------

func _test_adjacency() -> void:
	_group("Kề cạnh (không tính chéo)")

	var center := Vector2i(3, 4)

	_assert_true(MonoTile.are_adjacent(center, Vector2i(3, 3)), "kề ô phía trên")
	_assert_true(MonoTile.are_adjacent(center, Vector2i(4, 4)), "kề ô bên phải")
	_assert_true(MonoTile.are_adjacent(center, Vector2i(3, 5)), "kề ô phía dưới")
	_assert_true(MonoTile.are_adjacent(center, Vector2i(2, 4)), "kề ô bên trái")

	_assert_false(MonoTile.are_adjacent(center, Vector2i(4, 5)), "chéo KHÔNG tính là kề")
	_assert_false(MonoTile.are_adjacent(center, Vector2i(3, 6)), "cách 2 ô không kề")
	_assert_false(MonoTile.are_adjacent(center, center), "chính nó không kề chính nó")

	_assert_eq(MonoTile.get_edge_between(center, Vector2i(3, 3)), "top", "hướng lên = top")
	_assert_eq(MonoTile.get_edge_between(center, Vector2i(3, 5)), "bottom", "hướng xuống = bottom")
	_assert_eq(MonoTile.get_neighbor_positions(center).size(), 4, "có đúng 4 ô kề")


# ----------------------------------------------------------------------------
# Test: nối đường ray
# ----------------------------------------------------------------------------

func _test_edges_connect() -> void:
	_group("Nối đường ray giữa 2 tile kề nhau")

	var pos_left := Vector2i(0, 0)
	var pos_right := Vector2i(1, 0)

	# Hai tile ngang cạnh nhau: cả hai đều mở left/right -> nối được
	var h1: Dictionary = MonoTile.make_tile(MonoTile.TileType.STRAIGHT, 1)
	var h2: Dictionary = MonoTile.make_tile(MonoTile.TileType.STRAIGHT, 1)
	_assert_true(
		MonoTile.edges_connect(h1, pos_left, h2, pos_right),
		"2 STRAIGHT ngang cạnh nhau -> nối"
	)

	# Tile trái ngang, tile phải dọc -> tile phải không mở về bên trái
	var v: Dictionary = MonoTile.make_tile(MonoTile.TileType.STRAIGHT, 0)
	_assert_false(
		MonoTile.edges_connect(h1, pos_left, v, pos_right),
		"STRAIGHT ngang + STRAIGHT dọc -> không nối"
	)

	# CORNER rot 3 mở left+top, đặt bên phải tile ngang -> nối
	var c: Dictionary = MonoTile.make_tile(MonoTile.TileType.CORNER, 3)
	_assert_true(
		MonoTile.edges_connect(h1, pos_left, c, pos_right),
		"STRAIGHT ngang + CORNER(left,top) -> nối"
	)

	# Không kề cạnh thì luôn false, kể cả khi cạnh khớp
	_assert_false(
		MonoTile.edges_connect(h1, Vector2i(0, 0), h2, Vector2i(5, 5)),
		"không kề cạnh -> không nối"
	)

	# Quan hệ nối phải đối xứng
	for rot_a in range(MonoTile.ROTATION_COUNT):
		for rot_b in range(MonoTile.ROTATION_COUNT):
			var a: Dictionary = MonoTile.make_tile(MonoTile.TileType.CORNER, rot_a)
			var b: Dictionary = MonoTile.make_tile(MonoTile.TileType.CORNER, rot_b)
			_assert_true(
				(MonoTile.edges_connect(a, pos_left, b, pos_right)
					== MonoTile.edges_connect(b, pos_right, a, pos_left)),
				"đối xứng: CORNER %d <-> CORNER %d" % [rot_a, rot_b]
			)


# ----------------------------------------------------------------------------
# Test: canonical rotation
# ----------------------------------------------------------------------------

func _test_canonical_rotation() -> void:
	_group("Canonical rotation (dùng cho get_valid_moves / AI)")

	_assert_eq(
		MonoTile.get_canonical_rotation(MonoTile.TileType.STRAIGHT, 2), 0,
		"STRAIGHT rot 2 gộp về 0"
	)
	_assert_eq(
		MonoTile.get_canonical_rotation(MonoTile.TileType.STRAIGHT, 3), 1,
		"STRAIGHT rot 3 gộp về 1"
	)
	_assert_eq(
		MonoTile.get_canonical_rotation(MonoTile.TileType.CORNER, 3), 3,
		"CORNER giữ nguyên rot 3"
	)
	_assert_eq(
		MonoTile.get_distinct_rotation_count(MonoTile.TileType.STRAIGHT), 2,
		"STRAIGHT có 2 hình dạng khác nhau"
	)
	_assert_eq(
		MonoTile.get_distinct_rotation_count(MonoTile.TileType.CORNER), 4,
		"CORNER có 4 hình dạng khác nhau"
	)

	# Rotation cùng canonical thì phải cho ra cùng tập cạnh
	for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
		for rot in range(MonoTile.ROTATION_COUNT):
			var canon: int = MonoTile.get_canonical_rotation(type, rot)
			_assert_true(
				MonoTile.get_edges(type, rot) == MonoTile.get_edges(type, canon),
				"%s rot %d cùng cạnh với canonical %d" % [_type_name(type), rot, canon]
			)


# ----------------------------------------------------------------------------
# Test: serialize
# ----------------------------------------------------------------------------

func _test_serialize() -> void:
	_group("Serialize / deserialize")

	for type in [MonoTile.TileType.STRAIGHT, MonoTile.TileType.CORNER]:
		for rot in range(MonoTile.ROTATION_COUNT):
			var tile: Dictionary = MonoTile.make_tile(type, rot)
			var restored: Dictionary = MonoTile.from_dict(MonoTile.to_dict(tile))
			_assert_true(
				restored == tile,
				"%s rot %d: round-trip giữ nguyên" % [_type_name(type), rot]
			)

	# Phải qua được JSON thật (không chứa Node, Vector2i hay object)
	var sample: Dictionary = MonoTile.to_dict(MonoTile.make_tile(MonoTile.TileType.CORNER, 2))
	var json_text: String = JSON.stringify(sample)
	var parsed: Variant = JSON.parse_string(json_text)
	_assert_true(parsed != null, "tile stringify/parse được bằng JSON")
	_assert_eq(int(parsed["rotation"]), 2, "rotation giữ nguyên sau JSON")


# ----------------------------------------------------------------------------
# Test: validate định dạng tile
# ----------------------------------------------------------------------------

func _test_is_valid_tile() -> void:
	_group("is_valid_tile")

	_assert_true(
		MonoTile.is_valid_tile(MonoTile.make_tile(MonoTile.TileType.STRAIGHT, 0)),
		"tile hợp lệ"
	)
	_assert_false(MonoTile.is_valid_tile({}), "dict rỗng")
	_assert_false(MonoTile.is_valid_tile({"type": 0}), "thiếu rotation")
	_assert_false(MonoTile.is_valid_tile({"rotation": 0}), "thiếu type")
	_assert_false(MonoTile.is_valid_tile({"type": 9, "rotation": 0}), "type không tồn tại")
	_assert_false(MonoTile.is_valid_tile({"type": 0, "rotation": 4}), "rotation ngoài khoảng")
	_assert_false(MonoTile.is_valid_tile({"type": 0, "rotation": -1}), "rotation âm")
	_assert_false(MonoTile.is_valid_tile({"type": "straight", "rotation": 0}), "type là String")


# ----------------------------------------------------------------------------
# Hạ tầng test
# ----------------------------------------------------------------------------

func _group(title: String) -> void:
	_current_group = title
	print("\n--- %s ---" % title)


func _check_edges(type: int, rotation: int, expected_open: Array) -> void:
	var edges: Dictionary = MonoTile.get_edges(type, rotation)
	var ok: bool = true
	for edge_name in MonoTile.EDGE_ORDER:
		var should_be_open: bool = edge_name in expected_open
		if edges[edge_name] != should_be_open:
			ok = false
	_assert_true(
		ok,
		"%s rot %d -> [%s]" % [_type_name(type), rotation, ", ".join(expected_open)]
	)


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
		push_error("[tile test] FAIL: %s" % label)


func _assert_false(condition: bool, label: String) -> void:
	_assert_true(not condition, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_passed += 1
		print("  PASS  %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s (nhận %s, mong đợi %s)" % [label, str(actual), str(expected)])
		push_error("[tile test] FAIL: %s" % label)


func _type_name(type: int) -> String:
	return "STRAIGHT" if type == MonoTile.TileType.STRAIGHT else "CORNER"


func _print_summary() -> void:
	var total: int = _passed + _failed
	print("\n=========================================")
	print("  TỔNG: %d test | PASS %d | FAIL %d" % [total, _passed, _failed])
	if _failed == 0:
		print("  TẤT CẢ TEST ĐỀU PASS")
	else:
		print("  CÓ TEST FAIL — xem log phía trên")
	print("=========================================")
