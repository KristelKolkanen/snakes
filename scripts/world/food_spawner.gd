extends Node2D

const CELL := 256.0
const TARGET_COUNT := 1800

const PALETTE := [
	Color("#ff4d6d"), Color("#ffd23f"), Color("#4cc9f0"), Color("#b25cff"),
	Color("#5bff8a"), Color("#ff9f1c"), Color("#ff5cc8"), Color("#3a6bff"),
]

class Orb:
	var pos: Vector2
	var color: Color
	var value: int
	var radius: float
	var phase: float
	var born: float

	func _init(p: Vector2, c: Color, v: int, t: float) -> void:
		pos = p
		color = c
		value = v
		born = t
		radius = clampf(5.0 + sqrt(float(v)) * 2.5, 6.0, 18.0)
		phase = randf() * TAU

var cells := {}                          # Vector2i -> Array of Orb
var count := 0
var time := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for i in TARGET_COUNT:
		_spawn_ambient()


func _process(delta: float) -> void:
	time += delta
	# Refill ambient orbs a few per frame as they get eaten
	var missing := TARGET_COUNT - count
	for i in mini(missing, 8):
		_spawn_ambient()
	queue_redraw()


func _spawn_ambient() -> void:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * (Constants.ARENA_RADIUS - 100.0)
	var col: Color = PALETTE[rng.randi() % PALETTE.size()]
	var big := rng.randf() < 0.04
	add_orb(Vector2.from_angle(a) * r, col, 4 if big else 1)


func add_orb(pos: Vector2, color: Color, value: int = 1) -> void:
	var key := Vector2i(floori(pos.x / CELL), floori(pos.y / CELL))
	if not cells.has(key):
		cells[key] = []
	cells[key].append(Orb.new(pos, color, value, time))
	count += 1


# Removes every orb within `radius` of `p` and returns the total points eaten
func eat_around(p: Vector2, radius: float) -> int:
	var total := 0
	var r2 := radius * radius
	var x0 := floori((p.x - radius) / CELL)
	var x1 := floori((p.x + radius) / CELL)
	var y0 := floori((p.y - radius) / CELL)
	var y1 := floori((p.y + radius) / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if not cells.has(key):
				continue
			var arr: Array = cells[key]
			for i in range(arr.size() - 1, -1, -1):
				var o: Orb = arr[i]
				if o.pos.distance_squared_to(p) <= r2:
					total += o.value
					arr.remove_at(i)
					count -= 1
			if arr.is_empty():
				cells.erase(key)
	return total
	
# Returns the position of the most attractive orb within `radius`, or null if none.
# Big orbs and close orbs score higher.
func find_best(p: Vector2, radius: float):
	var best = null
	var best_score := 0.0
	var r2 := radius * radius
	var x0 := floori((p.x - radius) / CELL)
	var x1 := floori((p.x + radius) / CELL)
	var y0 := floori((p.y - radius) / CELL)
	var y1 := floori((p.y + radius) / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if not cells.has(key):
				continue
			for o: Orb in cells[key]:
				var d2 := o.pos.distance_squared_to(p)
				if d2 > r2:
					continue
				var score := float(o.value) / (sqrt(d2) + 80.0)
				if score > best_score:
					best_score = score
					best = o.pos
	return best

# A dead snake becomes a trail of orbs along its body
func drop_from_snake(segs: Array[Vector2], color: Color) -> void:
	var step := maxi(1, ceili(segs.size() / 120.0))   # cap the orb count on huge snakes
	var limit := Constants.ARENA_RADIUS - 40.0
	for i in range(0, segs.size(), step):
		var p := segs[i] + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))
		if p.length() > limit:
			p = p.normalized() * limit
		add_orb(p, color.lightened(rng.randf_range(0.0, 0.2)), 3 * step)


func _draw() -> void:
	# Only draw the orbs inside the camera view
	var inv := get_canvas_transform().affine_inverse()
	var view: Rect2 = (inv * get_viewport_rect()).grow(60.0)
	var x0 := floori(view.position.x / CELL)
	var x1 := floori(view.end.x / CELL)
	var y0 := floori(view.position.y / CELL)
	var y1 := floori(view.end.y / CELL)
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := Vector2i(cx, cy)
			if not cells.has(key):
				continue
			for o: Orb in cells[key]:
				var grow_in := clampf((time - o.born) * 4.0, 0.0, 1.0)
				var r := o.radius * grow_in * (1.0 + 0.08 * sin(time * 3.0 + o.phase))
				draw_circle(o.pos, r * 2.0, Color(o.color, 0.16))
				draw_circle(o.pos, r, o.color.darkened(0.5))
				draw_circle(o.pos, r * 0.82, o.color)
