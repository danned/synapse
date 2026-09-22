class_name ThemeFactory
extends RefCounted

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_font_size("font_size", "Label", 18)
	theme.set_font_size("font_size", "Button", 17)
	theme.set_color("font_color", "Label", Color("d8edff"))
	theme.set_color("font_color", "Button", Color("d8edff"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("62f4d2"))
	theme.set_color("font_disabled_color", "Button", Color("668096"))
	theme.set_stylebox("normal", "Button", _box(Color("162746"), Color("315479"), 12, 1))
	theme.set_stylebox("hover", "Button", _box(Color("20395d"), Color("62f4d2"), 12, 2))
	theme.set_stylebox("pressed", "Button", _box(Color("102c3d"), Color("33c8ff"), 12, 2))
	theme.set_stylebox("disabled", "Button", _box(Color("111b2d"), Color("26384c"), 12, 1))
	theme.set_stylebox("normal", "Panel", _box(Color(0.035, 0.07, 0.13, 0.94), Color("203d5d"), 16, 1))
	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.035, 0.07, 0.13, 0.94), Color("203d5d"), 16, 1))
	theme.set_stylebox("normal", "LineEdit", _box(Color("0c1830"), Color("315479"), 8, 1))
	theme.set_color("font_color", "LineEdit", Color("d8edff"))
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme

static func panel_style(color: Color = Color(0.035, 0.07, 0.13, 0.96), border: Color = Color("203d5d"), radius: int = 16) -> StyleBoxFlat:
	return _box(color, border, radius, 1)

static func _box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

