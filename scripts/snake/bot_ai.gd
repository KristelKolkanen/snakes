class_name BotAI
extends RefCounted

enum State { WANDER, SEEK_FOOD, CHASE, AVOID }

var snake = null
var world = null
var vision := 900.0
var think_interval := 0.2
var aggression := 0.5
var boost_skill := 0.5
var state := State.WANDER
var think_timer := 0.0
var chase_target = null
var avoid_side := 1.0
var wander_offset := 0.0


func setup(owner_snake, main_node, params: Dictionary) -> void:
	snake = owner_snake
	world = main_node
	configure(params)
	think_timer = randf() * think_interval      # bots don't all think on the same frame


func configure(params: Dictionary) -> void:
	vision = params["vision"]
	think_interval = params["think"]
	aggression = params["aggression"]
	boost_skill = params["boost"]
	if snake != null:
		snake.speed_scale = params["speed"]

func update(delta: float) -> void:
	think_timer -= delta
	if think_timer > 0.0:
		return
	think_timer = think_interval * randf_range(0.8, 1.2)
	_think()


func _think() -> void:
	var s = snake
	s.boost_requested = false
	var head: Vector2 = s.head
	var fwd: Vector2 = Vector2.from_angle(s.heading)

	# 1. Stay away from the arena edge
	if head.length() > Constants.ARENA_RADIUS - 550.0:
		state = State.AVOID
		s.aim_angle = (-head).angle()
		return

	# 2. Dodge other snakes
	var push := _danger_push(fwd)
	if push != Vector2.ZERO:
		state = State.AVOID
		var side := fwd.orthogonal()
		var lateral := push.dot(side)
		if absf(lateral) > 0.15:
			avoid_side = signf(lateral)
		s.aim_angle = (fwd + side * avoid_side * 2.5).angle()
		return

	# 3. Hunt a smaller snake
	if chase_target != null and not _valid_prey(chase_target):
		chase_target = null
	if chase_target == null and randf() < aggression:
		chase_target = _find_prey()
	if chase_target != null:
		state = State.CHASE
		var o = chase_target
		var dist: float = head.distance_to(o.head)
		var lead: float = clampf(dist * 0.7, 100.0, 450.0)
		var aim_point: Vector2 = o.head + Vector2.from_angle(o.heading) * lead
		s.aim_angle = (aim_point - head).angle()
		if dist < 500.0 and s.segment_count > s.min_segments + 8 and randf() < boost_skill:
			s.boost_requested = true
		return

	# 4. Go for food
	var target = world.food.find_best(head, vision)
	if target != null:
		state = State.SEEK_FOOD
		s.aim_angle = (target - head).angle()
		return

	# 5. Wander
	state = State.WANDER
	wander_offset = clampf(wander_offset + randf_range(-0.5, 0.5), -1.0, 1.0)
	s.aim_angle = s.heading + wander_offset
	if head.length() > Constants.ARENA_RADIUS * 0.7:
		s.aim_angle = (-head).angle()


# Looks at two points ahead of the head and returns a vector pointing away from nearby bodies
func _danger_push(fwd: Vector2) -> Vector2:
	var s = snake
	var head: Vector2 = s.head
	var look: float = 140.0 + s.current_speed * 0.4
	var probes: Array[Vector2] = [head + fwd * look * 0.5, head + fwd * look]
	var push := Vector2.ZERO
	for o in world.snakes:
		if o == s or not o.alive:
			continue
		var reach: float = o.segments.size() * o.segment_spacing + look + 200.0
		if head.distance_squared_to(o.head) > reach * reach:
			continue
		var thr: float = s.segment_radius + o.segment_radius + 25.0
		var thr2: float = thr * thr
		var segs: Array = o.segments
		for i in range(0, segs.size(), 2):
			var seg: Vector2 = segs[i]
			for p in probes:
				var d2: float = p.distance_squared_to(seg)
				if d2 < thr2:
					var d: float = maxf(sqrt(d2), 1.0)
					push += (p - seg) / d * (1.0 - d / thr)
	return push


func _valid_prey(o) -> bool:
	if not is_instance_valid(o) or not o.alive:
		return false
	if o.segment_count >= snake.segment_count * 0.85:
		return false
	return snake.head.distance_to(o.head) < vision * 1.4


func _find_prey():
	var best = null
	var best_d := vision
	for o in world.snakes:
		if o == snake or not _valid_prey(o):
			continue
		var d: float = snake.head.distance_to(o.head)
		if d < best_d:
			best_d = d
			best = o
	return best
