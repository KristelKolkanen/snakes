extends Control

var world = null                         # assigned by Main
var board: Array = []
var board_timer := 0.0
var panel_style := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_style.bg_color = Color(0, 0, 0, 0.35)
	panel_style.set_corner_radius_all(24)


func _process(delta: float) -> void:
	if world == null:
		return
	board_timer -= delta
	if board_timer <= 0.0:
		board_timer = 0.2
		board = world.snakes.duplicate()
		board.sort_custom(func(a, b): return a.get_score() > b.get_score())
	queue_redraw()


# Keeps the HUD out from under the notch / Dynamic Island on a real phone
func _safe_top() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return float(DisplayServer.get_display_safe_area().position.y) * size.y / float(win.y)


func _draw() -> void:
	if world == null or not is_instance_valid(world.snake):
		return
	var font := ThemeDB.fallback_font
	var me = world.snake
	var top := 30.0 + _safe_top()

	# Your length
	draw_string(font, Vector2(40.0, top + 36.0), "Your length",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.6))
	draw_string(font, Vector2(40.0, top + 112.0), str(me.get_score()),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color.WHITE)

	# Living snakes, best first
	var list: Array = []
	for s in board:
		if is_instance_valid(s) and s.alive:
			list.append(s)
	var rank := list.find(me) + 1
	var rows := mini(list.size(), 8)
	var extra := 1 if rank > rows else 0

	# Leaderboard panel
	var row_h := 44.0
	var px := size.x - 440.0
	draw_style_box(panel_style, Rect2(px - 20.0, top, 440.0, 40.0 + (rows + extra + 1) * row_h))
	var y := top + 44.0
	draw_string(font, Vector2(px, y), "Leaderboard", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.6))
	if rank > 0:
		draw_string(font, Vector2(px + 200.0, y), "%d / %d" % [rank, list.size()],
				HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 28, Color("#5eead4"))
	y += row_h
	for i in rows:
		_draw_row(font, px, y, i + 1, list[i], list[i] == me)
		y += row_h
	if extra == 1 and rank > 0:
		_draw_row(font, px, y + 6.0, rank, me, true)

	_draw_leader_marker(list, me)


func _draw_row(font: Font, x: float, y: float, rank: int, s, mine: bool) -> void:
	var col := Color("#5eead4") if mine else Color(1, 1, 1, 0.85)
	draw_string(font, Vector2(x, y), str(rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	draw_string(font, Vector2(x + 50.0, y), s.display_name.left(10), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	draw_string(font, Vector2(x + 250.0, y), str(s.get_score()), HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 30, col)


# Crown above the leader's head, or at the screen edge with an arrow if they're off-screen
func _draw_leader_marker(list: Array, me) -> void:
	if list.is_empty() or list[0] == me:
		return
	var leader = list[0]
	var xf := get_viewport().canvas_transform
	var sp: Vector2 = xf * leader.head
	var center := size / 2.0
	var dir := sp - center
	var half := center - Vector2(110.0, 190.0)
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	if k >= 1.0:
		var zoom := xf.get_scale().y
		_draw_crown(sp + Vector2(0.0, -(leader.segment_radius + 85.0) * zoom), 22.0)
		return
	var n := dir.normalized()
	var pos := center + dir * k
	_draw_crown(pos, 30.0)
	var tip := pos + n * 62.0
	var side := n.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		tip, tip - n * 26.0 + side * 16.0, tip - n * 26.0 - side * 16.0,
	]), Color.WHITE)


func _draw_crown(c: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-1.0, 0.7) * s, c + Vector2(-1.0, -0.6) * s, c + Vector2(-0.5, 0.0) * s,
		c + Vector2(0.0, -0.9) * s, c + Vector2(0.5, 0.0) * s, c + Vector2(1.0, -0.6) * s,
		c + Vector2(1.0, 0.7) * s,
	]), Color("#ffd23f"))
