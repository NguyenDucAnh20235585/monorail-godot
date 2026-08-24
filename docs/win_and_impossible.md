# Monorail — Win Condition & Impossible Flow

**Phụ trách:** Khiêm · **Week 3**

Hai file mới, đều `static` và **chỉ đọc GameState** — không ghi `winner`, không đổi `phase`, không chuyển lượt. Việc ghi vào state vẫn là của Công.

| File | Class | Vai trò |
|---|---|---|
| `scripts/core/win_checker/win_checker.gd` | `WinChecker` | `check_win()` — tìm vòng ray khép kín qua ga |
| `scripts/core/impossible/impossible_flow.gd` | `ImpossibleFlow` | Tuyên bố và giải quyết Impossible |

---

## 1. Luật đã chốt

**Thắng bằng đường ray:** hoàn thành một tuyến đường ray khép kín xuất phát từ nhà ga và quay trở lại chính nhà ga. Người đặt tile hoàn thành vòng đó thắng ngay.

**Hết tile mà không ai tuyên bố Impossible:** người đặt tile cuối cùng **thua**, đối thủ thắng. Nếu tile cuối cùng lại chính là tile khép được vòng thì luật thắng được ưu tiên — người khép vòng thắng.

**Thắng bằng Impossible:**

1. Đầu lượt của mình, người chơi có thể tuyên bố "không thể hoàn thành".
2. Ván bước vào giai đoạn quyết định. **Đối thủ** dùng số tile còn lại để cố hoàn thành đường ray; người tuyên bố không đặt tile nữa.
3. Đối thủ hoàn thành được vòng → **đối thủ thắng** (đã chứng minh tuyên bố sai).
   Đối thủ dùng hết tile mà không xong → **người tuyên bố thắng**.

Engine **không** tự phán đoán tuyên bố đúng hay sai — nó chỉ kiểm tra state có hợp lệ để tuyên bố không, rồi để đối thủ chứng minh bằng cách chơi. Tự dò xem có hoàn thành được không là bài toán tìm kiếm rất lớn với 24 tile, đủ để treo game.

---

## 2. WinChecker

```gdscript
WinChecker.check_win(state: GameState, last_move: Dictionary = {}) -> Dictionary
```

```gdscript
{
    "is_win": bool,                     # ván đã kết thúc và có người thắng
    "winner": int,                      # -1 nếu chưa kết thúc
    "reason": String,                   # NONE / LOOP_COMPLETED / OUT_OF_TILES
    "loop_positions": Array[Vector2i]   # các ô trong vòng, theo thứ tự đi
}
```

| `reason` | Ý nghĩa | `winner` |
|---|---|---|
| `NONE` | ván chưa kết thúc | `-1` |
| `LOOP_COMPLETED` | khép được vòng qua ga | người vừa đặt tile |
| `OUT_OF_TILES` | hết tile mà chưa có vòng | **đối thủ** của người vừa đặt tile |

> **Cẩn thận:** `is_win` nghĩa là "ván đã có người thắng", **không** phải "người vừa đi đã thắng". Ở trường hợp `OUT_OF_TILES` thì người thắng là đối thủ của người vừa đặt tile. Luôn đọc `winner`, đừng suy ra từ lượt hiện tại.

`reason` và `loop_positions` là phần thêm ngoài contract trong Roadmap — `reason` để ghi game log cho đúng, `loop_positions` để tô sáng vòng thắng. Không cần thì bỏ qua.

**Gọi ở đâu:** sau `apply_move()`, trước `end_turn()` — đúng thứ tự trong Turn_Flow. Lúc đó `state.current_player` vẫn là người vừa đi, nên `last_move` có thể bỏ trống. Truyền vào thì chắc chắn hơn: hàm ưu tiên `last_move["player_id"]`.

Hàm phụ:

```gdscript
WinChecker.find_station_loop(board) -> Array[Vector2i]   # vòng chứa ga, rỗng nếu chưa có
WinChecker.find_loop(board, start) -> Array[Vector2i]    # vòng chứa một ô bất kỳ
WinChecker.get_station_positions() -> Array[Vector2i]    # đọc từ RulesEngine
```

### Thuật toán

Mỗi tile luôn có **đúng 2 cạnh mở**, nên từ một tile đi vào bằng một cạnh thì chỉ có duy nhất một cạnh để đi ra. Đường đi là xác định, không cần quay lui hay tìm kiếm.

Bắt đầu từ tile ga trái, đi theo một cạnh, mỗi bước kiểm tra:

- ô kế tiếp trống → **nhánh cụt**, chưa thắng;
- tile kề không mở về phía mình → **ray đứt**, chưa thắng;
- quay về ga nhưng bằng sai cạnh → chưa khép kín;
- quay về ga bằng đúng cạnh còn lại → **vòng hợp lệ**.

Cuối cùng kiểm tra vòng có chứa cả hai tile ga không. Độ phức tạp tuyến tính theo số tile trong vòng.

---

## 3. ImpossibleFlow

`GameState` hiện chưa có chỗ lưu ai đã tuyên bố, nên các hàm nhận `declared_by` như một tham số thay vì tự đọc từ state. Công truyền vào từ chỗ mình lưu — xem mục 5.

```gdscript
# Bật/tắt nút Declare Impossible
ImpossibleFlow.can_declare(state, player_id, pending_tile_count = 0, declared_by = -1)
    -> { "is_allowed": bool, "error_code": String, "message": String }

# Thực hiện tuyên bố
ImpossibleFlow.declare_impossible(state, player_id, pending_tile_count = 0, declared_by = -1)
    -> { "is_valid", "error_code", "message", "declared_by": int, "challenger": int }

# Gọi sau mỗi apply_move() trong giai đoạn quyết định
ImpossibleFlow.resolve_after_move(state, last_move, declared_by)
    -> { "is_finished", "winner", "reason", "message", "loop_positions" }

# Phụ trợ
ImpossibleFlow.is_in_review(declared_by) -> bool
ImpossibleFlow.get_challenger(declared_by) -> int
ImpossibleFlow.should_switch_player(declared_by) -> bool
```

`ImpossibleFlow.NOBODY` là `-1` — giá trị khi chưa ai tuyên bố.

### Mã lỗi khi tuyên bố

| `error_code` | Khi nào |
|---|---|
| `OK` | được phép |
| `GAME_ALREADY_FINISHED` | `phase` đã là `GAME_FINISHED` |
| `WRONG_PLAYER` | không phải lượt của người này |
| `ALREADY_DECLARED` | trong ván đã có người tuyên bố |
| `PENDING_NOT_EMPTY` | đang có pending tile — chỉ được tuyên bố ở đầu lượt |
| `NO_TILES_LEFT` | hết tile, đối thủ không còn gì để đặt |

### Lý do kết thúc giai đoạn quyết định

| `reason` | Ý nghĩa | `winner` |
|---|---|---|
| `CONTINUE` | đối thủ còn tile, đi tiếp | `-1` |
| `CHALLENGER_COMPLETED_LOOP` | đối thủ hoàn thành vòng | đối thủ |
| `CHALLENGER_OUT_OF_TILES` | hết tile mà chưa xong | người tuyên bố |

---

## 4. Cách ghép vào game flow

```gdscript
var impossible_declared_by: int = ImpossibleFlow.NOBODY   # xem mục 5

func confirm_move() -> void:
    var move := pending_move.to_move()
    var validation := MoveValidator.validate_move(game_state, move)
    if not validation["is_valid"]:
        log_line("Invalid move: %s" % validation["message"])
        return                                   # KHÔNG đổi state, giữ pending

    RulesEngine.apply_move(game_state, move)

    if ImpossibleFlow.is_in_review(impossible_declared_by):
        var outcome := ImpossibleFlow.resolve_after_move(
            game_state, move, impossible_declared_by
        )
        log_line(outcome["message"])
        if outcome["is_finished"]:
            finish_game(outcome["winner"])
            return
        start_turn()                             # đối thủ đi tiếp, KHÔNG đổi lượt
        return

    var win := WinChecker.check_win(game_state, move)
    if win["is_win"]:
        if win["reason"] == WinChecker.REASON_OUT_OF_TILES:
            log_line("Hết tile mà chưa hoàn thành đường ray.")
        finish_game(win["winner"])       # KHÔNG dùng current_player làm winner
        return

    RulesEngine.end_turn(game_state)
    start_turn()


func _on_impossible_button_pressed() -> void:
    var result := ImpossibleFlow.declare_impossible(
        game_state, game_state.current_player,
        pending_move.size(), impossible_declared_by
    )
    if not result["is_valid"]:
        log_line(result["message"])
        return

    impossible_declared_by = result["declared_by"]
    game_state.current_player = result["challenger"]
    log_line(result["message"])
    start_turn()


func finish_game(winner: int) -> void:
    game_state.winner = winner
    game_state.phase = GameState.GamePhase.GAME_FINISHED
    # khóa toàn bộ interaction
```

Nút Declare Impossible nên bật/tắt bằng:

```gdscript
$ImpossibleButton.disabled = not ImpossibleFlow.can_declare(
    game_state, game_state.current_player,
    pending_move.size(), impossible_declared_by
)["is_allowed"]
```

---

## 5. Việc cần Công làm

1. **Lưu người tuyên bố.** `GameState` chưa có `impossible_declared_by` (Game_State.pdf có liệt kê). Thêm vào:

   ```gdscript
   var impossible_declared_by: int = -1
   ```

   Trong lúc chờ, controller giữ tạm một biến cục bộ như ví dụ ở mục 4 cũng chạy được — API của mình nhận `declared_by` qua tham số nên không phụ thuộc.

2. **Thêm phase `IMPOSSIBLE_REVIEW`** nếu muốn UI phân biệt giai đoạn quyết định:

   ```gdscript
   enum GamePhase { PLACING, GAME_FINISHED, IMPOSSIBLE_REVIEW }
   ```

   **Thêm vào CUỐI enum, đừng chèn vào giữa.** Chèn giữa sẽ đổi giá trị số của `GAME_FINISHED` từ 1 thành 2, làm hỏng mọi state đã serialize và mọi so sánh đang lưu số.

3. **`MoveValidator` mình đã sửa một dòng.** Trước đây nó chặn khi `phase != PLACING`; giờ chỉ chặn khi `phase == GAME_FINISHED`. Nếu không sửa, ngay khi Công đặt phase thành `IMPOSSIBLE_REVIEW` thì validator sẽ chặn hết mọi nước đi của đối thủ. `error_code` vẫn là `GAME_FINISHED`, phía Công không phải đổi gì.

4. **Không đổi lượt trong giai đoạn quyết định.** Đối thủ đi liên tiếp cho tới khi hoàn thành hoặc hết tile. Dùng `ImpossibleFlow.should_switch_player()` thay cho việc gọi thẳng `end_turn()`.

---

## 6. Còn để mở

1. **Rules.pdf mục 8 có thể đọc chặt hơn.** Câu "all railroad tracks already in place must be connected" có thể hiểu là *mọi* tile trên bàn phải nằm trong vòng, không được có tile lẻ hay nhánh cụt. Hiện `check_win()` làm theo luật đã chốt: **chỉ cần có vòng khép kín qua ga**, tile lẻ bên ngoài không ảnh hưởng. Đã có test khóa hành vi này lại (`_test_extra_tiles_outside_loop`). Nếu sau này chốt chặt hơn thì chỉ cần thêm một bước so sánh `loop.size()` với `board.size()` trong `find_station_loop()`.

---

## 7. Chạy test

Mở `scenes/TileTestRunner.tscn` → **F6**. Xem kết quả ở panel **Output**, cuộn xuống dòng `TỔNG: ... | PASS ... | FAIL ...` của từng nhóm.

Phần đếm PASS/FAIL dùng chung ở `tests/test_case.gd`. Thêm nhóm test mới thì `extends TestCase`, gọi `_begin("TÊN NHÓM")` ở đầu `_ready()` và `_print_summary()` ở cuối, rồi gắn script vào một node con trong `TileTestRunner.tscn`.

### `test_playthrough.gd` — chơi hết ván

Đây là file đáng xem nhất. Nó mô phỏng **trọn vẹn bốn ván đấu**, đi qua đúng pipeline mà controller của Công dùng:

```
validate_move()  ->  apply_move()  ->  check_win()  ->  end_turn()
```

Nếu phần của hai người ghép sai với nhau thì lộ ra ở đây, không phải lúc playtest bằng tay. Bốn ván:

| Ván | Kịch bản | Kết quả mong đợi |
|---|---|---|
| 1 | Hai người thay phiên, 5 lượt, 8 tile khép thành vòng quanh ga | Người đặt tile cuối thắng, không thắng sớm ở lượt nào |
| 2 | P1 đặt 1 lượt, P2 tuyên bố Impossible, P1 đi liên tiếp và khép được vòng | P1 thắng vì chứng minh tuyên bố sai |
| 3 | P2 tuyên bố khi chỉ còn 2 tile, P1 đặt hết mà không xong | P2 thắng |
| 4 | Còn 1 tile, không ai tuyên bố, P1 đặt nốt | P1 **thua**, P2 thắng |

Log in ra từng lượt cho dễ đọc:

```
Lượt 1 — Người chơi 1 đặt 1 tile | còn 23 tile | chưa kết thúc
Lượt 2 — Người chơi 2 đặt 2 tile | còn 21 tile | chưa kết thúc
...
Lượt 5 — Người chơi 1 đặt 1 tile | còn 16 tile | KẾT THÚC — Người chơi 1 thắng (LOOP_COMPLETED)
```

Vòng dùng trong test là hình chữ nhật 10 tile ôm quanh hai ga:

```
(-1,0) ─ (0,0)ga ─ (1,0)ga ─ (2,0)
  │                            │
(-1,1)                      (2,1)
  │                            │
(-1,2) ─ (0,2) ─── (1,2) ─── (2,2)
```

### `test_win_checker.gd` — từng hàm riêng lẻ

Phủ đúng 6 case trong Roadmap cộng thêm vài case biên:

- board ban đầu chưa có vòng;
- vòng khép kín 10 tile qua cả hai ga → thắng;
- thiếu tile ở 3 vị trí khác nhau → chưa thắng;
- thiếu hẳn tile ga → không thắng;
- ray đứt do xoay sai hướng, và do đổi nhầm loại tile;
- vòng khép kín ở xa không chứa ga → không thắng;
- tile lẻ và vòng thứ hai nằm ngoài → vẫn thắng;
- winner lấy từ `last_move`, không phải `current_player`;
- hết tile mà chưa có vòng → người đặt cuối thua;
- khép vòng bằng đúng tile cuối cùng → luật thắng được ưu tiên;
- `check_win()` không làm đổi state;
- 6 mã lỗi của `can_declare()`;
- `declare_impossible()` không sửa state;
- đối thủ hoàn thành → đối thủ thắng, kể cả khi hoàn thành bằng tile cuối cùng;
- đối thủ hết tile → người tuyên bố thắng;
- còn tile → `CONTINUE`.
