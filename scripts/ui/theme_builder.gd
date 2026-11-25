class_name ThemeBuilder
## Builds the whole look of the app in code from one small colour palette,
## which means dark mode, light mode and high contrast all share the same layout rules.

const BASE_FONT_SIZE := 44
const CORNER := 20
const PADDING := 28

## The glowing Ephrocity wine red from the design doc, which becomes the accent colour in dark mode.
const WINE_GLOW := "#A33B4C"


static func palette(mode: String, high_contrast: bool) -> Dictionary:
	if high_contrast:
		if mode == "light":
			return _colors("#FFFFFF", "#FFFFFF", "#000000", "#000000", "#000000", "#0033CC", "#FFFFFF")
		return _colors("#000000", "#000000", "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFD400", "#000000")
	if mode == "light":
		return _colors("#F4F1F2", "#FFFFFF", "#D4CDD0", "#1A1A1F", "#5C5C68", "#8E2F3E", "#FFFFFF")
	return _colors("#0E0E11", "#1C1C22", "#34343F", "#ECECF1", "#A0A0AC", WINE_GLOW, "#FFFFFF")


static func _colors(bg: String, surface: String, border: String, text: String, muted: String, accent: String, on_accent: String) -> Dictionary:
	return {
		"bg": Color(bg), "surface": Color(surface), "border": Color(border),
		"text": Color(text), "muted": Color(muted), "accent": Color(accent), "on_accent": Color(on_accent),
	}


static func build(c: Dictionary, text_scale: float) -> Theme:
	var theme := Theme.new()
	var size := roundi(BASE_FONT_SIZE * text_scale)
	theme.default_font_size = size

	theme.set_color("font_color", "Label", c.text)
	_variation(theme, "TitleLabel", "Label", roundi(size * 2.6), c.text)
	_variation(theme, "HeadingLabel", "Label", roundi(size * 1.25), c.accent)
	_variation(theme, "MutedLabel", "Label", roundi(size * 0.8), c.muted)
	_variation(theme, "SplashLabel", "Label", roundi(BASE_FONT_SIZE * 2.2), c.text)
	_variation(theme, "BannerLabel", "Label", roundi(size * 1.6), c.text)
	theme.set_color("font_outline_color", "BannerLabel", Color.BLACK)
	theme.set_constant("outline_size", "BannerLabel", roundi(size * 0.25))
	theme.set_stylebox("normal", "ToastLabel", _box(c.surface, c.border, 3))
	theme.set_type_variation("ToastLabel", "Label")

	# Buttons are large and rounded so they are easy to hit with a thumb.
	var normal := _box(c.surface, c.border, 3)
	var pressed := _box(c.accent, c.accent, 3)
	var focus := _box(Color(0, 0, 0, 0), c.accent, 6)
	var disabled := _box(c.surface, c.border, 3)
	disabled.bg_color.a = 0.4
	for state in ["normal", "hover"]:
		theme.set_stylebox(state, "Button", normal)
	for state in ["pressed", "hover_pressed"]:
		theme.set_stylebox(state, "Button", pressed)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("disabled", "Button", disabled)
	for colour_name in ["font_color", "font_hover_color", "font_focus_color"]:
		theme.set_color(colour_name, "Button", c.text)
	for colour_name in ["font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(colour_name, "Button", c.on_accent)
	theme.set_color("font_disabled_color", "Button", c.muted)

	# The slider track and its handle scale with the text size, which keeps them easy to drag.
	var track := _box(c.border, c.border, 0)
	track.content_margin_top = size * 0.18
	track.content_margin_bottom = size * 0.18
	var filled := _box(c.accent, c.accent, 0)
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var handle := _circle(roundi(size * 1.1), c.accent, c.text)
	for icon_name in ["grabber", "grabber_highlight"]:
		theme.set_icon(icon_name, "HSlider", handle)
	theme.set_stylebox("focus", "HSlider", focus)

	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("focus", "LineEdit", focus)
	theme.set_color("font_color", "LineEdit", c.text)
	theme.set_color("caret_color", "LineEdit", c.accent)
	theme.set_stylebox("panel", "PanelContainer", _box(c.bg, c.border, 3))
	# Stat tiles are softly raised boxes, and a stripe is a faint band behind every other row of numbers.
	theme.set_type_variation("StatTile", "PanelContainer")
	theme.set_stylebox("panel", "StatTile", _box(c.surface, c.border, 2))
	theme.set_type_variation("Stripe", "PanelContainer")
	var stripe := _box(Color(c.text, 0.05), Color(0, 0, 0, 0), 0)
	stripe.set_content_margin_all(PADDING * 0.6)
	theme.set_stylebox("panel", "Stripe", stripe)
	theme.set_type_variation("Plain", "PanelContainer")
	var plain := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	plain.set_content_margin_all(PADDING * 0.6)
	theme.set_stylebox("panel", "Plain", plain)
	_variation(theme, "StatNumber", "Label", roundi(size * 1.7), c.accent)
	var track := _box(c.border, c.border, 0)
	track.set_content_margin_all(0)
	var bar_fill := _box(c.accent, c.accent, 0)
	bar_fill.set_content_margin_all(0)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)

	theme.set_constant("h_separation", "GridContainer", roundi(size * 0.3))
	theme.set_constant("v_separation", "GridContainer", roundi(size * 0.3))
	theme.set_constant("separation", "VBoxContainer", roundi(size * 0.6))
	theme.set_constant("separation", "HBoxContainer", roundi(size * 0.4))
	return theme


static func _variation(theme: Theme, name: String, base: String, font_size: int, colour: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_font_size("font_size", name, font_size)
	theme.set_color("font_color", name, colour)


static func _box(fill: Color, edge: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(CORNER)
	box.set_content_margin_all(PADDING)
	return box


## Draws a filled circle with an outline into a texture, which becomes the slider handle.
static func _circle(diameter: int, fill: Color, edge: Color) -> ImageTexture:
	var image := Image.create_empty(diameter, diameter, false, Image.FORMAT_RGBA8)
	var radius := diameter / 2.0
	for y in diameter:
		for x in diameter:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(radius, radius))
			if distance <= radius - 4:
				image.set_pixel(x, y, fill)
			elif distance <= radius:
				image.set_pixel(x, y, edge)
	return ImageTexture.create_from_image(image)
