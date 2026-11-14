extends CanvasLayer

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var score_label: Label
var best_label: Label


func _ready() -> void:
	layer = 10
	visible = false

	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.82)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	box.add_child(UIKit.make_label("GAME OVER", 110, Color("#ff4d6d")))
	box.add_child(UIKit.make_label("Your length", 40, Color(1, 1, 1, 0.6)))
	score_label = UIKit.make_label("0", 160)
	box.add_child(score_label)
	best_label = UIKit.make_label("", 52, Color("#ffd23f"))
	box.add_child(best_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	var retry := UIKit.make_button("PLAY AGAIN", Color("#5eead4"))
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	box.add_child(retry)

	var menu := UIKit.make_button("MENU", Color("#8aa0ff"), Vector2(640, 120))
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	box.add_child(menu)


func show_result(score: int, best: int, new_best: bool) -> void:
	score_label.text = str(score)
	best_label.text = "NEW BEST!" if new_best else "Best: %d" % best
	visible = true
