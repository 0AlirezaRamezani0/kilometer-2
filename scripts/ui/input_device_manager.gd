class_name InputDeviceManager
extends Node

## K2-REDESIGN-002 (R4): tracks which input family the player is
## actually using — TOUCH, KEYBOARD_MOUSE or GAMEPAD — and broadcasts
## changes so HUD prompts and touch controls can switch automatically.
## The mode itself is static (shared by menu + HUD instances); each
## instance also emits its own signal for local listeners.

signal mode_changed(mode: int)

enum Mode { TOUCH, KEYBOARD_MOUSE, GAMEPAD }

static var current_mode: int = Mode.KEYBOARD_MOUSE
static var _mode_bootstrapped: bool = false

## True while at least one finger is physically on the screen (R7 gating).
static var touch_active: bool = false
static var _active_touch_indices: Dictionary = {}

## v0.1-b3: every live tracker, so a mode change is broadcast on all of them.
## (Before, only the first tracker to see the event emitted mode_changed —
## the others found the static mode already updated and stayed silent.)
static var _instances: Array = []
## Shared tracker for UI that only needs prompts (menus, sheets, chips).
static var _global: InputDeviceManager = null


static func get_mode() -> int:
	return current_mode


## Returns the shared tracker, creating it under the SceneTree root on first
## use. It persists across scene changes.
static func ensure_tracker(_requester: Node = null) -> InputDeviceManager:
	if _global != null and is_instance_valid(_global):
		return _global
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_global = InputDeviceManager.new()
	_global.name = "InputDeviceTracker"
	tree.root.add_child.call_deferred(_global)
	return _global


func _enter_tree() -> void:
	if not InputDeviceManager._instances.has(self):
		InputDeviceManager._instances.append(self)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputDeviceManager._mode_bootstrapped:
		InputDeviceManager._mode_bootstrapped = true
		if OS.has_feature("android"):
			InputDeviceManager.current_mode = Mode.TOUCH
		# R4: poll already-connected pads at startup.
		if not Input.get_connected_joypads().is_empty():
			InputDeviceManager.current_mode = Mode.GAMEPAD
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _exit_tree() -> void:
	InputDeviceManager._instances.erase(self)
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		_set_mode(Mode.GAMEPAD)
	elif event is InputEventJoypadMotion:
		var m := event as InputEventJoypadMotion
		if absf(m.axis_value) > 0.25:
			_set_mode(Mode.GAMEPAD)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_set_mode(Mode.TOUCH)
		if st.pressed:
			InputDeviceManager._active_touch_indices[st.index] = true
		else:
			InputDeviceManager._active_touch_indices.erase(st.index)
		InputDeviceManager.touch_active = not InputDeviceManager._active_touch_indices.is_empty()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		InputDeviceManager._active_touch_indices[sd.index] = true
		InputDeviceManager.touch_active = true
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		_set_mode(Mode.KEYBOARD_MOUSE)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_set_mode(Mode.KEYBOARD_MOUSE)


func _set_mode(m: int) -> void:
	if InputDeviceManager.current_mode == m:
		return
	InputDeviceManager.current_mode = m
	var emitted_self := false
	for inst in InputDeviceManager._instances.duplicate():
		if is_instance_valid(inst):
			(inst as InputDeviceManager).mode_changed.emit(m)
			if inst == self:
				emitted_self = true
	if not emitted_self:
		mode_changed.emit(m)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected:
		# R8: never leave a pad buzzing after it disappears.
		Input.stop_joy_vibration(device)
		if Input.get_connected_joypads().is_empty() and InputDeviceManager.current_mode == Mode.GAMEPAD:
			_set_mode(Mode.TOUCH if OS.has_feature("android") else Mode.KEYBOARD_MOUSE)
	else:
		_set_mode(Mode.GAMEPAD)
