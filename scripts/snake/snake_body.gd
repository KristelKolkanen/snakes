extends Node2D

signal died(snake)

const POINTS_PER_SEGMENT := 5

@export var is_player := true
@export var speed := 280.0
@export var boost_multiplier := 2.0
@export var turn_rate := 6.5            # radians per second
@export var segment_spacing := 20.0
@export var base_radius := 18.0         # radius of a fresh snake
@export var max_width_factor := 2.2     # widest a snake can get (x base_radius)
@export var width_growth := 0.008       # extra width per segment beyond the start length
@export var min_zoom := 0.85            # most the camera ever zooms out    # radians per second
@export var eat_radius := 44.0
@export var start_segments := 12
@export var min_segments := 10          # boost stops at this length
@export var boost_cost_per_sec := 2.0   # segments lost per second of boost
@export var body_color := Color("#5eead4")

var food = null                         # assigned by Main
var head := Vector2.ZERO
var heading := -PI / 2.0
var aim_angle := -PI / 2.0
var current_speed := 0.0
var segment_count := 0
var growth_points := 0
var boost_requested := false
var boosting := false
var boost_debt := 0.0
var alive := true
var wander_timer := 0.0
var trail: Array[Vector2] = []          # head positions, newest first
var segments: Array[Vector2] = []       # computed body positions, head first
var segment_radius := 18.0
var width_factor := 1.0
var world = null                        # assigned by Main
var ai: BotAI = null                    # only bots have one
var display_name := ""
var skin_colors: Array = []

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if not is_player:
		camera.queue_free()
		camera = null
	segment_count = start_segments
	head = position
	position = Vector2.ZERO             # all positions are world coordinates
	aim_angle = heading
	current_speed = speed
	var back := -Vector2.from_angle(heading)
	for i in range(int(segment_count * segment_spacing / 4.0) + 4):
		trail.append(head + back * i * 4.0)
	_update_segments()
	_update_width(0.0, true)


func get_score() -> int:
	return segment_count * POINTS_PER_SEGMENT + growth_points


func set_boost_requested(active: bool) -> void:
	boost_requested = active
	
func _update_width(delta: float, instant := false) -> void:
	var target := clampf(1.0 + (segment_count - start_segments) * width_growth, 1.0, max_width_factor)
	width_factor = target if instant else lerpf(width_factor, target, delta * 4.0)
	segment_radius = base_radius * width_factor


func _process(delta: float) -> void:
	if not alive:
		return

	if ai != null:
		ai.update(delta)

	# Turn toward the aim direction with a limited turn rate
	var diff := angle_difference(heading, aim_angle)
	var max_turn := turn_rate * delta
	heading += clampf(diff, -max_turn, max_turn)

	# Boost: faster, but burns length and drops small orbs
	var wants_boost := boost_requested or (is_player and Input.is_key_pressed(KEY_SPACE))
	boosting = wants_boost and segment_count > min_segments
	var target_speed := speed * (boost_multiplier if boosting else 1.0)
	current_speed = move_toward(current_speed, target_speed, 1500.0 * delta)
	if boosting:
		boost_debt += boost_cost_per_sec * delta
		while boost_debt >= 1.0:
			boost_debt -= 1.0
			segment_count = maxi(segment_count - 1, min_segments)
			if food != null and not segments.is_empty():
				food.add_orb(segments[segments.size() - 1], body_color, 3)

	# Move and record the trail
	head += Vector2.from_angle(heading) * current_speed * delta
	trail.push_front(head)

	# Touching the arena edge kills the snake
	if head.length() + segment_radius >= Constants.ARENA_RADIUS:
		die()
		return

	# Eat orbs: every 5 points of food adds one segment
	if food != null:
		var gained: int = food.eat_around(head, eat_radius * width_factor)
		if gained > 0:
			growth_points += gained
			while growth_points >= POINTS_PER_SEGMENT:
				growth_points -= POINTS_PER_SEGMENT
				segment_count += 1

	_update_width(delta)
	_update_segments()

	if camera != null:
		camera.position = head
		var t := (width_factor - 1.0) / (max_width_factor - 1.0)
		var z := lerpf(1.0, min_zoom, t)
		camera.zoom = camera.zoom.lerp(Vector2(z, z), delta * 2.0)

	queue_redraw()


func die() -> void:
	if not alive:
		return
	alive = false
	died.emit(self)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player:
		return
	if event is InputEventScreenDrag:
		_aim_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_aim_at(event.position)
	elif event is InputEventMouseMotion and not OS.has_feature("mobile"):
		_aim_at(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_G:
		segment_count += 5               # temporary test: G grows the snake


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
	for i in range(segments.size() - 1, -1, -1):
		var p := segments[i]
		var c: Color = body_color
		if skin_colors.size() > 1:
			c = skin_colors[floori(i / 3.0) % skin_colors.size()]
		if boosting:
			c = c.lightened(0.25)
		draw_circle(p, segment_radius, c.darkened(0.4))
		draw_circle(p, segment_radius * 0.85, c)

	var fwd := Vector2.from_angle(heading)
	var side := fwd.orthogonal()
	for s in [-1.0, 1.0]:
		var eye: Vector2 = head + fwd * 6.0 * width_factor + side * s * 8.0 * width_factor
		draw_circle(eye, 6.0 * width_factor, Color.WHITE)
		draw_circle(eye + fwd * 2.0 * width_factor, 3.0 * width_factor, Color.BLACK)
		
	if display_name != "":
		var font := ThemeDB.fallback_font
		draw_string(font, head + Vector2(-100.0, -segment_radius - 20.0), display_name,
				HORIZONTAL_ALIGNMENT_CENTER, 200.0, 28, Color(1, 1, 1, 0.85))
