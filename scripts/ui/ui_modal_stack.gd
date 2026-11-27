class_name UiModalStack
extends RefCounted

## Overlay stack with real focus trapping (fix for audit A-01).
##
## Opening an overlay disables focus and mouse on everything beneath it with
## Godot 4.5+'s focus_behavior_recursive / mouse_behavior_recursive, moves
## focus into the overlay, and on close restores the control that had focus
## before. Only the top overlay is interactive; Esc / B pops it.
## Overlays must be siblings of the base layer (not its descendants), or the
## base's recursive disable would also disable them.

signal changed

var _base: Control = null
var _stack: Array[Dictionary] = []


func _init(base_layer: Control) -> void:
	_base = base_layer


func size() -> int:
	return _stack.size()


func is_empty() -> bool:
	return _stack.is_empty()


func top() -> Control:
	return null if _stack.is_empty() else _stack.back()["node"]


func has(node: Control) -> bool:
	for e in _stack:
		if e["node"] == node:
			return true
	return false


static func _set_interactive(c: Control, on: bool) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED if on else Control.FOCUS_BEHAVIOR_DISABLED
	c.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if on else Control.MOUSE_BEHAVIOR_DISABLED


## First visible, enabled, focusable control inside `root` (depth-first).
static func first_focusable(root: Node) -> Control:
	for child in root.get_children():
		if child is Control:
			var c := child as Control
			if not c.is_visible_in_tree():
				continue
			if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
				return c
			var deeper := first_focusable(c)
			if deeper != null:
				return deeper
	return null


## Shows `node` on top. `focus_target` (or the first focusable descendant)
## receives focus. `on_cancel` runs when Esc/B pops this overlay.
func push(node: Control, focus_target: Control = null, on_cancel: Callable = Callable()) -> void:
	if node == null or has(node):
		return
	var vp := node.get_viewport()
	var prev: Control = vp.gui_get_focus_owner() if vp != null else null
	_set_interactive(top() if not _stack.is_empty() else _base, false)
	_stack.append({"node": node, "prev": prev, "cancel": on_cancel})
	node.visible = true
	_set_interactive(node, true)
	var target := focus_target
	if target == null or not target.is_visible_in_tree():
		target = first_focusable(node)
	if target != null:
		target.grab_focus()
	elif prev != null and is_instance_valid(prev):
		prev.release_focus()
	changed.emit()


## Hides the top overlay and gives focus back.
func pop() -> Control:
	if _stack.is_empty():
		return null
	var e: Dictionary = _stack.pop_back()
	var node: Control = e["node"]
	if is_instance_valid(node):
		node.visible = false
	var below: Control = top() if not _stack.is_empty() else _base
	_set_interactive(below, true)
	var prev: Control = e["prev"]
	if prev != null and is_instance_valid(prev) and prev.is_visible_in_tree() and prev.focus_mode != Control.FOCUS_NONE:
		prev.grab_focus()
	elif below != null and is_instance_valid(below):
		var f := first_focusable(below)
		if f != null:
			f.grab_focus()
	changed.emit()
	return node


## Pops overlays until `node` is gone (no-op if not open).
func close(node: Control) -> void:
	if not has(node):
		return
	while not _stack.is_empty():
		var n := pop()
		if n == node:
			break


func clear() -> void:
	while not _stack.is_empty():
		pop()


## Esc / B. Returns true when an overlay consumed the cancel.
func handle_cancel() -> bool:
	if _stack.is_empty():
		return false
	var cb: Callable = _stack.back()["cancel"]
	if cb.is_valid():
		cb.call()
	else:
		pop()
	return true
