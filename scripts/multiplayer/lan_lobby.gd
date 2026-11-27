extends Control

## Kilometer 2 — LAN lobby (v0.1-b3, "Proving Ground" design system).
## Two roles side by side (one column on narrow screens): host a room or
## join one by IP. Fixes from the audit:
##  - A-03: focus starts on «ساخت اتاق», Esc / B returns to the showroom;
##  - A-04: Persian labels use an explicit RTL paragraph and the IP address
##    lives in its own LTR label, so mixed text no longer scrambles;
##  - buttons enable only when they apply (cancel only while hosting or
##    connecting, join only with an address), the IP is validated with a
##    readable error, and the status chip carries tone + icon + text.
## Node names CreateRoom / JoinRoom / CancelRoom / BackToMenu / IpField match
## the original scene.
##
## v0.3 — host discovery. The lobby now leads with «میزبان‌های پیدا‌شده»: every device on the
## same Wi-Fi / hotspot that has a room open appears there by itself (LanSession broadcasts a
## beacon, the host answers), with a one-tap «اتصال» button per row. The manual IP field stays
## as the fallback for networks that filter broadcast traffic.

const IP_RE := "^((25[0-5]|2[0-4]\\d|1?\\d?\\d)\\.){3}(25[0-5]|2[0-4]\\d|1?\\d?\\d)$"

var _status_label: Label
var _status_chip: PanelContainer
var _status_icon: UiIcon
var _spinner: Control
var _ip_field: LineEdit
var _ip_error: Label
var _create_btn: Button
var _join_btn: Button
var _cancel_btn: Button
var _back_btn: Button
var _panel: PanelContainer
var _cards: GridContainer
var _re := RegEx.new()
var _error_shown: bool = false
var _hosts_list: VBoxContainer
var _hosts_empty: Label
var _hosts_hint: Label
var _search_btn: Button
var _host_rows: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_re.compile(IP_RE)
	SettingsManager.ensure_loaded()
	SettingsManager.apply_ui_scale()
	var bg := ColorRect.new()
	bg.color = UiTheme.COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var outer_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, UiTheme.SPACE_3)
	center.add_child(outer_margin)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = "GlassPanel"
	outer_margin.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.layout_direction = Control.LAYOUT_DIRECTION_RTL
	vbox.add_theme_constant_override("separation", UiTheme.SPACE_5)
	_panel.add_child(vbox)

	# Header: back (end side) · title + subtitle (start side) · status chip.
	var hdr := HBoxContainer.new()
	hdr.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hdr.add_theme_constant_override("separation", UiTheme.SPACE_4)
	vbox.add_child(hdr)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 2)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_col)
	title_col.add_child(UiTheme.make_heading("بازی شبکه‌ای محلی", "HeadlineLabel"))
	title_col.add_child(UiTheme.label("هر دو دستگاه به یک Wi-Fi یا هات‌اسپات وصل باشند؛ اینترنت لازم نیست.", "BodyMutedLabel", true))
	_back_btn = UiTheme.make_button("بازگشت", "BackToMenu", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary", "back")
	_back_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_back_btn.pressed.connect(_on_back_pressed)
	hdr.add_child(_back_btn)

	_status_chip = PanelContainer.new()
	_status_chip.name = "StatusChip"
	_status_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(_status_chip)
	var chip_row := HBoxContainer.new()
	chip_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	chip_row.add_theme_constant_override("separation", UiTheme.SPACE_2)
	_status_chip.add_child(chip_row)
	_status_icon = UiIcon.make("info", 20, UiTheme.COLOR_INFO)
	chip_row.add_child(_status_icon)
	_spinner = _make_spinner()
	_spinner.custom_minimum_size = Vector2(20, 20)
	_spinner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(_spinner)
	_status_label = UiTheme.label("", "LabelStrong", true)
	_status_label.name = "StatusLabel"
	chip_row.add_child(_status_label)

	# --- Discovered hosts (v0.3) -------------------------------------------
	# This is the primary path: one device hosts, the other simply sees it here and taps
	# «اتصال». Rows are rebuilt only when the list actually changes.
	var found_card := PanelContainer.new()
	found_card.name = "FoundHostsCard"
	found_card.theme_type_variation = "CardPanel"
	vbox.add_child(found_card)
	var found_box := VBoxContainer.new()
	found_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	found_box.add_theme_constant_override("separation", UiTheme.SPACE_3)
	found_card.add_child(found_box)
	var found_head := HBoxContainer.new()
	found_head.layout_direction = Control.LAYOUT_DIRECTION_RTL
	found_head.add_theme_constant_override("separation", UiTheme.SPACE_2)
	found_box.add_child(found_head)
	found_head.add_child(UiIcon.make("lan", 24, UiTheme.COLOR_PRIMARY))
	var found_title := UiTheme.label("میزبان‌های پیدا‌شده", "TitleLabel")
	found_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	found_head.add_child(found_title)
	_search_btn = UiTheme.make_button("جست‌وجوی دوباره", "SearchHosts", false, Vector2(0, UiTheme.TOUCH_MIN), "ghost", "search")
	_search_btn.pressed.connect(_on_search_pressed)
	found_head.add_child(_search_btn)

	_hosts_empty = UiTheme.label("در حال جست‌وجو… اگر دستگاه دوم هنوز اتاق نساخته، همین‌جا ظاهر می‌شود.", "BodyMutedLabel", true)
	_hosts_empty.name = "HostsEmpty"
	found_box.add_child(_hosts_empty)
	_hosts_list = VBoxContainer.new()
	_hosts_list.name = "HostsList"
	_hosts_list.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_hosts_list.add_theme_constant_override("separation", UiTheme.SPACE_2)
	found_box.add_child(_hosts_list)
	_hosts_hint = UiTheme.label("", "CaptionLabel", true)
	_hosts_hint.name = "HostsHint"
	_hosts_hint.visible = false
	found_box.add_child(_hosts_hint)

	_cards = GridContainer.new()
	_cards.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_cards.add_theme_constant_override("h_separation", UiTheme.SPACE_4)
	_cards.add_theme_constant_override("v_separation", UiTheme.SPACE_4)
	vbox.add_child(_cards)

	# --- Host card ---------------------------------------------------------
	var host := _card("ساخت اتاق", "میزبان می‌شوید و دستگاه دوم به شما وصل می‌شود.", "lan")
	_cards.add_child(host[0])
	var host_box: VBoxContainer = host[1]
	host_box.add_child(UiTheme.label("نشانی این دستگاه:", "CaptionLabel"))
	var own_ip := LanSession.get_local_ip()
	if own_ip != "":
		var ip_lbl := UiTheme.ltr_label(own_ip, "NumericLabel")
		ip_lbl.name = "OwnIpLabel"
		ip_lbl.add_theme_font_size_override("font_size", UiTheme.TYPE_NUMERIC_LG)
		ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		host_box.add_child(ip_lbl)
	else:
		var no_ip := UiTheme.label("نشانی پیدا نشد؛ اتصال Wi-Fi یا هات‌اسپات را بررسی کنید.", "BodyMutedLabel", true)
		no_ip.name = "OwnIpLabel"
		no_ip.add_theme_color_override("font_color", UiTheme.COLOR_WARNING)
		host_box.add_child(no_ip)
	_create_btn = UiTheme.make_button("ساخت اتاق و انتظار", "CreateRoom", true, Vector2(0, UiTheme.CONTROL_HEIGHT_LG), "primary", "play")
	_create_btn.pressed.connect(_on_create_pressed)
	host_box.add_child(_create_btn)
	_cancel_btn = UiTheme.make_button("لغو اتصال", "CancelRoom", false, Vector2(0, UiTheme.TOUCH_MIN), "ghost", "close")
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	host_box.add_child(_cancel_btn)

	# --- Guest card --------------------------------------------------------
	var guest := _card("اتصال با نشانی", "اگر میزبان در فهرست بالا نیامد، نشانی IP او را از صفحهٔ خودش وارد کنید.", "user")
	_cards.add_child(guest[0])
	var guest_box: VBoxContainer = guest[1]
	guest_box.add_child(UiTheme.label("نشانی IP میزبان", "LabelStrong"))
	_ip_field = LineEdit.new()
	_ip_field.name = "IpField"
	_ip_field.placeholder_text = "192.168.1.2"
	_ip_field.text_direction = Control.TEXT_DIRECTION_LTR
	_ip_field.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_ip_field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	_ip_field.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	_ip_field.accessibility_name = "نشانی IP میزبان"
	_ip_field.text_changed.connect(func(_t: String) -> void:
		_set_ip_error("")
		_refresh_buttons())
	_ip_field.text_submitted.connect(func(_t: String) -> void: _on_join_pressed())
	guest_box.add_child(_ip_field)
	_ip_error = UiTheme.label("", "CaptionLabel", true)
	_ip_error.name = "IpError"
	_ip_error.add_theme_color_override("font_color", UiTheme.COLOR_ERROR)
	_ip_error.visible = false
	guest_box.add_child(_ip_error)
	_join_btn = UiTheme.make_button("پیوستن", "JoinRoom", false, Vector2(0, UiTheme.CONTROL_HEIGHT_LG), "secondary", "forward")
	_join_btn.pressed.connect(_on_join_pressed)
	guest_box.add_child(_join_btn)

	var note := UiTheme.label("خودرو را پیش از ورود در نمایشگاه انتخاب کنید.", "CaptionLabel", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(note)

	LanSession.status_changed.connect(_on_status_changed)
	LanSession.lan_error.connect(_on_lan_error)
	LanSession.hosts_changed.connect(_on_hosts_changed)
	LanSession.start_discovery()
	_render_hosts(LanSession.hosts)
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	var initial := LanSession.status_text
	if LanSession.state == LanSession.State.IDLE and (initial.begins_with("به میزبان متصل شدید") or initial == "اتصال لغو شد."):
		initial = ""
	_show_status(initial)
	_refresh_buttons()
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("attach_ui_sounds"):
			am.call("attach_ui_sounds", self)
		if am.has_method("play_menu_music"):
			am.call("play_menu_music")
	_create_btn.grab_focus()
	var d := UiTheme.fade_sec(UiTheme.MOTION_MEDIUM_MS)
	if d > 0.0:
		_panel.modulate.a = 0.0
		create_tween().tween_property(_panel, "modulate:a", 1.0, d)


## Local loading spinner. (The old SceneTransitionLayer.Spinner lived with the fade veil
## that v0.2-b1 replaced with the identity-v2 loading screen.)
func _make_spinner() -> Control:
	var sp := Control.new()
	sp.name = "Spinner"
	sp.draw.connect(func() -> void:
		var c := sp.size * 0.5
		var r := minf(sp.size.x, sp.size.y) * 0.5 - 2.0
		sp.draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.14), 3.0, true)
		sp.draw_arc(c, r, -PI * 0.5, PI * 0.2, 16, UiTheme.COLOR_PRIMARY, 3.0, true))
	sp.custom_minimum_size = Vector2(20, 20)
	return sp


func _card(title: String, desc: String, icon: String) -> Array:
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.add_theme_constant_override("separation", UiTheme.SPACE_3)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.layout_direction = Control.LAYOUT_DIRECTION_RTL
	head.add_theme_constant_override("separation", UiTheme.SPACE_2)
	head.add_child(UiIcon.make(icon, 24, UiTheme.COLOR_PRIMARY))
	head.add_child(UiTheme.label(title, "TitleLabel"))
	box.add_child(head)
	box.add_child(UiTheme.label(desc, "BodyMutedLabel", true))
	return [card, box]


func _exit_tree() -> void:
	LanSession.stop_discovery()
	if LanSession.hosts_changed.is_connected(_on_hosts_changed):
		LanSession.hosts_changed.disconnect(_on_hosts_changed)
	if LanSession.status_changed.is_connected(_on_status_changed):
		LanSession.status_changed.disconnect(_on_status_changed)
	if LanSession.lan_error.is_connected(_on_lan_error):
		LanSession.lan_error.disconnect(_on_lan_error)


func _relayout() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	if _panel != null:
		_panel.custom_minimum_size = Vector2(minf(860.0, maxf(300.0, vp.x - 24.0)), 0.0)
	if _cards != null:
		_cards.columns = 2 if vp.x >= maxf(vp.y, 700.0) else 1
	if _status_label != null:
		_status_label.custom_minimum_size = Vector2(minf(560.0, maxf(200.0, vp.x - 140.0)), 0)


func _busy() -> bool:
	return LanSession.state == LanSession.State.HOSTING or LanSession.state == LanSession.State.CONNECTING


func _refresh_buttons() -> void:
	var busy := _busy()
	_create_btn.disabled = busy
	_cancel_btn.disabled = not busy
	_join_btn.disabled = busy or _ip_field.text.strip_edges().is_empty()
	_ip_field.editable = not busy
	if _search_btn != null:
		_search_btn.disabled = busy
	for ip in _host_rows.keys():
		var b := _host_rows[ip] as Button
		if b != null:
			b.disabled = busy


## Status chip: tone + icon + text (colour is never the only cue).
func _show_status(msg: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	var text := msg if msg != "" else "آماده اتصال؛ یکی از دو نقش را انتخاب کنید."
	_status_label.text = text
	var tone := UiTheme.COLOR_INFO
	var icon := "info"
	var spin := _busy()
	if is_error:
		tone = UiTheme.COLOR_ERROR
		icon = "alert"
		spin = false
	elif LanSession.state == LanSession.State.IN_GAME or text.contains("متصل شد"):
		tone = UiTheme.COLOR_SUCCESS
		icon = "check"
	elif not spin:
		tone = UiTheme.COLOR_ON_SURFACE_VARIANT
	_status_chip.add_theme_stylebox_override("panel", UiTheme.box(Color(tone, 0.12), UiTheme.RADIUS_SM, Color(tone, 0.6), 1, Vector4(14, 10, 14, 10)))
	_status_icon.kind = icon
	_status_icon.color = tone
	_status_icon.visible = not spin
	_spinner.visible = spin
	_status_label.add_theme_color_override("font_color", tone if is_error else UiTheme.COLOR_ON_SURFACE)


## Rebuilds the discovered-host rows. Only called when LanSession says the list changed.
func _render_hosts(list: Array) -> void:
	if _hosts_list == null:
		return
	for c in _hosts_list.get_children():
		c.queue_free()
	_host_rows.clear()
	var busy := _busy()
	for h in list:
		var ip := str(h.get("ip", ""))
		if ip == "":
			continue
		var row := PanelContainer.new()
		row.name = "HostRow_" + ip.replace(".", "_")
		row.add_theme_stylebox_override("panel", UiTheme.box(Color(UiTheme.COLOR_PRIMARY, 0.10), UiTheme.RADIUS_SM, Color(UiTheme.COLOR_PRIMARY, 0.45), 1, Vector4(12, 8, 12, 8)))
		_hosts_list.add_child(row)
		var hb := HBoxContainer.new()
		hb.layout_direction = Control.LAYOUT_DIRECTION_RTL
		hb.add_theme_constant_override("separation", UiTheme.SPACE_3)
		row.add_child(hb)
		hb.add_child(UiIcon.make("check", 20, UiTheme.COLOR_SUCCESS))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(col)
		col.add_child(UiTheme.label("میزبان آماده است", "LabelStrong"))
		var ip_lbl := UiTheme.ltr_label(ip, "CaptionLabel")
		ip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(ip_lbl)
		var connect_btn := UiTheme.make_button("اتصال", "ConnectHost", true, Vector2(0, UiTheme.TOUCH_MIN), "primary", "forward")
		connect_btn.disabled = busy
		connect_btn.set_meta("ip", ip)
		connect_btn.pressed.connect(_on_host_connect_pressed.bind(ip))
		hb.add_child(connect_btn)
		_host_rows[ip] = connect_btn
	_hosts_empty.visible = list.is_empty()
	if list.is_empty():
		_hosts_hint.visible = false
	else:
		_hosts_hint.text = "%d میزبان روی این شبکه پیدا شد؛ برای ورود روی «اتصال» بزنید." % list.size()
		_hosts_hint.visible = true


func _on_hosts_changed(list: Array) -> void:
	if not is_inside_tree():
		return
	_render_hosts(list)
	_refresh_buttons()


func _on_search_pressed() -> void:
	LanSession.refresh_hosts()
	if LanSession.hosts.is_empty():
		_hosts_empty.text = "هنوز میزبانی پیدا نشد. روی دستگاه دوم «ساخت اتاق» را بزنید."
		_hosts_empty.visible = true


func _on_host_connect_pressed(ip: String) -> void:
	_set_ip_error("")
	_ip_field.text = ip
	LanSession.join_room(ip)
	_refresh_buttons()


func _on_status_changed(msg: String) -> void:
	if not is_inside_tree():
		return
	_show_status(msg, _error_shown and LanSession.state == LanSession.State.IDLE)
	_error_shown = false
	_refresh_buttons()


func _on_lan_error(msg: String) -> void:
	if not is_inside_tree():
		return
	_error_shown = true
	_show_status(msg, true)
	_refresh_buttons()


func _set_ip_error(msg: String) -> void:
	_ip_error.text = msg
	_ip_error.visible = not msg.is_empty()
	_ip_field.theme_type_variation = "ErrorLineEdit" if not msg.is_empty() else ""


func _on_create_pressed() -> void:
	LanSession.host_room()
	_refresh_buttons()
	_cancel_btn.grab_focus()


func _on_join_pressed() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip.is_empty():
		_set_ip_error("نشانی IP میزبان را وارد کنید.")
		_ip_field.grab_focus()
		return
	if _re.search(ip) == null:
		_set_ip_error("این نشانی معتبر نیست؛ چهار عدد با نقطه، مثل 192.168.1.2")
		_ip_field.grab_focus()
		return
	_set_ip_error("")
	LanSession.join_room(ip)
	_refresh_buttons()
	_cancel_btn.grab_focus()


func _on_cancel_pressed() -> void:
	LanSession.cancel()
	_refresh_buttons()
	_create_btn.grab_focus()


func _on_back_pressed() -> void:
	LanSession.cancel()
	LanSession.open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_back"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()
