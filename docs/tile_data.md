# Monorail — TileData Contract

**Phụ trách:** Khiêm · **Giai đoạn 1 (Tuần 1)** · File: `scripts/core/tile_data/tile_data.gd`

Đây là bản chốt quy ước tile. Công đọc file này trước khi ghép `GameState.board` và `apply_move()`.
Nếu cần đổi bất kỳ quy ước nào bên dưới, báo trước khi sửa code — `move_validator` và `check_win` đều dựa vào đây.

---

## 1. Tên class

Godot 4 đã có sẵn class built-in tên `TileData` (thuộc hệ TileMap), nên không khai báo `class_name TileData` được — engine báo lỗi parser ngay.

Class trong project tên là **`MonoTile`**:

```gdscript
MonoTile.get_edges(MonoTile.TileType.CORNER, 1)
```

Khái niệm "TileData" trong tài liệu vẫn giữ nguyên — nó chỉ **định dạng Dictionary**, không phải tên class.

---

## 2. Định dạng tile

```gdscript
{
    "type": TileType,   # int: 0 = STRAIGHT, 1 = CORNER
    "rotation": int     # 0, 1, 2, 3
}
```

- **Không lưu `edges` trong tile.** Cạnh luôn được tính bằng `get_edges(type, rotation)`, nên rotation và edges không bao giờ lệch nhau.
- `rotation` là số nguyên 0–3, tương ứng 0° / 90° / 180° / 270°, **quay theo chiều kim đồng hồ**.
- Luôn tạo tile bằng `MonoTile.make_tile(type, rotation)` để rotation được chuẩn hóa sẵn.

---

## 3. Quy ước cạnh

Hệ trục theo chuẩn Godot: `Vector2i(x, y)`, **y tăng khi đi xuống dưới**.

| Cạnh | Offset |
|---|---|
| `top` | `Vector2i(0, -1)` |
| `right` | `Vector2i(1, 0)` |
| `bottom` | `Vector2i(0, 1)` |
| `left` | `Vector2i(-1, 0)` |

Thứ tự chuẩn `EDGE_ORDER = ["top", "right", "bottom", "left"]` — xoay theo chiều kim đồng hồ. Xoay 90° CW nghĩa là cạnh ở index `i` chuyển sang index `(i + 1) % 4`.

### Hình dạng gốc (rotation 0)

- `STRAIGHT` rotation 0 = đường ray **dọc** → mở `top` + `bottom`
- `CORNER` rotation 0 = đường ray gấp **lên-phải** → mở `top` + `right`

### Bảng đầy đủ

| Type | Rotation | Cạnh mở |
|---|---|---|
| STRAIGHT | 0 | top, bottom |
| STRAIGHT | 1 | right, left |
| STRAIGHT | 2 | top, bottom |
| STRAIGHT | 3 | right, left |
| CORNER | 0 | top, right |
| CORNER | 1 | right, bottom |
| CORNER | 2 | bottom, left |
| CORNER | 3 | left, top |

**Bất biến:** mọi tile luôn có đúng **2 cạnh mở**. `get_edges()` luôn trả về đủ 4 khóa (`top`/`right`/`bottom`/`left`), khóa nào không mở thì bằng `false` — Công không cần kiểm tra `has()`.

---

## 4. Rotate và Flip

| Thao tác | Hành vi |
|---|---|
| `rotate_tile(tile)` | `rotation + 1` (90° CW), giữ nguyên `type` |
| `rotate_tile_ccw(tile)` | `rotation - 1`, tự chuẩn hóa về 0–3 |
| `flip_tile(tile)` | Đổi `STRAIGHT <-> CORNER`, **giữ nguyên rotation** |

**Cả hai hàm đều trả về Dictionary MỚI, không sửa tile đầu vào.** Pending move giữ tile của mình, gọi rotate/flip rồi gán lại kết quả:

```gdscript
pending_move["tiles"][i] = MonoTile.rotate_tile(pending_move["tiles"][i])
```

Tính chất đã được test:

- Xoay CW 4 lần → về đúng tile ban đầu
- Xoay CW rồi CCW → về đúng tile ban đầu
- Flip 2 lần → về đúng tile ban đầu

> Lưu ý về flip: theo Rules, tile vật lý có 2 mặt (thẳng / góc), nên flip đổi **mặt** chứ không phải mirror hình học. Rotation được giữ nguyên vì người chơi lật tile tại chỗ rồi mới xoay tiếp.

---

## 5. Kề cạnh và nối đường ray

```gdscript
MonoTile.are_adjacent(a: Vector2i, b: Vector2i) -> bool
MonoTile.get_edge_between(from: Vector2i, to: Vector2i) -> String   # "" nếu không kề
MonoTile.get_neighbor_positions(pos: Vector2i) -> Array[Vector2i]   # đúng 4 ô
MonoTile.edges_connect(tile_a, pos_a, tile_b, pos_b) -> bool
```

- **Chỉ tính kề cạnh trên/dưới/trái/phải. Không tính kề chéo** (Rules mục 6, 8).
- `edges_connect()` = cả hai tile đều mở về phía nhau. Quan hệ này đối xứng.
- `edges_connect()` phục vụ `check_win()` và feedback UI — **không phải luật đặt tile**. Theo Rules mục 7, tile mới không bắt buộc phải nối ray ngay khi đặt.

---

## 6. Canonical rotation (dùng sau, cho AI)

`STRAIGHT` rotation 0 và 2 cho ra cùng tập cạnh (1 và 3 cũng vậy). Để `get_valid_moves()` không sinh ra hai move trùng nhau:

```gdscript
MonoTile.get_canonical_rotation(type, rotation) -> int   # STRAIGHT: 0..1, CORNER: 0..3
MonoTile.get_distinct_rotation_count(type) -> int        # STRAIGHT: 2, CORNER: 4
```

`validate_move()` vẫn **chấp nhận cả 4 rotation** của STRAIGHT — UI không cần chuẩn hóa gì.

---

## 7. Serialize

```gdscript
MonoTile.to_dict(tile) -> Dictionary     # chỉ chứa int, JSON-safe
MonoTile.from_dict(data) -> Dictionary
```

Tile không chứa Node, Sprite, texture hay scene — `serialize_state()` của Công có thể `JSON.stringify` thẳng phần tile. Đã test round-trip qua JSON thật cho đủ 8 tổ hợp type × rotation.

Riêng `Vector2i` làm key của `board` thì JSON không giữ được — phần đó thuộc `serialize_state()` (Giai đoạn 7), Công xử lý.

---

## 8. Tile ga (station) — đã chốt

**Ga = 2 tile `STRAIGHT` đặt sẵn cạnh nhau trong `create_initial_state()`.**

`Game_State.pdf` có ghi `"tile_type": "station"` nhưng đó là bản nháp trước. `Final_DataFormat` chốt `TileType` chỉ gồm `STRAIGHT` và `CORNER` — enum này chỉ mô tả 24 tile người chơi đặt trong ván, ga bị bỏ sót chứ không phải là một loại riêng.

Hệ quả:

- **Không thêm `TileType.STATION`.** `get_edges()` giữ nguyên 2 loại.
- Ga nằm trong `board` như tile bình thường, và **không** làm giảm `remaining_tiles` (vẫn là 24 khi bắt đầu).
- Validator coi ga như tile đã có trên board: tile mới chỉ cần kề cạnh ga là hợp lệ.

### Còn 2 việc cần Công chốt

1. **`check_win()` cần biết ô nào là ga.** Vì ga không phân biệt được với tile STRAIGHT thường trong `board`, hàm duyệt đường ray không tự tìm được điểm xuất phát. Cách đơn giản nhất: `create_initial_state()` lưu thêm một field, ví dụ

   ```gdscript
   "station_positions": [Vector2i, Vector2i]
   ```

   Đây là field **read-only** đối với mình — chỉ đọc, không sửa. Nếu Công không muốn thêm field vào `GameState`, phương án thay thế là hard-code vị trí ga thành hằng số dùng chung, nhưng như vậy sẽ khó thay đổi board sau này.

2. **Vị trí và rotation ban đầu của 2 ga.** Cần con số cụ thể để mình viết test `validate_move()` (Tuần 3) và `check_win()` (Tuần 5). Ví dụ `Vector2i(0,0)` và `Vector2i(1,0)`, cả hai rotation 1 (nằm ngang, nối nhau).

> **Đã thống nhất:** dùng **enum int** theo `Final_DataFormat`, không dùng String (`"straight"`/`"corner"`) như `Game_State.pdf`.

---

## 9. Chạy test

Mở project trong Godot 4.x → **F5**. Scene chính là `scenes/TileTestRunner.tscn`, kết quả PASS/FAIL in ra Output panel.

Test đang phủ: đủ 4 rotation của cả 2 loại tile, chuẩn hóa rotation âm/lớn, tính bất biến của rotate/flip, số cạnh mở, kề cạnh, tính đối xứng của nối ray, canonical rotation, serialize round-trip, và validate định dạng tile.

Khi Công thêm scene game thật, đổi `run/main_scene` trong `project.godot` sang scene đó và chạy test bằng cách mở riêng `TileTestRunner.tscn` (F6).
