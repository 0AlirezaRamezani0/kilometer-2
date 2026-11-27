extends SceneTree

## Dev-only focus/bidi probe (export-excluded). Prints facts about keyboard /
## gamepad focus on each screen so the audit can cite runtime evidence.
## Run: godot --headless --path . --script res://qa/probe_focus.gd


func _initialize() -> void:
	await _run()
	quit(0)


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _owner_desc() -> String:
	var f := root.gui_get_focus_owner()
	if f == null:
		return "<none>"
	var behind := ""
	return "%s (%s)%s" % [f.name, f.get_class(), behind]


func _run() -> void:
	root.size = Vector2i(1280, 720)
	SettingsManager.load_settings()
	SettingsManager.set_selected_vehicle(0)

	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(6)
	print("PROBE menu.initial_focus = ", _owner_desc())
	(menu.find_child("MenuSettingsButton", true, false) as Button).pressed.emit()
	await _frames(4)
	print("PROBE menu.settings_open.focus = ", _owner_desc())
	var panel := menu.find_child("MenuSettingsPanel", true, false) as Control
	var f := root.gui_get_focus_owner()
	print("PROBE menu.settings_open.focus_inside_modal = ", f != null and panel != null and (panel.is_ancestor_of(f) or f.name == "MenuSettingsBackButton"))
	var back := menu.find_child("MenuSettingsBackButton", true, false) as Button
	back.grab_focus()
	await _frames(2)
	# Walk "up" from the close button 6 times and see whether focus leaves the modal.
	var escaped := false
	for _i in range(6):
		var cur := root.gui_get_focus_owner()
		if cur == null:
			break
		var nb := cur.find_valid_focus_neighbor(SIDE_TOP)
		if nb == null:
			break
		nb.grab_focus()
		await _frames(1)
		var now := root.gui_get_focus_owner()
		if now != null and not (panel.is_ancestor_of(now) or now == back):
			escaped = true
			print("PROBE menu.settings_focus_escaped_to = ", now.name)
			break
	print("PROBE menu.settings_focus_trapped = ", not escaped)
	back.pressed.emit()
	await _frames(2)
	(menu.find_child("HelpButton", true, false) as Button).pressed.emit()
	await _frames(3)
	print("PROBE menu.help_open.focus = ", _owner_desc())
	menu.queue_free()
	await _frames(3)

	var lobby: Node = (load("res://scenes/multiplayer/lan_lobby.tscn") as PackedScene).instantiate()
	root.add_child(lobby)
	await _frames(6)
	print("PROBE lan_lobby.initial_focus = ", _owner_desc())
	# Bidi: report the resolved direction of the IP label.
	for n in lobby.find_children("*", "Label", true, false):
		var l := n as Label
		if l.text.begins_with("IP"):
			print("PROBE lan_lobby.ip_label.text_direction = ", l.text_direction, " (0=auto,1=ltr,2=rtl)")
	lobby.queue_free()
	await _frames(3)

	var main: Node = (load("res://scenes/main/main_driving_template.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(8)
	print("PROBE hud.driving.focus = ", _owner_desc())
	var hud = main.hud
	hud.set_game_paused(true)
	await _frames(4)
	print("PROBE hud.pause.focus = ", _owner_desc())
	var quit_btn := hud.find_child("PauseQuitButton", true, false) as Button
	print("PROBE hud.pause.quit_button_has_confirm = ", quit_btn != null and quit_btn.pressed.get_connections().size() > 0)
	hud.set_game_paused(false)
	await _frames(2)
	print("PROBE done")
