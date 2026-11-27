extends SceneTree

const RUNWAY = preload("res://tests/support/test_runway.gd")

## K2-FINAL-003: touch controls and a physical gamepad COEXIST.
## Verified headlessly (no physical pad in this VM): synthetic touch
## events (two fingers, distinct indices) and synthetic joypad events
## are injected with Input.parse_input_event into the real driving
## scene. Asserts: touch pads stay visible AND functional in GAMEPAD
## mode, the Settings toggle (default ON) owns their visibility,
## simultaneous presses merge without sticking or cross-clearing,
## and a pad disconnect does not disturb an in-flight touch press.

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	await run_checks()
	print("=== TOUCH+GAMEPAD COEXIST SUMMARY: %d passed, %d failed ===" % [passed, failed])
	quit(1 if failed > 0 else 0)


func check(cond: bool, label: String, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  [PASS] %s %s" % [label, detail])
	else:
		failed += 1
		push_error("  [FAIL] %s %s" % [label, detail])


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _joy_button(button: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = pressed
	Input.parse_input_event(ev)


func run_checks() -> void:
	await process_frame
	VehicleInputMap.ensure_actions()
	SettingsManager.load_settings()
	# v0.1-b3: geometry checks assume 100 % UI scale, whatever the persisted value.
	SettingsManager.ui_scale = 1.0
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()

	# Setting contract: toggle exists, defaults ON, persists.
	check(SettingsManager.show_touch_controls == true, "touch_toggle_default_on")
	SettingsManager.show_touch_controls = false
	SettingsManager.save_settings()
	SettingsManager.show_touch_controls = true
	SettingsManager.load_settings()
	check(SettingsManager.show_touch_controls == false, "touch_toggle_persists")
	SettingsManager.show_touch_controls = true
	SettingsManager.save_settings()

	root.size = Vector2i(1280, 720)
	var main = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in range(30):
		await physics_frame
	await process_frame
	var hud: VehicleHud = main.hud
	var vehicle = main.vehicle
	var steer_zone := hud.get_node("HudRoot/SteerZone") as Control
	var pedal_col := hud.get_node("HudRoot/PedalColumn") as Control
	var hint := hud.get_node("HudRoot/GamepadHintStrip") as Control if hud.has_node("HudRoot/GamepadHintStrip") else null

	# Enter GAMEPAD mode the way a real pad press would.
	InputDeviceManager.current_mode = InputDeviceManager.Mode.KEYBOARD_MOUSE
	_joy_button(JOY_BUTTON_Y, true)
	_joy_button(JOY_BUTTON_Y, false)
	await process_frame
	check(InputDeviceManager.current_mode == InputDeviceManager.Mode.GAMEPAD, "pad_press_sets_gamepad_mode")
	hud._apply_input_mode(InputDeviceManager.Mode.GAMEPAD)
	await process_frame
	check(steer_zone.visible, "steer_zone_visible_in_gamepad_mode")
	check(pedal_col.visible, "pedal_column_visible_in_gamepad_mode")
	check(hint != null and hint.visible, "gamepad_hint_strip_still_shows")

	# Two-finger multitouch: finger 0 on throttle, finger 1 on steer-left.
	await process_frame
	var throttle_pos := hud.btn_throttle.get_global_rect().get_center()
	var steer_pos := hud.btn_steer_left.get_global_rect().get_center()
	_touch(0, throttle_pos, true)
	_touch(1, steer_pos, true)
	await process_frame
	await process_frame
	check(hud.btn_throttle.is_pressed_down, "multitouch_throttle_down")
	check(hud.btn_steer_left.is_pressed_down, "multitouch_steer_down")
	check(vehicle.touch_throttle == 1.0, "touch_throttle_written_in_gamepad_mode", "%.2f" % vehicle.touch_throttle)
	check(vehicle.touch_steer == -1.0, "touch_steer_written_in_gamepad_mode", "%.2f" % vehicle.touch_steer)

	# A pad press while both fingers stay down flips the mode back to
	# GAMEPAD — the true simultaneous state. Touch input must survive.
	_joy_button(JOY_BUTTON_DPAD_UP, true)
	_joy_button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	await process_frame
	check(InputDeviceManager.current_mode == InputDeviceManager.Mode.GAMEPAD, "mode_gamepad_with_fingers_down")
	check(vehicle.touch_throttle == 1.0 and vehicle.touch_steer == -1.0, "touch_survives_mode_switch_to_gamepad")
	check(steer_zone.visible and pedal_col.visible, "zones_still_visible_after_mode_switch")

	# The car actually drives on touch while the mode is GAMEPAD.
	# v0.2-b2: the grid now sits on the desert circuit, 39 m before a kink, so a 1.5 s throttle
	# hold from the start line ends against the barrier. This checks the *touch path*, not the
	# map, so the car is moved onto the synthetic runway the other speed suites use.
	var runway: Transform3D = RUNWAY.build(main, 500.0, 40.0)
	vehicle.set_spawn_transform(runway)
	vehicle.reset_vehicle(runway)
	await physics_frame
	var v0: float = vehicle.current_speed_kmh
	for i in range(90):
		await physics_frame
	check(vehicle.current_speed_kmh > v0 + 3.0, "vehicle_drives_on_touch_in_gamepad_mode", "%.1f -> %.1f km/h" % [v0, vehicle.current_speed_kmh])

	# Releasing finger 0 must not clear finger 1 (no cross-talk, no stuck).
	_touch(0, throttle_pos, false)
	for i in range(4):
		await process_frame
	check(vehicle.touch_throttle == 0.0, "throttle_released_cleanly")
	check(vehicle.touch_steer == -1.0, "steer_survives_other_finger_release")
	_touch(1, steer_pos, false)
	for i in range(4):
		await process_frame
	check(vehicle.touch_steer == 0.0, "steer_released_cleanly_no_stuck")

	# Handbrake pad also works in gamepad mode.
	hud.btn_handbrake.set_simulated_press(true)
	await process_frame
	await process_frame
	check(vehicle.touch_handbrake == true, "touch_handbrake_in_gamepad_mode")
	hud.btn_handbrake.set_simulated_press(false)
	for i in range(3):
		await process_frame
	check(vehicle.touch_handbrake == false, "touch_handbrake_releases")

	# Pad disconnect mid-press: mode falls back, touch press unaffected.
	hud.btn_throttle.set_simulated_press(true)
	await process_frame
	var dm := InputDeviceManager.new()
	root.add_child(dm)
	dm._on_joy_connection_changed(0, false)
	await process_frame
	check(InputDeviceManager.current_mode != InputDeviceManager.Mode.GAMEPAD, "disconnect_falls_back_from_gamepad")
	check(vehicle.touch_throttle == 1.0, "touch_press_survives_pad_disconnect")
	hud.btn_throttle.set_simulated_press(false)
	dm.queue_free()

	# Toggle OFF: zones hide and inputs zero even mid-press.
	hud.btn_throttle.set_simulated_press(true)
	await process_frame
	hud.set_touch_controls_visible(false)
	await process_frame
	check(not steer_zone.visible and not pedal_col.visible, "toggle_off_hides_zones")
	check(vehicle.touch_throttle == 0.0, "toggle_off_zeroes_inputs_no_stuck")
	hud.btn_throttle.set_simulated_press(false)
	hud.set_touch_controls_visible(true)
	await process_frame
	check(steer_zone.visible and pedal_col.visible, "toggle_on_restores_zones")

	# Engine-volume setting contract (K2-FINAL-003 audio).
	SettingsManager.engine_volume = 0.35
	SettingsManager.save_settings()
	SettingsManager.engine_volume = 0.8
	SettingsManager.load_settings()
	check(absf(SettingsManager.engine_volume - 0.35) < 0.001, "engine_volume_persists")
	SettingsManager.engine_volume = 0.8
	SettingsManager.save_settings()
