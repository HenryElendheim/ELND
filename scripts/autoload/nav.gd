extends CanvasLayer
## Moves between screens with a short fade, shows short messages, and handles the Android back button.

const FADE_TIME := 0.35
const TOAST_TIME := 2.5

## Settings handed to the next screen, such as which mode the battle screen should run.
var params := {}

var _fade := ColorRect.new()
var _toast := Label.new()
var _banner := Label.new()
var _banner_tween: Tween

const BANNER_TIME := 1.2


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)

	_toast.theme_type_variation = "ToastLabel"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_top = -160
	_toast.offset_bottom = -160
	_toast.custom_minimum_size.x = 900
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)

	_banner.theme_type_variation = "BannerLabel"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)


## Shows a big message in the middle of the screen that fades away, such as "Not enough Ephrocity".
## With reduced motion it simply disappears after the same time instead of fading.
func banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	if Settings.reduced_motion():
		_banner_tween.tween_interval(BANNER_TIME)
	else:
		_banner_tween.tween_interval(BANNER_TIME * 0.4)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, BANNER_TIME * 0.6)
	_banner_tween.tween_callback(_banner.hide)


## Opens a screen. With reduced motion turned on the switch is instant, otherwise it fades out and back in.
func go(scene_path: String, next_params := {}) -> void:
	params = next_params
	if Settings.reduced_motion():
		get_tree().change_scene_to_file(scene_path)
		return
	_fade.color = Settings.palette().bg
	_fade.color.a = 0.0
	await _tween_fade(1.0)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await _tween_fade(0.0)


## Shows a short message near the bottom of the screen, then hides it again.
func toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	var hide_after := get_tree().create_timer(TOAST_TIME)
	await hide_after.timeout
	if _toast.text != text:
		return
	if not Settings.reduced_motion():
		await create_tween().tween_property(_toast, "modulate:a", 0.0, FADE_TIME).finished
	_toast.visible = false


func _tween_fade(alpha: float) -> void:
	await create_tween().tween_property(_fade, "color:a", alpha, FADE_TIME).finished


## The Android back gesture asks the current screen to go back. A screen that has nowhere to go back to closes the app.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var screen := get_tree().current_scene
	if screen != null and screen.has_method("go_back") and screen.go_back():
		return
	get_tree().quit()
