# Monorail — Tile Interaction & Move Validation

**Phụ trách:** Khiêm · **Giai đoạn 2 (Tuần 2)**

Ba file mới, tất cả đều **chỉ đọc GameState**, không sửa board, không giảm `remaining_tiles`, không chuyển lượt, không đụng Node/UI:

| File | Class | Vai trò |
|---|---|---|
| `scripts/core/tile_data/placement_helper.gd` | `PlacementHelper` | Ô nào đặt được, ghost preview xanh/đỏ |
| `scripts/core/pending_move/pending_move.gd` | `PendingMove` | Giữ 1–3 tile đang thử đặt |
| `scripts/core/move_validator/move_validator.gd` | `MoveValidator` | `validate_move()` — bản Giai đoạn 2 |

---

## 1. Cách ghép vào turn flow

```gdscript
# --- Bắt đầu lượt ---
var pending := PendingMove.new(state.current_player)
pending.changed.connect(_render_board)     # tự render lại mỗi khi pending đổi

# --- Chuột di chuyển: ghost preview ---
func _on_cell_hovered(cell: Vector2i) -> void:
    var preview := PlacementHelper.get_preview_state(state.board, pending.get_tiles(), cell)
    var is_ok := preview == PlacementHelper.PreviewState.VALID
    ghost.modulate = Color.GREEN if is_ok else Color.RED
    feedback_label.text = PlacementHelper.describe_preview_state(preview)

# --- Click đặt tile ---
func _on_cell_clicked(cell: Vector2i) -> void:
    if PlacementHelper.can_place_at(state.board, pending.get_tiles(), cell):
        pending.add_tile(cell, selected_type, selected_rotation)

# --- Nút Rotate / Flip / Clear ---
pending.rotate_at(cell)
pending.flip_at(cell)
pending.clear()

# --- Nút Confirm ---
func confirm_move() -> void:
    var result := MoveValidator.validate_move(state, pending.to_move())
    if not result["is_valid"]:
        feedback_label.text = result["message"]
        _highlight(result["invalid_positions"])
        return                                  # KHÔNG xóa pending, KHÔNG đổi state
    RulesEngine.apply_move(state, pending.to_move())
    # check_win() -> end_turn() -> switch_player()
    pending.reset_for_player(state.current_player)
```

Điểm quan trọng: **nước đi sai không được đụng vào `GameState` và không được xóa pending move** (Roadmap Giai đoạn 3, Final_DataFormat mục 4). `MoveValidator` đã đảm bảo phần của nó — phần còn lại nằm ở `confirm_move()`.

---

## 2. PlacementHelper

Tất cả hàm đều `static`.

```gdscript
is_occupied(board, position) -> bool
is_pending_at(pending_tiles, position) -> bool
is_free(board, pending_tiles, position) -> bool

is_adjacent_to_board(board, position) -> bool
is_adjacent_to_pending(pending_tiles, position) -> bool
is_adjacency_ok(board, pending_tiles, position) -> bool

get_preview_state(board, pending_tiles, position) -> PreviewState
can_place_at(board, pending_tiles, position) -> bool
describe_preview_state(state) -> String          # thông báo tiếng Việt cho UI
get_placeable_positions(board, pending_tiles) -> Array[Vector2i]

is_cluster_contiguous(positions) -> bool
is_cluster_aligned(positions) -> bool            # CHƯA áp dụng, xem mục 5
cluster_touches_board(board, positions) -> bool

get_connected_edges(board, position, tile) -> Array[String]
count_connections(board, position, tile) -> int
```

`pending_tiles` là `Array` các Dictionary `{position, type, rotation}` — chính là `pending.get_tiles()`.

### PreviewState

| Giá trị | Ghost | Ý nghĩa |
|---|---|---|
| `VALID` | xanh | đặt được |
| `OCCUPIED` | đỏ | đã có tile committed |
| `PENDING_OCCUPIED` | đỏ | đã có pending tile ở ô này |
| `NOT_ADJACENT` | đỏ | không chạm board / rời khỏi cụm pending |
| `LIMIT_REACHED` | đỏ | đã đủ 3 tile |

**Quy tắc kề cạnh trong preview:**

- Chưa có pending tile nào → ô phải **kề board**.
- Đã có pending tile → ô phải **kề cụm pending**.

Vế thứ hai là vì Rules mục 8: các tile mới trong cùng một lượt phải kề nhau. Nếu chỉ kề board mà rời khỏi cụm pending thì nước đi sẽ hỏng khi Confirm, nên chặn ngay từ preview cho người chơi đỡ mất công.

---

## 3. PendingMove

Object có state (không phải static). Có signal `changed` — nối vào để render lại lớp pending.

```gdscript
PendingMove.new(player_id)
MAX_TILES = 3

size() / is_empty() / is_full() / can_add()
has_tile_at(pos) / get_tile_at(pos) / get_tiles()

add_tile(pos, type, rotation = 0) -> bool
remove_at(pos) -> bool
clear()

rotate_at(pos) -> bool
flip_at(pos) -> bool
move_tile(from, to) -> bool

to_move() -> Dictionary                # đúng Move format
PendingMove.from_move(move) -> PendingMove
reset_for_player(new_player_id)
```

Bất biến mà object này tự giữ: **tối đa 3 tile, không hai tile cùng một ô**. Nó **không** kiểm tra ô có bị board chiếm không — gọi `PlacementHelper.can_place_at()` trước.

`get_tile_at()`, `get_tiles()` và `to_move()` đều trả **bản sao**, sửa bên ngoài không ảnh hưởng pending move.

---

## 4. MoveValidator

```gdscript
MoveValidator.validate_move(state: GameState, move: Dictionary) -> Dictionary
```

Kết quả đúng như Final_DataFormat mục 5:

```gdscript
{
    "is_valid": bool,
    "error_code": String,
    "message": String,                  # tiếng Việt, hiện thẳng lên UI được
    "invalid_positions": Array[Vector2i]
}
```

Chỉ báo **lỗi đầu tiên** tìm thấy, để người chơi không bị dội 5 thông báo cùng lúc.

### Mã lỗi

| `error_code` | Khi nào |
|---|---|
| `OK` | hợp lệ |
| `GAME_FINISHED` | `phase` không phải `PLACING` |
| `WRONG_PLAYER` | `player_id` khác `current_player` |
| `INVALID_TILE_COUNT` | 0 tile hoặc quá 3 tile |
| `NOT_ENOUGH_TILES` | nhiều hơn `remaining_tiles` |
| `INVALID_TILE_DATA` | thiếu khóa, sai kiểu, rotation ngoài 0–3 |
| `DUPLICATE_POSITION` | hai tile trong move vào cùng một ô |
| `CELL_OCCUPIED` | đặt đè lên tile đã có |
| `TILES_NOT_ADJACENT` | các tile mới không thành một cụm liền |
| `NOT_TOUCHING_BOARD` | không tile nào kề board |

Các hằng số này là `const` trong `MoveValidator`, so sánh bằng `MoveValidator.CELL_OCCUPIED` chứ đừng gõ chuỗi tay.

### Chưa kiểm tra — để Giai đoạn 3

- Luật thẳng hàng (xem mục 5).
- Điều kiện kết nối đường ray.

**Chữ ký hàm và định dạng kết quả đã chốt** — Công nối `confirm_move()` vào bây giờ, tuần sau mình thêm rule mà chỗ nối không phải sửa.

---

## 5. Cần chốt: luật thẳng hàng

Hai tài liệu đang lệch nhau:

- **Rules.pdf mục 7 (và bản tiếng Việt mục 8):** khi đặt từ 2 tile trở lên, các tile mới chỉ cần **kề cạnh nhau**.
- **Roadmap Giai đoạn 3 rule 5:** các tile phải kề nhau **và phải thẳng hàng**.

Khác biệt thực tế: đặt 3 tile hình chữ L — theo Rules là hợp lệ, theo Roadmap là sai.

Hiện tại validator làm **theo Rules.pdf** (chấp nhận hình L), vì Rules.pdf là luật gốc của board game. Hàm `PlacementHelper.is_cluster_aligned()` đã viết sẵn và có test — nếu chốt theo Roadmap thì chỉ cần thêm 4 dòng vào `validate_move()`.

Cần Công xác nhận trước khi mình khóa lại ở Giai đoạn 3.

---

## 6. Ghi chú về code hiện tại của Công

Mình **không sửa** file nào của Công. Liệt kê ở đây để Công tự xử lý:

1. **`game_state.gd` dòng 4: `var game_state: GameState`** — GameState đang chứa một biến trỏ tới chính GameState. Thừa và dễ gây nhầm, nên xóa.

2. **Thư mục `scripts/core/game_state.gd/`** có đuôi `.gd` nhưng lại là folder. Theo Git_Workflow mục 6 nên là `scripts/core/game_state/` và `scripts/core/rules_engine/`. Đổi sớm thì đỡ phải sửa import sau.

3. **`main.gd._on_place_tile_button_pressed()` giảm `remaining_tiles` trực tiếp từ UI.** Vi phạm nguyên tắc 6 của Roadmap: chỉ `apply_move()` mới được đổi state chính thức. Chỗ này cần bỏ khi làm turn flow thật.

4. **`create_initial_state()` dùng `randi_range(0, 1)`** nên test không xác định được người đi trước. Đề xuất thêm tham số `starting_player: int = -1` (âm thì mới random) để test và replay dùng được. Test của mình đang tự dựng `GameState` thủ công để né chỗ này.

5. **`GameState` chưa có `impossible_declared_by`** — Game_State.pdf và Roadmap Giai đoạn 5 đều cần. Chưa gấp.

6. **`main.tscn1612972479.tmp` đang bị Git theo dõi.** File tạm của Godot, nên `git rm --cached` và thêm `*.tmp` vào `.gitignore`.

7. **`check_win()` cần biết ô nào là ga.** Hiện mình đọc `RulesEngine.LEFT_START_POS` / `RIGHT_START_POS` — dùng được. Nhưng khi làm serialize ở Giai đoạn 7, vị trí ga nên nằm trong `GameState` để state khôi phục lại là đầy đủ, không phụ thuộc hằng số trong code.

---

## 7. Chạy test

**Test tự động:** mở `scenes/TileTestRunner.tscn` → **F6**. Chạy cả test tile (Tuần 1) lẫn test placement/pending/validator (Tuần 2), in PASS/FAIL ra Output.

Test tuần 2 phủ: contract với `create_initial_state()` của Công, ô trống/bị chiếm, kề board và kề chéo, cả 5 trạng thái preview, danh sách ô đặt được, cụm liền/thẳng hàng/chạm board, nối ray, toàn bộ API của PendingMove, và 12 trường hợp hợp lệ / không hợp lệ của validator — gồm cả kiểm tra validator không làm đổi state.

Đã có một bàn thử tương tác để kiểm tra bằng mắt, chạy xong thì xóa đi cho gọn. Cần lại thì lấy từ git history: `git log --diff-filter=D -- tests/interaction_sandbox.gd`.

---

## 8. Một bài học từ bàn thử — dành cho UI của Công

**"Tile trên tay" và "tile chờ đã đặt" phải là hai thứ độc lập.**

Bản đầu của bàn thử tự động chọn tile ngay sau khi đặt, nên nút Rotate sửa nhầm tile vừa đặt thay vì tile người chơi đang cầm — và hai bên còn đồng bộ ngược trạng thái với nhau, không tách ra được.

Nguyên tắc cho UI thật:

- Đặt tile xong **không** tự chọn nó.
- Chọn một tile chờ **không** copy trạng thái sang tile trên tay.
- Lúc nào cũng cho người chơi thấy rõ Rotate/Flip đang tác động lên cái nào.

`end_turn()` / `switch_player()` / `check_win()` vẫn là phần của Công — mấy file trên không đụng vào.
