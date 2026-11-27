extends SceneTree

## K2-REDESIGN-002 (R9): gamepad mapping verified HEADLESSLY — no
## physical pad is attached to this VM. Synthetic InputEventJoypad*
## events are injected with Input.parse_input_event and the InputMap
## wiring + analog maths are asserted. The raw-axis helpers
## (get_joy_axis) cannot be exercised without hardware; they are
## asserted to be safe no-ops with zero pads connected.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_checks()
	print("=== GAMEPAD MAPPING SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func _has_motion(action: String, axis: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == axis:
			return true
	return false


func _has_button(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false


func run_checks() -> void:
	await process_frame
	VehicleInputMap.ensure_actions()
	SettingsManager.load_settings()
	SettingsManager.joy_deadzone = 0.15

	# Wiring: axes.
	check(_has_motion("steer_left", JOY_AXIS_LEFT_X), "steer_left_on_left_stick")
	check(_has_motion("steer_right", JOY_AXIS_LEFT_X), "steer_right_on_left_stick")
	check(_has_motion("throttle", JOY_AXIS_TRIGGER_RIGHT), "throttle_on_rt")
	check(_has_motion("brake_reverse", JOY_AXIS_TRIGGER_LEFT), "brake_on_lt")
	check(_has_motion("camera_orbit_x", JOY_AXIS_RIGHT_X), "orbit_on_right_stick_x")
	# Wiring: buttons.
	check(_has_button("throttle", JOY_BUTTON_A), "throttle_fallback_a")
	check(_has_button("brake_reverse", JOY_BUTTON_X), "brake_fallback_x")
	check(_has_button("handbrake", JOY_BUTTON_B), "handbrake_b")
	check(_has_button("toggle_headlights", JOY_BUTTON_Y), "headlights_y")
	check(_has_button("pause_game", JOY_BUTTON_START), "pause_start")
	check(_has_button("camera_reset", JOY_BUTTON_RIGHT_STICK), "camera_reset_r3")
	check(_has_button("photo_mode", JOY_BUTTON_BACK), "photo_mode_back")
	check(_has_button("menu_accept", JOY_BUTTON_A), "menu_accept_a")
	check(_has_button("menu_back", JOY_BUTTON_B), "menu_back_b")
	check(_has_button("menu_up", JOY_BUTTON_DPAD_UP), "menu_up_dpad")

	# Analog maths: deadzone normalisation is progressive, not binary.
	var dz := VehicleInputMap._apply_deadzone(0.6, 0.15)
	check(absf(dz - 0.5294) < 0.001, "deadzone_progressive", "%.4f" % dz)
	check(VehicleInputMap._apply_deadzone(0.1, 0.15) == 0.0, "deadzone_kills_small_input")
	check(is_equal_approx(VehicleInputMap._apply_deadzone(1.0, 0.15), 1.0), "deadzone_full_lock_at_1")
	check(absf(VehicleInputMap._apply_deadzone(-0.6, 0.15) + 0.5294) < 0.001, "deadzone_symmetric")

	# No hardware: helpers are safe zeros.
	check(Input.get_connected_joypads().is_empty(), "no_physical_pad_in_vm")
	check(VehicleInputMap.joy_steer_axis() == 0.0, "joy_steer_safe_without_pad")
	check(VehicleInputMap.joy_throttle_value() == 0.0, "joy_throttle_safe_without_pad")

	# Synthetic events drive the actions + the device manager mode.
	var dm := InputDeviceManager.new()
	root.add_child(dm)
	await process_frame
	var bev := InputEventJoypadButton.new()
	bev.button_index = JOY_BUTTON_Y
	bev.pressed = true
	Input.parse_input_event(bev)
	await process_frame
	await process_frame
	check(Input.is_action_pressed("toggle_headlights"), "synthetic_y_fires_headlights")
	check(InputDeviceManager.current_mode == InputDeviceManager.Mode.GAMEPAD, "manager_switches_to_gamepad")
	var bev2 := InputEventJoypadButton.new()
	bev2.button_index = JOY_BUTTON_Y
	bev2.pressed = false
	Input.parse_input_event(bev2)
	await process_frame
	var mev := InputEventJoypadMotion.new()
	mev.axis = JOY_AXIS_LEFT_X
	mev.axis_value = 0.6
	Input.parse_input_event(mev)
	await process_frame
	await process_frame
	check(Input.get_action_strength("steer_right") > 0.3, "synthetic_stick_is_analog", "%.3f" % Input.get_action_strength("steer_right"))
	var mev2 := InputEventJoypadMotion.new()
	mev2.axis = JOY_AXIS_LEFT_X
	mev2.axis_value = 0.0
	Input.parse_input_event(mev2)
	await process_frame
	dm.queue_free()
