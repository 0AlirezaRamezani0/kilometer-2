class_name InputPrompts
extends RefCounted

## Device-aware input prompts (XAG 112/114, Apple/Xbox prompt guidance).
## Every prompt shown to the player comes from this table, so the glyphs
## always match the bindings in project.godot and the active device
## reported by InputDeviceManager (keyboard/mouse, gamepad or touch).
##
## Gamepad glyphs use the common Xbox-style names; the button letter is
## always drawn inside the glyph, so colour is never the only cue.

enum Device { KEYBOARD = 0, GAMEPAD = 1, TOUCH = 2 }

## action -> [keyboard glyphs, gamepad glyphs]. Empty = no binding on that
## device (the prompt is hidden rather than showing a wrong key).
const GLYPHS := {
	"throttle": [["W", "↑"], ["RT", "A"]],
	"brake_reverse": [["S", "↓"], ["LT", "X"]],
	"steer": [["A", "D"], ["L"]],
	"handbrake": [["Space"], ["B"]],
	"reset_vehicle": [["R"], []],
	"pause_game": [["Esc"], ["Start"]],
	"toggle_headlights": [["H"], ["Y"]],
	"camera_reset": [["C"], ["R3"]],
	"photo_mode": [["F"], ["Back"]],
	"accept": [["Enter"], ["A"]],
	"back": [["Esc"], ["B"]],
	"page": [["Q", "E"], ["LB", "RB"]],
	"switch_car": [["←", "→"], ["LB", "RB"]],
	"navigate": [["↑", "↓"], ["▲", "▼"]],
}

## Xbox-convention tints for the four face buttons (paired with letters).
const FACE_COLORS := {
	"A": Color("#2EDB91"),
	"B": Color("#FF5B6E"),
	"X": Color("#56A8F0"),
	"Y": Color("#FFB627"),
}


static func current_device() -> int:
	match InputDeviceManager.current_mode:
		InputDeviceManager.Mode.GAMEPAD:
			return Device.GAMEPAD
		InputDeviceManager.Mode.TOUCH:
			return Device.TOUCH
	return Device.KEYBOARD


## Glyph list for an action on a device (touch has no glyphs).
static func glyphs(action: String, device: int = -1) -> Array:
	var dev := current_device() if device < 0 else device
	if dev == Device.TOUCH or not GLYPHS.has(action):
		return []
	return GLYPHS[action][0 if dev == Device.KEYBOARD else 1]


## Plain-text form used inside sentences, e.g. "Esc" or "Start".
static func text(action: String, device: int = -1) -> String:
	return " / ".join(glyphs(action, device))


## One prompt: [glyph(s)] + Persian label. Rebuilds itself when the active
## input device changes; hides itself when the action has no binding on
## the current device (and on touch unless touch_label is given).
class PromptChip extends HBoxContainer:
	var action: String = ""
	var label_text: String = ""
	var touch_label: String = ""
	var _tracker: InputDeviceManager = null

	func _init(p_action: String = "", p_label: String = "", p_touch_label: String = "") -> void:
		action = p_action
		label_text = p_label
		touch_label = p_touch_label
		add_theme_constant_override("separation", 6)
		layout_direction = Control.LAYOUT_DIRECTION_RTL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		_tracker = InputDeviceManager.ensure_tracker(self)
		if _tracker != null and not _tracker.mode_changed.is_connected(_on_mode):
			_tracker.mode_changed.connect(_on_mode)
		rebuild()

	func _exit_tree() -> void:
		if _tracker != null and is_instance_valid(_tracker) and _tracker.mode_changed.is_connected(_on_mode):
			_tracker.mode_changed.disconnect(_on_mode)

	func _on_mode(_m: int) -> void:
		rebuild()

	func rebuild() -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		var dev := InputPrompts.current_device()
		if dev == InputPrompts.Device.TOUCH:
			visible = not touch_label.is_empty()
			if visible:
				add_child(UiIcon.make("touch", 18, UiTheme.COLOR_ON_SURFACE_VARIANT))
				add_child(UiTheme.label(touch_label, "CaptionLabel"))
			return
		var gl := InputPrompts.glyphs(action, dev)
		visible = not gl.is_empty()
		if not visible:
			return
		# RTL row: the label reads first (right), glyphs follow on its left.
		add_child(UiTheme.label(label_text, "CaptionLabel"))
		var keys := HBoxContainer.new()
		keys.layout_direction = Control.LAYOUT_DIRECTION_LTR
		keys.add_theme_constant_override("separation", 4)
		keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for g in gl:
			keys.add_child(InputPrompts.Glyph.new(str(g), dev))
		add_child(keys)


## A single key/button glyph drawn in code (keycap or round face button).
class Glyph extends Control:
	var key: String = ""
	var device: int = 0

	func _init(p_key: String = "", p_device: int = 0) -> void:
		key = p_key
		device = p_device
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _ready() -> void:
		var f := UiTheme.font_bold()
		var w := 26.0
		if f != null:
			w = maxf(26.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14.0)
		if device == InputPrompts.Device.GAMEPAD and InputPrompts.FACE_COLORS.has(key):
			w = 26.0
		custom_minimum_size = Vector2(w, 26)

	func _draw() -> void:
		var f := UiTheme.font_bold()
		var r := Rect2(Vector2.ZERO, size)
		var fg := UiTheme.COLOR_ON_SURFACE
		if device == InputPrompts.Device.GAMEPAD and InputPrompts.FACE_COLORS.has(key):
			var c: Color = InputPrompts.FACE_COLORS[key]
			draw_circle(size * 0.5, size.y * 0.5, Color(0.04, 0.05, 0.07, 0.92))
			draw_arc(size * 0.5, size.y * 0.5 - 1.0, 0.0, TAU, 32, c, 2.0, true)
			fg = c
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.04, 0.05, 0.07, 0.92)
			sb.border_color = Color(1, 1, 1, 0.55)
			sb.set_border_width_all(1)
			sb.border_width_bottom = 3
			sb.set_corner_radius_all(6 if device == InputPrompts.Device.KEYBOARD else 13)
			sb.anti_aliasing = true
			draw_style_box(sb, r)
		if f != null:
			var ts := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			var pos := Vector2((size.x - ts.x) * 0.5, (size.y + f.get_ascent(14) - f.get_descent(14)) * 0.5 - 1.0)
			draw_string(f, pos, key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fg)
