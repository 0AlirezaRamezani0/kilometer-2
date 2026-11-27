class_name VehicleInputMap
extends RefCounted

## Ensures all driving and reset InputMap actions exist with desktop
## keyboard bindings (WASD + Arrow keys + Space + R), while allowing
## Android touch controls and automated test harnesses to share the same model.
## Pass 3: there is deliberately NO cycle_camera / cycle_vehicle action —
## the camera has a single follow behavior and the car is chosen in the
## main-menu showroom, then locked for the session.
## Kilometer 2: actions are also persisted in project.godot ([input] section)
## so they are visible in Project Settings > Input Map before runtime; this
## runtime ensure remains as a safety net for older checkouts.

const ACTIONS := [
	"throttle",
	"brake_reverse",
	"steer_left",
	"steer_right",
	"handbrake",
	"reset_vehicle",
	"pause_game",
	"toggle_headlights",
	"camera_reset",
	"photo_mode",
	"menu_accept",
	"menu_back",
	"menu_up",
	"menu_down",
	"menu_left",
	"menu_right",
	"camera_orbit_x",
	"camera_orbit_y",
	"ui_page_left",
	"ui_page_right",
]


static func ensure_actions() -> void:
	_add_key_action("throttle", [KEY_W, KEY_UP])
	_add_key_action("brake_reverse", [KEY_S, KEY_DOWN])
	_add_key_action("steer_left", [KEY_A, KEY_LEFT])
	_add_key_action("steer_right", [KEY_D, KEY_RIGHT])
	_add_key_action("handbrake", [KEY_SPACE])
	_add_key_action("reset_vehicle", [KEY_R])
	_add_key_action("pause_game", [KEY_ESCAPE, KEY_P])
	_add_key_action("toggle_headlights", [KEY_H])
	_add_joypad_button_action("toggle_headlights", JOY_BUTTON_Y)
	# --- K2-REDESIGN-002 gamepad bindings (keyboard bindings stay) ---
	_add_joypad_motion_action("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joypad_motion_action("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joypad_motion_action("throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joypad_button_action("throttle", JOY_BUTTON_A)
	_add_joypad_motion_action("brake_reverse", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joypad_button_action("brake_reverse", JOY_BUTTON_X)
	_add_joypad_button_action("handbrake", JOY_BUTTON_B)
	_add_joypad_button_action("pause_game", JOY_BUTTON_START)
	_add_key_action("camera_reset", [KEY_C])
	_add_joypad_button_action("camera_reset", JOY_BUTTON_RIGHT_STICK)
	_add_key_action("photo_mode", [KEY_F])
	_add_joypad_button_action("photo_mode", JOY_BUTTON_BACK)
	_add_key_action("menu_accept", [KEY_ENTER])
	_add_joypad_button_action("menu_accept", JOY_BUTTON_A)
	_add_key_action("menu_back", [KEY_BACKSPACE])
	_add_joypad_button_action("menu_back", JOY_BUTTON_B)
	_add_key_action("menu_up", [KEY_UP])
	_add_joypad_button_action("menu_up", JOY_BUTTON_DPAD_UP)
	_add_joypad_motion_action("menu_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_key_action("menu_down", [KEY_DOWN])
	_add_joypad_button_action("menu_down", JOY_BUTTON_DPAD_DOWN)
	_add_joypad_motion_action("menu_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_key_action("menu_left", [KEY_LEFT])
	_add_joypad_button_action("menu_left", JOY_BUTTON_DPAD_LEFT)
	_add_joypad_motion_action("menu_left", JOY_AXIS_LEFT_X, -1.0)
	_add_key_action("menu_right", [KEY_RIGHT])
	_add_joypad_button_action("menu_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joypad_motion_action("menu_right", JOY_AXIS_LEFT_X, 1.0)
	# v0.1-b3: spatial paging (LB/RB, Q/E). In the RTL UI the left input moves
	# to the item on the LEFT, i.e. the next one in reading order.
	_add_key_action("ui_page_left", [KEY_Q])
	_add_joypad_button_action("ui_page_left", JOY_BUTTON_LEFT_SHOULDER)
	_add_key_action("ui_page_right", [KEY_E])
	_add_joypad_button_action("ui_page_right", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joypad_motion_action("camera_orbit_x", JOY_AXIS_RIGHT_X, -1.0)
	_add_joypad_motion_action("camera_orbit_x", JOY_AXIS_RIGHT_X, 1.0)
	_add_joypad_motion_action("camera_orbit_y", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joypad_motion_action("camera_orbit_y", JOY_AXIS_RIGHT_Y, 1.0)


static func _add_key_action(action_name: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.15)
	var existing := InputMap.action_get_events(action_name)
	for k in keys:
		var found := false
		for ev in existing:
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == k:
				found = true
				break
		if not found:
			var kev := InputEventKey.new()
			kev.physical_keycode = k
			InputMap.action_add_event(action_name, kev)


static func _add_joypad_button_action(action_name: String, button: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.15)
	var existing := InputMap.action_get_events(action_name)
	for ev in existing:
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return
	var bev := InputEventJoypadButton.new()
	bev.button_index = button
	InputMap.action_add_event(action_name, bev)


# ------------------------------------------------------------------
# K2-REDESIGN-002: full physical gamepad support.
# ------------------------------------------------------------------

static func _add_joypad_motion_action(action_name: String, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.15)
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == axis and is_equal_approx((ev as InputEventJoypadMotion).axis_value, axis_value):
			return
	var mev := InputEventJoypadMotion.new()
	mev.axis = axis
	mev.axis_value = axis_value
	InputMap.action_add_event(action_name, mev)


static func _apply_deadzone(v: float, dz: float) -> float:
	var a := absf(v)
	if a <= dz:
		return 0.0
	return signf(v) * (a - dz) / maxf(1.0 - dz, 0.01)


## Analog steering from the left stick of any connected pad, with the
## configurable SettingsManager.joy_deadzone applied. + = steer right.
static func joy_steer_axis() -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var v := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		if absf(v) > absf(best):
			best = v
	return _apply_deadzone(best, SettingsManager.joy_deadzone)


## Trigger value normalised to 0..1 regardless of whether the pad
## reports its triggers as 0..1 or -1..1 (rest position detected at
## runtime: a rest value below -0.05 means the -1..1 flavour).
static func _joy_trigger(axis: JoyAxis) -> float:
	var best := 0.0
	for dev in Input.get_connected_joypads():
		var raw := Input.get_joy_axis(dev, axis)
		var n := (raw + 1.0) * 0.5 if raw < -0.05 else raw
		best = maxf(best, clampf(n, 0.0, 1.0))
	return _apply_deadzone(best, SettingsManager.joy_deadzone * 0.5)


static func joy_throttle_value() -> float:
	return _joy_trigger(JOY_AXIS_TRIGGER_RIGHT)


static func joy_brake_value() -> float:
	return _joy_trigger(JOY_AXIS_TRIGGER_LEFT)
