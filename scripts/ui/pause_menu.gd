class_name PauseMenu
extends CanvasLayer

signal resumed

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var button: Button
var panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # keeps working while the game is paused
	layer = 8

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Pause button, top center
	button = UIKit.make_button("II", Color(1, 1, 1, 0.3), Vector2(100, 100), 48)
	button.anchor_left = 0.5
	button.anchor_right = 0.5
	var top := 30.0 + UIKit.safe_insets(root).y
	button.offset_left = -50.0
	button.offset_right = 50.0
	button.offset_top = top
	button.offset_bottom = top + 100.0
	button.pressed.connect(open)
	root.add_child(button)

	# Pause panel
	panel = Control.new()
	panel.visible = false
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.09, 0.82)
	panel.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	box.add_child(UIKit.make_label("PAUSED", 120))
	var resume := UIKit.make_button("RESUME", Color("#5eead4"), Vector2(640, 150), 64)
	resume.pressed.connect(close)
	box.add_child(resume)
	var menu := UIKit.make_button("MENU", Color("#8aa0ff"), Vector2(640, 120))
	menu.pressed.connect(_on_menu)
	box.add_child(menu)


func open() -> void:
	if panel.visible:
		return
	panel.visible = true
	button.visible = false
	get_tree().paused = true


func close() -> void:
	panel.visible = false
	button.visible = true
	get_tree().paused = false
	resumed.emit()


func hide_button() -> void:
	button.visible = false


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
