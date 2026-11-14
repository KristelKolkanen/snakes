extends Node2D

signal died(snake)

const LOD_DISTANCE := 3200.0            # bots farther than this from the player run in "low detail"
const LOD_FRAMES := 3                   # ...updating once every this many frames

@export var is_player := true
@export var speed := 280.0
@export var boost_multiplier := 2.0
@export var turn_rate := 6.5            # radians per second
@export var segment_spacing := 20.0
@export var base_radius := 18.0         # radius of a fresh snake
@export var max_width_factor := 3.2     # widest a snake can get (x base_radius)
@export var width_growth := 0.018       # width gained as the score grows
@export var min_zoom := 0.85            # most the camera ever zooms out
@export var eat_radius := 44.0
@export var start_points := 60.0        # 60 points = 12 segments
@export var min_segments := 10
@export var min_boost_points := 50.0    # boost stops at this score
@export var boost_segments_per_sec := 2.5       # body segments lost per second of boost...
@export var boost_segment_fraction := 0.012     # ...plus this fraction of the current length
@export var boost_drop_fraction := 0.3          # share of lost points that drops as orbs (0.33 = one third)
@export var magnet_extra := 40.0                # magnet reaches this far beyond the normal pickup area
@export var body_color := Color("#5eead4")

var food = null                         # assigned by Main
var world = null                        # assigned by Main
var ai: BotAI = null                    # only bots have one
var display_name := ""
var skin_colors: Array = []
var speed_scale := 1.0

var head := Vector2.ZERO
var heading := -PI / 2.0
var aim_angle := -PI / 2.0
var current_speed := 0.0
var points := 0.0
var segment_count := 0
var boost_requested := false
var boosting := false
var boost_debt := 0.0
var alive := true
var segment_radius := 18.0
var width_factor := 1.0
var lod_accum := 0.0
var lod_phase := 0
var trail: Array[Vector2] = []          # head positions, newest first
var segments: Array[Vector2] = []       # computed body positions, head first

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	if not is_player:
		camera.queue_free()
		camera = null
	points = start_points
	segment_count = _segments_for_points()
	lod_phase = get_instance_id() % LOD_FRAMES
	head = position
	position = Vector2.ZERO             # all positions are world coordinates
	aim_angle = heading
	current_speed = speed * speed_scale
	_build_start_trail()
	_update_segments()
	_update_width(0.0, true)


func get_score() -> int:
	return int(points)


func set_boost_requested(active: bool) -> void:
	boost_requested = active


func _segments_for_points() -> int:
	return maxi(min_segments, Constants.segments_for(points))


# Short snakes start in a straight line, long ones start coiled in an arc so they fit in the arena
func _build_start_trail() -> void:
	var step := 4.0
	var count := int(segment_count * segment_spacing / step) + 4
	var length := count * step
	var fwd := Vector2.from_angle(heading)
	if length < Constants.COIL_LENGTH:
		for i in count:
			trail.append(head - fwd * i * step)
	else:
		var rho := length / 4.5
		var c := head + fwd.orthogonal() * rho
		for i in count:
			trail.append(c + (head - c).rotated(i * step / rho))


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)           # a hitch must never teleport the snake
	if not alive:
		return

	# Far-away bots only update every few frames to save CPU
	if not is_player and points < 3000.0 and _is_far():
		lod_accum += delta
		if (Engine.get_process_frames() + lod_phase) % LOD_FRAMES != 0:
			return
		delta = lod_accum
		lod_accum = 0.0

	if ai != null:
		ai.update(delta)

	# Turn toward the aim direction with a limited turn rate
	var diff := angle_difference(heading, aim_angle)
	var max_turn := turn_rate * speed_scale * delta
	heading += clampf(diff, -max_turn, max_turn)

	# Boost: faster, but burns points and drops orbs from the tail
	var wants_boost := boost_requested or (is_player and Input.is_key_pressed(KEY_SPACE))
	boosting = wants_boost and points > min_boost_points
	var target_speed := speed * speed_scale * (boost_multiplier if boosting else 1.0)
	current_speed = move_toward(current_speed, target_speed, 1500.0 * delta)
	if boosting:
		var seg_f := Constants.segments_f(points)
		var loss := (boost_segments_per_sec + seg_f * boost_segment_fraction) * delta
		var new_points := maxf(Constants.points_for_segments(seg_f - loss), min_boost_points)
		boost_debt += (points - new_points) * boost_drop_fraction
		points = new_points
		# Drop orbs of mixed sizes until the owed amount is paid off
		var base := maxf(2.0, points / 800.0)
		while boost_debt >= base * 0.5:
			var v := base * (randf_range(0.4, 0.9) if randf() < 0.6 else randf_range(1.2, 2.5))
			var value := maxi(1, roundi(v))
			boost_debt -= value
			if food != null and not segments.is_empty():
				var tail := segments[segments.size() - 1]
				var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)) * width_factor
				food.add_orb(tail + jitter, body_color, value)

	# Move and record the trail
	head += Vector2.from_angle(heading) * current_speed * delta
	trail.push_front(head)

	# Touching the arena edge kills the snake
	if head.length() + segment_radius >= Constants.ARENA_RADIUS:
		die()
		return

	# Eat orbs: a light magnet pulls nearby ones in, then anything in the mouth is eaten
	if food != null:
		food.attract(head, (eat_radius + magnet_extra) * width_factor, delta)
		var gained: int = food.eat_around(head, eat_radius * width_factor)
		if gained > 0:
			points += gained

	segment_count = _segments_for_points()
	_update_width(delta)
	_update_segments()

	if camera != null:
		camera.position = head
		var t := (width_factor - 1.0) / (max_width_factor - 1.0)
		var z := lerpf(1.0, min_zoom, t)
		camera.zoom = camera.zoom.lerp(Vector2(z, z), delta * 2.0)

	if is_player or _on_screen():
		queue_redraw()


func _is_far() -> bool:
	if world == null or not is_instance_valid(world.snake):
		return false
	return head.distance_squared_to(world.snake.head) > LOD_DISTANCE * LOD_DISTANCE


func _on_screen() -> bool:
	var view: Rect2 = get_canvas_transform().affine_inverse() * get_viewport_rect()
	var reach := segments.size() * segment_spacing + segment_radius + 120.0
	return view.grow(reach).has_point(head)


func _update_width(delta: float, instant := false) -> void:
	var growth := sqrt(points + 100.0) - sqrt(160.0)      # 0 for a fresh snake
	var target := clampf(1.0 + growth * width_growth, 1.0, max_width_factor)
	width_factor = target if instant else lerpf(width_factor, target, minf(delta * 4.0, 1.0))
	segment_radius = base_radius * width_factor


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
		points += 250.0                  # temporary test: G adds 250 points


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
	var view: Rect2 = (get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(segment_radius + 120.0)
	for i in range(segments.size() - 1, -1, -1):
		var p := segments[i]
		if not view.has_point(p):
			continue
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
