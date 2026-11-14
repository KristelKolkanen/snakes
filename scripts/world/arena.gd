extends Node2D

const TILE_SIZE := 512
const BG_COLOR := Color("#0f1424")
const INK_COLOR := Color("#1b2338")
const COVER := 2400.0       # how far the world is drawn past the arena edge

var tile: ImageTexture


func _ready() -> void:
	z_index = -10
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tile = _make_tile()
	queue_redraw()


func _draw() -> void:
	if tile == null:
		return
	var r := Constants.ARENA_RADIUS
	var half := r + COVER
	draw_texture_rect(tile, Rect2(-half, -half, half * 2.0, half * 2.0), true)
	# Dark void outside the arena
	draw_arc(Vector2.ZERO, r + COVER / 2.0, 0.0, TAU, 256, Color(0.02, 0.03, 0.06, 0.85), COVER)
	# Glowing red boundary
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 256, Color(1.0, 0.23, 0.36, 0.18), 60.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 256, Color(1.0, 0.23, 0.36, 1.0), 12.0, true)


# Generates a seamless squiggle pattern so you need no image files yet
func _make_tile() -> ImageTexture:
	var img := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(BG_COLOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for s in 70:
		var p := Vector2(rng.randf() * TILE_SIZE, rng.randf() * TILE_SIZE)
		var a := rng.randf() * TAU
		var curve := rng.randf_range(0.08, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0)
		var steps := rng.randi_range(14, 30)
		for i in steps:
			_stamp(img, p, 5)
			p += Vector2.from_angle(a) * 2.5
			a += curve
			if i == int(steps * 0.5):
				curve = -curve        # makes an S-shaped squiggle
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _stamp(img: Image, c: Vector2, r: int) -> void:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(posmod(int(c.x) + dx, TILE_SIZE), posmod(int(c.y) + dy, TILE_SIZE), INK_COLOR)
