# Monorail — Get Valid Moves & AI

**Phụ trách:** Khiêm · **Giai đoạn 6**

| File | Class | Vai trò |
|---|---|---|
| `scripts/core/ai/move_generator.gd` | `MoveGenerator` | Sinh nước đi hợp lệ, tìm nước khép vòng |
| `scripts/core/ai/ai_player.gd` | `AIPlayer` | Quyết định hành động cho một lượt |

Cả hai đều `static` và **chỉ đọc GameState**. AI không gọi `apply_move()`, không chuyển lượt, không sửa board. Nó trả về một hành động, Công đẩy qua đúng đường mà người thật đi.

---

## 1. Cách ghép AI vào turn flow

```gdscript
var ai_players := {1: AIPlayer.Difficulty.HEURISTIC}   # player 2 là máy

func start_turn() -> void:
    reset_pending_move()
    update_hud()
    if ai_players.has(game_state.current_player):
        await get_tree().create_timer(0.4).timeout    # cho người xem kịp nhìn
        _take_ai_turn()

func _take_ai_turn() -> void:
    var action := AIPlayer.choose_action(
        game_state,
        ai_players[game_state.current_player],
        impossible_declared_by
    )
    log_line(action["reason"])

    match action["type"]:
        AIPlayer.ACTION_DECLARE_IMPOSSIBLE:
            _declare_impossible(game_state.current_player)
        AIPlayer.ACTION_MOVE:
            pending_move = PendingMove.from_move(action["move"])
            confirm_move()                # đi qua đúng đường của người thật
        AIPlayer.ACTION_NONE:
            log_line("AI không còn nước đi.")
```

Điểm quan trọng: AI **không có đường tắt**. Nước đi của nó vẫn qua `validate_move()` rồi `apply_move()` như người chơi. Nếu AI sinh nước sai thì validator chặn, không phải board hỏng. Nhờ vậy cùng một interface dùng lại được cho network player ở Giai đoạn 8.

---

## 2. MoveGenerator

```gdscript
MoveGenerator.get_valid_moves(state, max_tiles = 1) -> Array   # mảng Move
MoveGenerator.get_moves_at(state, position) -> Array           # mọi cách đặt vào một ô
MoveGenerator.get_closing_move(state, max_tiles = 3) -> Dictionary  # {} nếu chưa khép được
```

Danh sách được lọc bằng **chính `MoveValidator`**, không có luật riêng cho AI (nguyên tắc 4 của Roadmap). Validator đổi thì danh sách tự đổi theo.

Rotation được khử trùng lặp: `STRAIGHT` chỉ sinh rotation 0 và 1, vì 2 và 3 cho ra đúng tập cạnh đó.

### Cẩn thận với `max_tiles`

Số nước đi tăng rất nhanh. Đo trên board 10 tile:

| `max_tiles` | Số nước đi | Thời gian (bản mô phỏng Python) |
|---|---|---|
| 1 | 90 | 0,4 ms |
| 2 | 1.314 | 11 ms |
| 3 | 24.858 | 381 ms |

GDScript sẽ chậm hơn Python vài lần, nên `max_tiles = 3` là đủ để làm khựng game vài giây mỗi lượt. Vì vậy mặc định là **1**.

AI vẫn đặt được 2–3 tile, nhưng không bao giờ bằng cách sinh toàn bộ tổ hợp:

- `get_closing_move()` đi thẳng từ một đầu ray tới đầu kia. Mỗi bước chỉ có 3 lựa chọn vì tile được xác định bởi cạnh vào và cạnh ra, nên tối đa 39 đường phải thử — **0,18 ms**.
- `AIPlayer` chọn nhiều tile bằng cách thêm từng tile một, mỗi bước lấy tile điểm cao nhất.

---

## 3. AIPlayer

```gdscript
AIPlayer.choose_action(state, difficulty = HEURISTIC, declared_by = -1) -> Dictionary
AIPlayer.choose_move(state, difficulty = HEURISTIC) -> Dictionary
```

`choose_action()` trả về:

```gdscript
{
    "type": String,        # ACTION_MOVE / ACTION_DECLARE_IMPOSSIBLE / ACTION_NONE
    "move": Dictionary,    # Move hợp lệ, rỗng nếu type khác ACTION_MOVE
    "reason": String       # câu tiếng Việt, ghi thẳng vào Game Log được
}
```

`choose_move()` là bản rút gọn chỉ trả Move, tiện khi chưa nối flow Impossible.

Hai mức khó: `Difficulty.RANDOM` (chọn bừa trong các nước hợp lệ) và `Difficulty.HEURISTIC` (bản dùng để chơi thật).

### AI heuristic quyết định theo bốn bước

1. **Khép được vòng thì khép** — thắng ngay.
2. **Chứng minh được ván không thể hoàn thành thì tuyên bố Impossible** (mục 4).
3. **Chọn số tile sao cho đối thủ là người đặt tile cuối cùng** — lớp phòng xa cho trường hợp hiếm khi ván kéo dài tới lúc cạn tile.
4. **Chọn vị trí**: kéo hai đầu ray lại gần nhau, thưởng cạnh ray nối khớp, phạt nặng cạnh lệch, và không mở đường cho đối thủ khép vòng ở lượt kế tiếp.

Trọng số nằm ở đầu `ai_player.gd`, muốn AI đánh khác thì sửa ở đó.

### `WEIGHT_GAP` — trọng số đáng chú ý nhất

Nó phạt theo khoảng cách còn lại giữa hai đầu đường ray, và quyết định **AI chơi kiểu gì**:

| `WEIGHT_GAP` | AI làm gì | 100 ván tự đánh |
|---|---|---|
| `0` | Kéo dài đường ray lung tung tới khi không ai khép nổi vòng, rồi tuyên bố Impossible mà thắng | 3 ván khép vòng, trung bình 13 lượt |
| `3` (đang dùng) | Chủ động khép vòng | **100 ván khép vòng**, trung bình 4,6 lượt |

Đối đầu trực tiếp thì bản có trọng số này thắng **72 – 28**, nên bật lên vừa mạnh hơn vừa cho ván đấu đúng tinh thần trò chơi. Giá trị từ 1 trở lên đều cho kết quả như nhau.

Nếu sau này thấy AI khép vòng nhanh quá, người chơi chưa kịp làm gì đã thua, thì hạ trọng số này xuống là cách chỉnh độ khó đơn giản nhất.

### Sức mạnh đo được

100 ván mỗi cặp, người đi trước chọn ngẫu nhiên:

| Đối đầu | Tỉ số |
|---|---|
| AI heuristic vs random | **100 – 0** |
| AI heuristic vs bản không ưu tiên khép vòng | **72 – 28** |

Chi phí: khoảng **3 ms mỗi lượt** trong bản mô phỏng Python. GDScript chậm hơn vài lần nhưng vẫn thừa sức chạy tức thì.

---

## 4. Khi nào AI tuyên bố Impossible

AI **chỉ tuyên bố khi chứng minh được** là không ai còn khép nổi vòng. Nó không bao giờ đoán, nên không bao giờ tuyên bố sai rồi thua oan. Hai căn cứ:

**1. Đường ray từ ga bị chặn vĩnh viễn.**
`WinChecker.trace_station_track()` trả về `TRACK_BLOCKED` khi đoạn ray từ ga đâm vào một tile đã commit mà tile đó không mở về phía mình. Tile đã commit thì không sửa được nữa, nên cạnh đó chết vĩnh viễn — không vòng nào qua ga còn khả thi.

**2. Không đủ tile để nối hai đầu ray.**
`WinChecker.min_tiles_to_close()` trả về **cận dưới** số tile cần: khoảng cách Manhattan giữa hai ô trống ở hai đầu ray, cộng một. Đường thật luôn dài hơn hoặc bằng, nên nếu cận dưới đã lớn hơn `remaining_tiles` thì chắc chắn không ai khép nổi.

Cận dưới cố tình để lỏng. Ví dụ board đầu ván cần thật sự 8 tile nhưng cận dưới chỉ báo 4. Lỏng thì AI tuyên bố muộn, nhưng **không bao giờ tuyên bố nhầm** — đánh đổi đúng hướng, vì tuyên bố sai là thua ngay.

Trong 150 ván mô phỏng: ray bị chặn xảy ra ở 2 ván, không đủ tile xảy ra ở 124 ván. Nghĩa là gần cuối ván AI hầu như luôn có cơ sở để tuyên bố.

Hai hàm này cũng dùng được cho UI: hiện cảnh báo "đường ray đã bị chặn" hoặc bật/tắt nút Declare Impossible cho người chơi.

---

## 5. Việc cần Công làm

1. **Interface nguồn điều khiển lượt** (Roadmap Giai đoạn 6): human / AI / network. Gợi ý giữ một Dictionary `{player_id: Difficulty}` như ví dụ ở mục 1 — trống thì là người thật.

2. **Độ trễ giả cho AI.** AI trả lời trong vài mili giây, đi ngay lập tức thì người chơi không kịp thấy chuyện gì xảy ra. Nên chờ 0,3–0,5 giây trước khi thực hiện.

3. **Khóa input khi tới lượt AI**, không thì người chơi bấm chồng lên lượt của máy.

4. **`PendingMove.from_move()`** dựng lại pending move từ Move của AI, nên board vẫn hiện tile mờ trước khi confirm nếu Công muốn cho xem AI "đặt thử".

---

## 6. Xem AI đánh

Mở **`scenes/AIArena.tscn`** → **F6**, xem panel Output. Đây là công cụ xem, không assert gì cả, chạy riêng để bộ test thường vẫn nhanh.

**Phần 1** cho AI đánh một ván, in bàn cờ sau mỗi lượt. Bàn cờ vẽ bằng ký tự suy thẳng từ `get_edges()`, nên nhìn hình là biết tile logic đúng hay sai:

```
Ban đầu:                Sau vài lượt:
  ·  ·  ·  ·               ·  ·  ·  ·  ·  ·  ·
  ·  ═  ═  ·               ·  ·  ·  ·  · [┌] ·
  ·  ·  ·  ·               ·  └  ─  ═  ═  ┘  ·
                           ·  ·  ·  ·  ·  ·  ·
```

`═ ║` là tile ga, `─ │` tile thẳng, `└ ┌ ┐ ┘` tile góc, `·` ô trống. Tile trong ngoặc vuông là tile vừa đặt — hoặc là vòng thắng, ở lượt cuối.

Mỗi lượt còn in lý do AI chọn nước đó, số tile còn lại, trạng thái đường ray (`OPEN` / `BLOCKED` / `CLOSED`) và số tile tối thiểu còn cần để khép vòng. Đủ để theo dõi AI đang nghĩ gì.

**Phần 2** chạy ba cặp đối đầu — Heuristic vs Random, Heuristic vs Heuristic, Random vs Random — mỗi cặp `GAMES_PER_MATCHUP` ván, in tỉ số và cách các ván kết thúc. Đổi lượt đi đầu giữa các ván cho công bằng. Muốn số liệu chắc hơn thì tăng hằng số đó trong `tests/ai_arena.gd`, đổi lại chạy lâu hơn.

Vòng lặp ván đấu nằm ở `tests/game_runner.gd`, dùng chung với `test_ai.gd`:

```gdscript
var runner := GameRunner.new()
runner.difficulties = {0: AIPlayer.Difficulty.HEURISTIC, 1: AIPlayer.Difficulty.RANDOM}
var result := runner.play(RulesEngine.create_initial_state())
# -> { "winner", "reason", "turns", "declared_by" }
```

Bật `runner.verbose = true` rồi nối ba signal `action_chosen` / `move_applied` / `impossible_declared` thì in được log từng lượt như phần 1.

---

## 7. Chạy test

Mở `scenes/TileTestRunner.tscn` → **F6**. Nhóm `MONORAIL — MOVE GENERATOR / AI` phủ:

- sinh đúng 36 nước ở board đầu ván, không trùng lặp, `STRAIGHT` chỉ 2 rotation;
- mọi nước sinh ra đều qua được `MoveValidator`;
- không bao giờ sinh nhiều tile hơn số còn lại;
- tìm đúng nước khép vòng, và không bịa ra nước khép khi chưa thể;
- bốn trạng thái của `trace_station_track()`;
- cận dưới `min_tiles_to_close()` không vượt quá số tile thật sự cần;
- AI chọn 3 tile khi còn 24, chọn 1 tile khi còn 2 (parity);
- AI chỉ tuyên bố Impossible ở hai tình huống chứng minh được, và không tuyên bố khi đã có người tuyên bố;
- thấy đường thắng thì đi ngay, không tham parity.

Cuối cùng là phần **AI tự chơi 10 ván trọn vẹn**, kiểm tra ba thứ mà unit test khó thấy: AI không sinh nước bị validator từ chối, không làm turn flow kẹt, và không ván nào chạy mãi không kết thúc. Muốn soi kỹ hơn thì tăng `SELF_PLAY_GAMES` trong `tests/test_ai.gd` — mỗi ván tốn khoảng một giây.
