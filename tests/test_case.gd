class_name TestCase
extends Node

# ============================================================================
# Monorail — Hạ tầng test dùng chung
# Phụ trách: Khiêm
#
# Các file test kế thừa class này để khỏi chép lại phần đếm PASS/FAIL.
#
#     extends TestCase
#
#     func _ready() -> void:
#         _begin("TÊN NHÓM TEST")
#         _group("Nhóm nhỏ")
#         _assert_eq(actual, expected, "mô tả")
#         _print_summary()
#
# Assertion riêng của từng nhóm (ví dụ kiểm tra ValidationResult) thì viết
# trong chính file test đó, gọi _pass() / _fail() để cộng điểm.
# ============================================================================

var _passed: int = 0
var _failed: int = 0
var _suite: String = "test"


func _begin(title: String) -> void:
	_suite = title
	print("\n=========================================")
	print("  %s" % title)
	print("=========================================")


func _group(title: String) -> void:
	print("\n--- %s ---" % title)


func _pass(label: String) -> void:
	_passed += 1
	print("  PASS  %s" % label)


func _fail(label: String) -> void:
	_failed += 1
	print("  FAIL  %s" % label)
	push_error("[%s] FAIL: %s" % [_suite, label])


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass(label)
	else:
		_fail(label)


func _assert_false(condition: bool, label: String) -> void:
	_assert_true(not condition, label)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass(label)
	else:
		_fail("%s (nhận %s, mong đợi %s)" % [label, str(actual), str(expected)])


func _print_summary() -> void:
	var total: int = _passed + _failed
	print("\n=========================================")
	print("  TỔNG: %d test | PASS %d | FAIL %d" % [total, _passed, _failed])
	if _failed == 0:
		print("  TẤT CẢ TEST ĐỀU PASS")
	else:
		print("  CÓ TEST FAIL — xem log phía trên")
	print("=========================================")
