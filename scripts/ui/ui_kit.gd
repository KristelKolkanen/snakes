class_name UIKit


static func make_label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_button(text: String, color: Color, min_size := Vector2(640, 140),
		font_size := 56, outlined := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	var dark := Color("#0f1424")
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, dark)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))

	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(36)
	if outlined:
		normal.set_border_width_all(8)
		normal.border_color = Color.WHITE
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.25)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(1, 1, 1, 0.1)
	disabled.set_border_width_all(0)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b
	
# Space (in game pixels) to keep free for the notch, rounded corners and home bar.
# Returns Vector4(left, top, right, bottom). All zeros on the Mac.
static func safe_insets(ctrl: Control) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var vp := ctrl.get_viewport().get_visible_rect().size
	var sa := DisplayServer.get_display_safe_area()
	var sx := vp.x / win.x
	var sy := vp.y / win.y
	return Vector4(
		sa.position.x * sx,
		sa.position.y * sy,
		maxf(win.x - (sa.position.x + sa.size.x), 0.0) * sx,
		maxf(win.y - (sa.position.y + sa.size.y), 0.0) * sy)
