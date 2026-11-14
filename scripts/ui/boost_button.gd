extends Control

signal boost_changed(active: bool)

var touch_index := -1
var is_down := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := 100.0 + UIKit.safe_insets(self).w     # stays above the home bar

	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 50.0
	offset_right = 250.0
	offset_top = -(bottom + 200.0)
	offset_bottom = -bottom


func reset() -> void:
	touch_index = -1
	if is_down:
		_set_down(false)


# Handles its own touches so boosting and steering work with two fingers at once
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and get_global_rect().grow(30.0).has_point(event.position):
			touch_index = event.index
			_set_down(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
			_set_down(false)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		get_viewport().set_input_as_handled()


func _set_down(value: bool) -> void:
	is_down = value
	queue_redraw()
	boost_changed.emit(value)


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.28 if is_down else 0.14)
	box.set_corner_radius_all(48)
	draw_style_box(box, Rect2(Vector2.ZERO, size))

	var col := Color(1, 1, 1, 0.8 if is_down else 0.45)
	var c := size / 2.0
	for i in 3:
		var y := c.y + (i - 1) * 40.0
		draw_polyline(PackedVector2Array([
			Vector2(c.x - 38.0, y + 12.0),
			Vector2(c.x, y - 14.0),
			Vector2(c.x + 38.0, y + 12.0),
		]), col, 10.0, true)
