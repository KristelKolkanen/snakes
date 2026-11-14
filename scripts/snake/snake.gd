extends Node2D

@export var speed := 280.0
@export var turn_rate := 3.2            # radians per second
@export var segment_spacing := 12.0
@export var segment_radius := 18.0
@export var start_segments := 12
@export var body_color := Color("#5eead4")

var head := Vector2.ZERO
var heading := -PI / 2.0                # start facing up
var segment_count := 0
var trail: Array[Vector2] = []          # head positions, newest first
var segments: Array[Vector2] = []       # computed body positions, head first

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	segment_count = start_segments
	head = position
	# Prefill the trail straight behind the head
	var back := -Vector2.from_angle(heading)
	for i in range(int(segment_count * segment_spacing / 4.0) + 4):
		trail.append(head + back * i * 4.0)
	_update_segments()


func _process(delta: float) -> void:
	# Steer toward the pointer with a limited turn rate
	var to_target := get_global_mouse_position() - head
	if to_target.length() > 8.0:
		var diff := angle_difference(heading, to_target.angle())
		var max_turn := turn_rate * delta
		heading += clampf(diff, -max_turn, max_turn)

	# Move forward and record the trail
	head += Vector2.from_angle(heading) * speed * delta
	trail.push_front(head)
	_update_segments()

	# Camera follows the head and zooms out as the snake grows
	camera.position = head
	var z := clampf(1.0 - segment_count * 0.003, 0.5, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2(z, z), delta * 2.0)

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Temporary test: Space adds 5 segments
	if event.is_action_pressed("ui_accept"):
		segment_count += 5


# Walk along the trail and drop a segment every `segment_spacing` pixels
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
				trail.resize(i + 2)   # drop trail points we no longer need
			break


func _draw() -> void:
	# Tail first so the head ends up on top
	for i in range(segments.size() - 1, -1, -1):
		var p := segments[i]
		draw_circle(p, segment_radius, body_color.darkened(0.4))
		draw_circle(p, segment_radius * 0.85, body_color)

	# Eyes
	var fwd := Vector2.from_angle(heading)
	var side := fwd.orthogonal()
	for s in [-1.0, 1.0]:
		var eye: Vector2 = head + fwd * 6.0 + side * s * 8.0
		draw_circle(eye, 6.0, Color.WHITE)
		draw_circle(eye + fwd * 2.0, 3.0, Color.BLACK)
