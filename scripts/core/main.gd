extends Node2D

const SNAKE_SCENE := preload("res://scenes/snake/snake.tscn")
const BOT_COUNT := 15
const BOT_NAMES := [
	"Wormy", "Slinky", "Noodle", "Zigzag", "Viper", "Pixel", "Mochi", "Coil",
	"Ziggy", "Sprout", "Bean", "Comet", "Doodle", "Fang", "Loop", "Twist",
	"Nibble", "Rascal", "Slither", "Gizmo",
]

@onready var snake = $Snake
@onready var food = $Food
@onready var boost_button = $HUD/BoostButton
@onready var overlay = $HUD/Overlay
@onready var game_over = $GameOver

var snakes: Array = []                   # every living snake, player included


func _ready() -> void:
	var colors: Array = Skins.colors_of(SaveManager.skin_index)
	snake.skin_colors = colors
	snake.body_color = colors[0]
	snake.food = food
	snake.world = self
	snake.display_name = SaveManager.player_name
	snake.z_index = 1                    # player draws on top of the bots
	snakes.append(snake)
	boost_button.boost_changed.connect(snake.set_boost_requested)
	snake.died.connect(_on_snake_died)
	overlay.world = self
	for i in BOT_COUNT:
		_spawn_bot()


func _process(_delta: float) -> void:
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
	var reach: float = o.segments.size() * o.segment_spacing + 200.0
	if s.head.distance_squared_to(o.head) > reach * reach:
		return false
	var hit: float = (s.segment_radius + o.segment_radius) * 0.7
	var hit2: float = hit * hit
	var segs: Array = o.segments
	for i in range(1, segs.size(), 2):
		if s.head.distance_squared_to(segs[i]) < hit2:
			return true
	return false


func _find_spawn_point() -> Vector2:
	var p := Vector2.ZERO
	for attempt in 12:
		p = Vector2.from_angle(randf() * TAU) * randf_range(600.0, Constants.ARENA_RADIUS - 900.0)
		var ok := true
		for s in snakes:
			var min_dist := 1300.0 if s == snake else 500.0
			if s.alive and s.head.distance_to(p) < min_dist:
				ok = false
				break
		if ok:
			break
	return p


func _spawn_bot() -> void:
	var b = SNAKE_SCENE.instantiate()
	b.is_player = false
	b.food = food
	b.world = self
	b.display_name = BOT_NAMES[randi() % BOT_NAMES.size()]
	var colors: Array = Skins.colors_of(randi() % Skins.LIST.size())
	b.skin_colors = colors
	b.body_color = colors[0]
	b.start_segments = randi_range(10, 40)
	b.heading = randf() * TAU
	b.position = _find_spawn_point()
	b.ai = BotAI.new()
	b.ai.setup(b, self, Constants.DIFFICULTY[Constants.difficulty])
	b.died.connect(_on_snake_died)
	add_child(b)
	snakes.append(b)


func _on_snake_died(s) -> void:
	food.drop_from_snake(s.segments, s.body_color)
	snakes.erase(s)
	s.visible = false
	if s == snake:
		var score: int = s.get_score()
		var new_best := SaveManager.submit_score(score)
		Input.vibrate_handheld(250)      # haptic buzz on a phone, does nothing on the Mac
		await get_tree().create_timer(1.0).timeout
		game_over.show_result(score, SaveManager.high_score, new_best)
	else:
		s.queue_free()
		await get_tree().create_timer(2.0).timeout
		_spawn_bot()
