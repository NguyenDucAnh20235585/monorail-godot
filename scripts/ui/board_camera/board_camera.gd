extends Camera2D

const ZOOM_STEP := 0.1
const MIN_ZOOM := 0.4
const MAX_ZOOM := 1.6

const DRAG_THRESHOLD := 6.0

var left_mouse_down := false
var is_dragging := false
var drag_start_position := Vector2.ZERO


func _ready() -> void:
	set_process_input(true)

	zoom = Vector2.ONE
	enabled = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			change_zoom(ZOOM_STEP)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			change_zoom(-ZOOM_STEP)

		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_mouse_down = true
				is_dragging = false
				drag_start_position = event.position
			else:
				left_mouse_down = false

				if is_dragging:
					get_viewport().set_input_as_handled()

				is_dragging = false

	if event is InputEventMouseMotion and left_mouse_down:
		if not is_dragging:
			var drag_distance: float = event.position.distance_to(drag_start_position)

			if drag_distance >= DRAG_THRESHOLD:
				is_dragging = true

		if is_dragging:
			position -= event.relative / zoom.x
			get_viewport().set_input_as_handled()

func change_zoom(amount: float) -> void:
	var mouse_before: Vector2 = get_global_mouse_position()

	var new_zoom: float = clampf(
		zoom.x + amount,
		MIN_ZOOM,
		MAX_ZOOM
	)

	zoom = Vector2(new_zoom, new_zoom)
	force_update_scroll()

	var mouse_after: Vector2 = get_global_mouse_position()

	global_position += mouse_before - mouse_after
	force_update_scroll()
