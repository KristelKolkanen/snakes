extends Node2D

signal died

@export var speed := 280.0
@export var boost_multiplier := 2.0
@export var turn_rate := 6.5            # radians per second
@export var segment_spacing := 20.0
@export var segment_radius := 18.0
@export var start_segments := 12
@export var min_segments := 10          # boost stops at this length
@export var boost_cost_per_sec := 2.0   # segments lost per second of boost
@export var body_color := Color("#5eead4")

var head := Vector2.ZERO
var heading := -PI / 2.0
var aim_angle := -PI / 2.0
var current_speed := 0.0
var segment_count := 0
var boost_requested := false
var boosting := false
var boost_debt := 0.0
var alive := true
var trail: Array[Vector2] = []          # head positions, newest first
var segments: Array[Vector2] = []       # computed body positions, head first

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	segment_count = start_segments
	head = position
	aim_angle = heading
	current_speed = speed
	var back := -Vector2.from_angle(heading)
	for i in range(int(segment_count * segment_spacing / 4.0) + 4):
		trail.append(head + back * i * 4.0)
	_update_segments()


func set_boost_requested(active: bool) -> void:
	boost_requested = active


func _process(delta: float) -> void:
	if not alive:
		return

	# Turn toward the aim direction with a limited turn rate
	var diff := angle_difference(heading, aim_angle)
	var max_turn := turn_rate * delta
	heading += clampf(diff, -max_turn, max_turn)

	# Boost: faster, but burns length
	boosting = (boost_requested or Input.is_key_pressed(KEY_SPACE)) and segment_count > min_segments
	var target_speed := speed * (boost_multiplier if boosting else 1.0)
	current_speed = move_toward(current_speed, target_speed, 1500.0 * delta)
	if boosting:
		boost_debt += boost_cost_per_sec * delta
		while boost_debt >= 1.0:
			boost_debt -= 1.0
			segment_count = maxi(segment_count - 1, min_segments)

	# Move and record the trail
	head += Vector2.from_angle(heading) * current_speed * delta
	trail.push_front(head)

	# Touching the arena edge kills the snake
	if head.length() + segment_radius >= Constants.ARENA_RADIUS:
		die()
		return

	_update_segments()

	# Camera follows the head and zooms out as the snake grows
	camera.position = head
	var z := clampf(1.0 - segment_count * 0.003, 0.5, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2(z, z), delta * 2.0)

	queue_redraw()


func die() -> void:
	if not alive:
		return
	alive = false
	died.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_aim_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventMouseMotion and not OS.has_feature("mobile"):
		_aim_at(event.position)          # desktop testing: just move the mouse
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		segment_count += 5               # temporary test: G grows the snake


# Convert a screen position to a steering direction relative to the head
func _aim_at(screen_pos: Vector2) -> void:
	var head_screen := get_viewport().canvas_transform * head
	var d := screen_pos - head_screen
	if d.length() > 20.0:
		aim_angle = d.angle()


func _update_segments() -> void:
	segments.clear()
	segments.append(trail[0])
	var travelled := 0.0
	var next_dist := segment_spacing
	for i in range(1, trail.size()):
		var a := trail[i - 1]
		var b := trail[i]
		var d := a.distance_to(b)
		if d < 0.001:
			continue
		while travelled + d >= next_dist and segments.size() < segment_count:
			segments.append(a.lerp(b, (next_dist - travelled) / d))
			next_dist += segment_spacing
		travelled += d
		if segments.size() >= segment_count:
			if i + 2 < trail.size():
				trail.resize(i + 2)
			break


func _draw() -> void:
	var col := body_color.lightened(0.25) if boosting else body_color
	for i in range(segments.size() - 1, -1, -1):
		var p := segments[i]
		draw_circle(p, segment_radius, col.darkened(0.4))
		draw_circle(p, segment_radius * 0.85, col)

	var fwd := Vector2.from_angle(heading)
	var side := fwd.orthogonal()
	for s in [-1.0, 1.0]:
		var eye: Vector2 = head + fwd * 6.0 + side * s * 8.0
		draw_circle(eye, 6.0, Color.WHITE)
		draw_circle(eye + fwd * 2.0, 3.0, Color.BLACK)
