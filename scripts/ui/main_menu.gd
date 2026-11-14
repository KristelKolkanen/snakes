extends Control

const GAME_SCENE := "res://scenes/main/main.tscn"
const DIFF_NAMES := ["easy", "normal", "hard"]

var name_edit: LineEdit
var preview: Control
var skin_grid: GridContainer
var diff_row: HBoxContainer
var best_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("#0f1424")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	box.add_child(UIKit.make_label("WORM ARENA", 110, Color("#5eead4")))   # rename to your own title

	preview = Control.new()
	preview.custom_minimum_size = Vector2(800, 200)
	preview.draw.connect(_draw_preview)
	box.add_child(preview)

	name_edit = LineEdit.new()
	name_edit.text = SaveManager.player_name
	name_edit.placeholder_text = "Your nickname"
	name_edit.max_length = 12
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(640, 120)
	name_edit.add_theme_font_size_override("font_size", 56)
	name_edit.text_submitted.connect(func(_t): name_edit.release_focus())
	box.add_child(name_edit)

	box.add_child(UIKit.make_label("Skin", 40, Color(1, 1, 1, 0.6)))
	skin_grid = GridContainer.new()
	skin_grid.columns = 4
	skin_grid.add_theme_constant_override("h_separation", 16)
	skin_grid.add_theme_constant_override("v_separation", 16)
	box.add_child(skin_grid)

	box.add_child(UIKit.make_label("Bots", 40, Color(1, 1, 1, 0.6)))
	diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 16)
	box.add_child(diff_row)

	best_label = UIKit.make_label("", 44, Color("#ffd23f"))
	box.add_child(best_label)

	var play := UIKit.make_button("PLAY", Color("#5eead4"), Vector2(640, 170), 72)
	play.pressed.connect(_on_play)
	box.add_child(play)

	_build_skins()
	_build_difficulty()
	best_label.text = "Best: %d" % SaveManager.high_score


func _draw_preview() -> void:
	var colors: Array = Skins.colors_of(SaveManager.skin_index)
	var count := 16
	var r := 40.0
	var spacing := 44.0
	var start_x := preview.size.x / 2.0 - (count - 1) * spacing / 2.0
	var cy := preview.size.y / 2.0
	for i in range(count - 1, -1, -1):
		var c: Color = colors[floori(i / 3.0) % colors.size()]
		var p := Vector2(start_x + i * spacing, cy + sin(i * 0.5) * 22.0)
		preview.draw_circle(p, r, c.darkened(0.4))
		preview.draw_circle(p, r * 0.85, c)
		if i == 0:                       # head faces left, with eyes
			var k := r / 18.0
			for s in [-1.0, 1.0]:
				var eye := p + Vector2(-6.0, s * 8.0) * k
				preview.draw_circle(eye, 6.0 * k, Color.WHITE)
				preview.draw_circle(eye + Vector2(-2.0, 0.0) * k, 3.0 * k, Color.BLACK)


func _build_skins() -> void:
	for c in skin_grid.get_children():
		skin_grid.remove_child(c)
		c.queue_free()
	for i in Skins.LIST.size():
		var skin: Dictionary = Skins.LIST[i]
		var unlocked := Skins.is_unlocked(i, SaveManager.high_score)
		var colors: Array = skin["colors"]
		var text: String = skin["name"] if unlocked else "Locked\n%d" % skin["unlock"]
		var b := UIKit.make_button(text, colors[0], Vector2(190, 120), 34, i == SaveManager.skin_index)
		b.disabled = not unlocked
		b.pressed.connect(_on_skin_pressed.bind(i))
		skin_grid.add_child(b)


func _build_difficulty() -> void:
	for c in diff_row.get_children():
		diff_row.remove_child(c)
		c.queue_free()
	for d: String in DIFF_NAMES:
		var b := UIKit.make_button(d.capitalize(), Color("#8aa0ff"), Vector2(250, 100), 40,
				d == Constants.difficulty)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_difficulty_pressed.bind(d))
		diff_row.add_child(b)


func _on_skin_pressed(i: int) -> void:
	SaveManager.skin_index = i
	SaveManager.save_data()
	_build_skins()
	preview.queue_redraw()


func _on_difficulty_pressed(d: String) -> void:
	Constants.difficulty = d
	SaveManager.difficulty = d
	SaveManager.save_data()
	_build_difficulty()


func _on_play() -> void:
	var n := name_edit.text.strip_edges()
	SaveManager.player_name = n if n != "" else "YOU"
	SaveManager.save_data()
	get_tree().change_scene_to_file(GAME_SCENE)
