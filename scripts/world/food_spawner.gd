extends Node2D

const CELL := 256.0
const TARGET_COUNT := 20000
const DEATH_DROP_FRACTION := 0.6

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
		radius = clampf(5.0 + sqrt(float(v)) * 3.0, 6.0, 50.0)
		phase = randf() * TAU

var cells := {}                          # Vector2i -> Array of Orb
var count := 0
var time := 0.0
var rng := RandomNumberGenerator.new()
var orb_tex: ImageTexture


func _ready() -> void:
	orb_tex = _make_orb_texture()
	rng.randomize()
	for i in TARGET_COUNT:
		_spawn_ambient()


func _process(delta: float) -> void:
	time += delta
	# Refill ambient orbs a few per frame as they get eaten
	var missing := TARGET_COUNT - count
	for i in mini(missing, 25):
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


# Soft glow + dark rim + bright core in grayscale, so draw's color tints it
func _make_orb_texture() -> ImageTexture:
	var n := 64
	var half := n / 2.0
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
			var c := Color(1, 1, 1, 0.16 * (1.0 - smoothstep(0.85, 1.0, d)))
			if d < 0.5:
				var edge := 1.0 - smoothstep(0.48, 0.5, d)
				var core := 1.0 - smoothstep(0.39, 0.41, d)
				var shade := lerpf(0.5, 1.0, core)
				c = Color(shade, shade, shade, maxf(edge, c.a))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


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
	
	
# Light magnet: orbs within `radius` of `p` drift toward it. Weak at the edge, stronger up close.
func attract(p: Vector2, radius: float, delta: float) -> void:
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
			var i := arr.size() - 1
			while i >= 0:
				var o: Orb = arr[i]
				var d2 := o.pos.distance_squared_to(p)
				if d2 < r2 and d2 > 1.0:
					var d := sqrt(d2)
					var pull := lerpf(120.0, 420.0, 1.0 - d / radius)    # pixels per second
					o.pos += (p - o.pos) / d * minf(pull * delta, d)
					var nk := Vector2i(floori(o.pos.x / CELL), floori(o.pos.y / CELL))
					if nk != key:                  # the orb crossed into another grid cell
						arr.remove_at(i)
						if not cells.has(nk):
							cells[nk] = []
						cells[nk].append(o)
				i -= 1
			if arr.is_empty():
				cells.erase(key)
	
	
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

# A dead snake becomes orbs along its body. Bigger snakes drop up to 160 orbs, each worth more.
func drop_from_snake(segs: Array[Vector2], color: Color, score: float, spread: float) -> void:
	if segs.is_empty():
		return
	var total := score * DEATH_DROP_FRACTION
	var count := clampi(int(total / 12.0), 12, 160)
	var value := maxi(1, roundi(total / count))
	var limit := Constants.ARENA_RADIUS - 40.0
	var jitter := spread * 0.6 + 8.0
	for k in count:
		var idx := mini(int(float(k) * segs.size() / count), segs.size() - 1)
		var p := segs[idx] + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		if p.length() > limit:
			p = p.normalized() * limit
		add_orb(p, color.lightened(rng.randf_range(0.0, 0.2)), value)


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
				var g := o.radius * grow_in * (1.0 + 0.08 * sin(time * 3.0 + o.phase)) * 2.0
				if g < 1.0:
					continue
				draw_texture_rect(orb_tex, Rect2(o.pos.x - g, o.pos.y - g, g * 2.0, g * 2.0), false, o.color)
