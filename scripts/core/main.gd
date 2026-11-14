extends Node2D

const SNAKE_SCENE := preload("res://scenes/snake/snake.tscn")
const BOT_COUNT := 8

@onready var snake = $Snake
@onready var food = $Food
@onready var boost_button = $HUD/BoostButton

var snakes: Array = []                   # every living snake, player included


func _ready() -> void:
	snake.food = food
	snake.z_index = 1                    # player draws on top of the bots
	snakes.append(snake)
	boost_button.boost_changed.connect(snake.set_boost_requested)
	snake.died.connect(_on_snake_died)
	for i in BOT_COUNT:
		_spawn_bot()


func _process(_delta: float) -> void:
	# Temporary score display in the window title (a real HUD comes in Phase 5)
	if is_instance_valid(snake):
		get_window().title = "Score %d" % snake.get_score()

	# A snake dies when its head touches another snake's body
	var doomed: Array = []
	for s in snakes:
		if not s.alive:
			continue
		for o in snakes:
			if o == s or not o.alive:
				continue
			if _head_hits_body(s, o):
				doomed.append(s)
				break
	for s in doomed:
		s.die()


func _head_hits_body(s, o) -> bool:
	# Quick reject: a snake can't reach farther than its own length
	var reach: float = o.segments.size() * o.segment_spacing + 200.0
	if s.head.distance_squared_to(o.head) > reach * reach:
		return false
	var hit: float = (s.segment_radius + o.segment_radius) * 0.7
	var hit2: float = hit * hit
	var segs: Array = o.segments
	for i in range(1, segs.size(), 2):   # every second segment is enough
		if s.head.distance_squared_to(segs[i]) < hit2:
			return true
	return false


func _spawn_bot() -> void:
	var b = SNAKE_SCENE.instantiate()
	b.is_player = false
	b.food = food
	b.body_color = Color.from_hsv(randf(), 0.65, 1.0)
	b.start_segments = randi_range(10, 40)
	b.heading = randf() * TAU
	b.position = Vector2.from_angle(randf() * TAU) * randf_range(600.0, Constants.ARENA_RADIUS - 900.0)
	b.died.connect(_on_snake_died)
	add_child(b)
	snakes.append(b)


func _on_snake_died(s) -> void:
	food.drop_from_snake(s.segments, s.body_color)
	snakes.erase(s)
	s.visible = false
	if s == snake:
		# Temporary: restart after a moment. A game-over screen comes in Phase 5.
		await get_tree().create_timer(1.5).timeout
		get_tree().reload_current_scene()
	else:
		s.queue_free()
		await get_tree().create_timer(2.0).timeout
		_spawn_bot()
