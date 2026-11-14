extends Node2D

const SNAKE_SCENE := preload("res://scenes/snake/snake.tscn")
const TOTAL_SNAKES := 170                # you + 169 bots. Lower this if the game runs slowly
const NEAR_DIST := 3200.0
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
var pause_menu: PauseMenu
var frame_n := 0


func _ready() -> void:
	var colors: Array = Skins.colors_of(SaveManager.skin_index)
	snake.skin_colors = colors
	snake.body_color = colors[0]
	snake.food = food
	snake.speed_scale = Constants.DIFFICULTY[Constants.difficulty]["speed"] if Constants.PLAYER_SPEED_SCALES else 1.0
	snake.world = self
	snake.display_name = SaveManager.player_name
	snake.z_index = 1                    # player draws on top of the bots
	snakes.append(snake)
	boost_button.boost_changed.connect(snake.set_boost_requested)
	snake.died.connect(_on_snake_died)
	overlay.world = self
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.resumed.connect(_on_resumed)
	_spawn_initial_bots()


func _on_resumed() -> void:
	snake.reset_input()
	boost_button.reset()


# Auto-pause when the app goes to the background
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if pause_menu != null and is_instance_valid(snake) and snake.alive:
			pause_menu.open()


# Spawned in batches so the game doesn't hitch when it loads
func _spawn_initial_bots() -> void:
	var ring_angle := randf() * TAU
	for i in TOTAL_SNAKES - 1:
		_spawn_bot(_start_points_for(i), i, ring_angle)
		if i % 25 == 24:
			await get_tree().process_frame


# #1 is around 20k, #2 and #3 are 10-15k, then a group of mid-size snakes, then everyone else
func _start_points_for(index: int) -> float:
	if index == 0:
		return randf_range(19000.0, 21000.0)
	if index == 1:
		return randf_range(12500.0, 15000.0)
	if index == 2:
		return randf_range(10000.0, 12500.0)
	if index < 15:
		return randf_range(1500.0, 6000.0)
	return 60.0 + pow(randf(), 3.0) * 1400.0


func _process(_delta: float) -> void:
	frame_n += 1
	var doomed: Array = []
	var player_pos: Vector2 = snake.head
	var near2 := NEAR_DIST * NEAR_DIST
	for i in snakes.size():
		var s = snakes[i]
		if not s.alive:
			continue
		# Snakes near the player are checked every frame, distant ones every 4th frame
		if s.head.distance_squared_to(player_pos) > near2 and (frame_n + i) % 4 != 0:
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
	var sp: float = o.segment_spacing
	var segs: Array = o.segments
	var n := segs.size()
	var i := 1
	while i < n:
		var d: float = s.head.distance_to(segs[i])
		if d < hit:
			return true
		i += maxi(1, int((d - hit) / sp))     # can't be touching anything closer than this
	return false


func _find_spawn_point(check_others := true) -> Vector2:
	var p := Vector2.ZERO
	for attempt in 12:
		p = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * (Constants.ARENA_RADIUS - 1500.0)
		if p.distance_to(snake.head) < 1300.0:
			continue
		if not check_others:
			break
		var ok := true
		for s in snakes:
			if s != snake and s.alive and s.head.distance_to(p) < 500.0:
				ok = false
				break
		if ok:
			break
	return p


# Long snakes start as a ring: pick a ring center away from the player and put the head on the ring
func _place_coiled(b, length: float, center_angle: float) -> void:
	var rho := length / 4.5
	var max_c := Constants.ARENA_RADIUS - rho - 700.0
	var min_c := minf(rho + 1800.0, max_c)
	var c := Vector2.from_angle(center_angle) * randf_range(min_c, max_c)
	var u := Vector2.from_angle(randf() * TAU)
	b.position = c + u * rho
	b.heading = u.angle() - PI / 2.0


func _random_name() -> String:
	var n: String = BOT_NAMES[randi() % BOT_NAMES.size()]
	if randf() < 0.6:
		n += str(randi_range(2, 99))
	return n


# start_pts < 0 means a respawn, which starts small
func _spawn_bot(start_pts := -1.0, index := -1, ring_angle := 0.0) -> void:
	var b = SNAKE_SCENE.instantiate()
	b.is_player = false
	b.food = food
	b.world = self
	b.display_name = _random_name()
	var colors: Array = Skins.colors_of(randi() % Skins.LIST.size())
	b.skin_colors = colors
	b.body_color = colors[0]
	if start_pts < 0.0:
		start_pts = 60.0 + pow(randf(), 2.0) * 240.0
	b.start_points = start_pts
	b.heading = randf() * TAU
	var length: float = Constants.segments_for(start_pts) * b.segment_spacing
	if length >= Constants.COIL_LENGTH:
		var center_angle := randf() * TAU
		if index >= 0 and index < 3:
			center_angle = ring_angle + index * TAU / 3.0      # the three giants start far apart
		_place_coiled(b, length, center_angle)
	else:
		b.position = _find_spawn_point(index < 0)
	b.ai = BotAI.new()
	b.ai.setup(b, self, Constants.DIFFICULTY[Constants.difficulty])
	b.died.connect(_on_snake_died)
	add_child(b)
	snakes.append(b)


func _on_snake_died(s) -> void:
	food.drop_from_snake(s.segments, s.body_color, s.points, s.segment_radius)
	snakes.erase(s)
	s.visible = false
	if s == snake:
		pause_menu.hide_button()
		var score: int = s.get_score()
		var new_best := SaveManager.submit_score(score)
		Input.vibrate_handheld(250)
		await get_tree().create_timer(1.0).timeout
		game_over.show_result(score, SaveManager.high_score, new_best)
	else:
		s.queue_free()
		await get_tree().create_timer(2.0).timeout
		_spawn_bot()
