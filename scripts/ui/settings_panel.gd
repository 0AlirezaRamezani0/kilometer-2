class_name SettingsPanel
extends PanelContainer

## Kilometer 2 settings (v0.1-b3, "Proving Ground" design system).
## One component, two hosts: the main-menu modal and the pause drawer.
##
##   0 نمایش       display & graphics, on-screen info
##   1 صدا         5-bus mixer, music mode, ducking, test cue
##   2 دوربین      FOV, smoothing, distance, impact shake
##   3 کنترل‌ها     gamepad deadzone/vibration, touch controls, steer mode
##   4 دسترسی      UI scale, reduced motion
##
## Behaviour:
## - Every change applies live to its own domain only (an audio slider no
##   longer re-applies the graphics tier), then saves after a short debounce
##   and shows a «ذخیره شد» chip (audit A-13).
## - Rows reflow by flipping BoxContainer.vertical (wide = one line, narrow =
##   label above control). Nodes are never rebuilt, so references, focus and
##   UI sounds survive every resize.
## - LB/RB or Q/E switch tabs; the host traps focus and handles Esc/B
##   through handle_cancel().

signal settings_changed
signal close_requested

## Below this panel width rows stack and the tab grid wraps.
const COMPACT_WIDTH := 500.0
const SAVE_DEBOUNCE_SEC := 0.35
const TAB_DEFS := [
	["نمایش", "display"],
	["صدا", "volume"],
	["دوربین", "cameraview"],
	["کنترل‌ها", "gamepad"],
	["دسترسی", "access"],
]
const GFX_NAMES := ["سریع", "متعادل", "کیفیت بالا"]
const GFX_HINTS := [
	"وضوح سه‌بعدی ۸۰٪ و بدون ضدلبه؛ روان‌ترین حالت برای گوشی‌های ضعیف.",
	"وضوح کامل با ضدلبهٔ ۲×؛ تعادل کیفیت و روانی.",
	"وضوح کامل با ضدلبهٔ ۴× و سایهٔ دقیق‌تر؛ برای دستگاه‌های قوی.",
]
const STEER_NAMES := ["دکمه‌ها", "فرمان", "نوار"]
const STEER_HINTS := [
	"دو دکمهٔ چپ و راست؛ ساده و مطمئن.",
	"غربیلک چرخان؛ دقیق‌ترین کنترل لمسی.",
	"نوار آنالوگ افقی؛ فرمان تدریجی با یک انگشت.",
]

var _hud: VehicleHud = null
var _rig: VehicleCameraRig = null

# Widgets (names kept for hosts/tests).
var _fullscreen_check: CheckButton
var _gfx_option: Segmented
var _gfx_hint: Label
var _perf_check: CheckButton
var _diag_check: CheckButton = null
var _volume_slider: HSlider
var _volume_value: Label
var _engine_vol_slider: HSlider
var _engine_vol_value: Label
var _music_vol_slider: HSlider
var _music_vol_value: Label
var _sfx_vol_slider: HSlider
var _sfx_vol_value: Label
var _ui_vol_slider: HSlider
var _ui_vol_value: Label
var _music_mode_option: OptionButton
var _ducking_check: CheckButton
var _fov_slider: HSlider
var _fov_value: Label
var _smooth_slider: HSlider
var _smooth_value: Label
var _dist_slider: HSlider
var _dist_value: Label
var _shake_slider: HSlider
var _shake_value: Label
var _deadzone_slider: HSlider
var _deadzone_value: Label
var _vibration_slider: HSlider
var _vibration_value: Label
var _touch_check: CheckButton
var _steer_option: Segmented
var _steer_hint: Label
var _scale_slider: HSlider
var _scale_value: Label
var _motion_check: CheckButton

var close_button: Button = null
var reset_button: Button = null

var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _tab_group := ButtonGroup.new()
var _rows: Array[BoxContainer] = []
var _active_tab: int = 0
var _compact: bool = false
var _syncing: bool = false

var _outer: VBoxContainer = null
var _tab_row: GridContainer = null
var _scroll: ScrollContainer = null
var _pages_host: VBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _saved_chip: PanelContainer = null
var _save_timer: Timer = null
var _scale_timer: Timer = null
var _confirm: Control = null
var _confirm_card: PanelContainer = null


## Segmented button group with the subset of the OptionButton API the panel
## and its tests use (item_count, selected, select(), item_selected).
class Segmented extends HBoxContainer:
	signal item_selected(index: int)
	var _group := ButtonGroup.new()
	var _buttons: Array[Button] = []
	var selected: int = -1
	var item_count: int:
		get:
			return _buttons.size()

	func _init() -> void:
		layout_direction = Control.LAYOUT_DIRECTION_RTL
		add_theme_constant_override("separation", UiTheme.SPACE_2)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func add_item(text: String) -> void:
		var b := UiTheme.make_button(text, "Segment%d" % _buttons.size(), false, Vector2(0, UiTheme.TOUCH_MIN), "tab")
		b.button_group = _group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var idx := _buttons.size()
		b.pressed.connect(func() -> void:
			if selected != idx:
				selected = idx
				item_selected.emit(idx))
		add_child(b)
		_buttons.append(b)

	func select(idx: int) -> void:
		selected = clampi(idx, 0, _buttons.size() - 1)
		for i in range(_buttons.size()):
			_buttons[i].set_pressed_no_signal(i == selected)

	func get_button(idx: int) -> Button:
		return _buttons[idx]


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	theme = UiTheme.get_theme()
	theme_type_variation = "GlassPanel"
	custom_minimum_size = Vector2(280, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	SettingsManager.ensure_loaded()
	_build_shell()
	_build_pages()
	_build_confirm()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DEBOUNCE_SEC
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)
	_scale_timer = Timer.new()
	_scale_timer.one_shot = true
	_scale_timer.wait_time = 0.6
	_scale_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_scale_timer.timeout.connect(_apply_ui_scale_now)
	add_child(_scale_timer)
	resized.connect(_update_responsive)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			flush_pending())
	_sync_controls_from_settings()
	_select_tab(0, true)
	_update_responsive()
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("attach_ui_sounds"):
		am.call("attach_ui_sounds", self)


# ------------------------------------------------------------------ public
func refresh_from_settings() -> void:
	_sync_controls_from_settings()


func bind_systems(hud: VehicleHud, rig: VehicleCameraRig) -> void:
	_hud = hud
	_rig = rig
	_sync_controls_from_settings()


func select_audio_tab() -> void:
	_select_tab(1)


func tab_count() -> int:
	return _tab_buttons.size()


## Control that should receive focus when a host opens the panel.
func default_focus() -> Control:
	return _tab_buttons[_active_tab] if _active_tab < _tab_buttons.size() else null


## Esc / B inside the panel: closes the reset confirmation first.
func handle_cancel() -> bool:
	if _confirm != null and _confirm.visible:
		_close_confirm()
		return true
	return false


## Saves immediately if a debounced save is pending (called on close).
func flush_pending() -> void:
	if _save_timer != null and not _save_timer.is_stopped():
		_save_timer.stop()
		_flush_save()
	if _scale_timer != null and not _scale_timer.is_stopped():
		_scale_timer.stop()
		_apply_ui_scale_now()


# ------------------------------------------------------------------- shell
func _build_shell() -> void:
	_outer = VBoxContainer.new()
	_outer.name = "SettingsOuter"
	_outer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_outer.add_theme_constant_override("separation", UiTheme.SPACE_4)
	add_child(_outer)

	var hdr := HBoxContainer.new()
	hdr.name = "SettingsHeader"
	hdr.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hdr.add_theme_constant_override("separation", UiTheme.SPACE_3)
	_outer.add_child(hdr)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_col)
	var heading := UiTheme.make_heading("تنظیمات", "HeadlineLabel")
	_title_label = heading.get_node("HeadingText") as Label
	_title_label.name = "SettingsTitle"
	title_col.add_child(heading)
	_subtitle_label = UiTheme.label("تغییرات خودکار ذخیره می‌شوند.", "CaptionLabel")
	_subtitle_label.name = "SettingsSubtitle"
	title_col.add_child(_subtitle_label)
	_saved_chip = PanelContainer.new()
	_saved_chip.name = "SavedChip"
	_saved_chip.add_theme_stylebox_override("panel", UiTheme.chip_style_for(UiTheme.COLOR_SUCCESS))
	_saved_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_saved_chip.modulate.a = 0.0
	_saved_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_row := HBoxContainer.new()
	chip_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	chip_row.add_theme_constant_override("separation", 6)
	chip_row.add_child(UiIcon.make("check", 18, UiTheme.COLOR_SUCCESS))
	var chip_lbl := UiTheme.label("ذخیره شد", "LabelStrong")
	chip_lbl.add_theme_color_override("font_color", UiTheme.COLOR_SUCCESS)
	chip_row.add_child(chip_lbl)
	_saved_chip.add_child(chip_row)
	hdr.add_child(_saved_chip)

	_tab_row = GridContainer.new()
	_tab_row.name = "SettingsTabBar"
	_tab_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_tab_row.columns = TAB_DEFS.size()
	_tab_row.add_theme_constant_override("h_separation", UiTheme.SPACE_2)
	_tab_row.add_theme_constant_override("v_separation", UiTheme.SPACE_2)
	_outer.add_child(_tab_row)
	for i in range(TAB_DEFS.size()):
		var tb := UiTheme.make_button(TAB_DEFS[i][0], "SettingsTab%d" % i, false, Vector2(0, UiTheme.TOUCH_MIN), "tab", TAB_DEFS[i][1])
		tb.button_group = _tab_group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.clip_text = true
		var tid := i
		tb.pressed.connect(func() -> void: _select_tab(tid))
		_tab_row.add_child(tb)
		_tab_buttons.append(tb)

	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_outer.add_child(_scroll)
	_pages_host = VBoxContainer.new()
	_pages_host.name = "SettingsPages"
	_pages_host.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages_host.add_theme_constant_override("separation", 0)
	_scroll.add_child(_pages_host)

	var footer := HBoxContainer.new()
	footer.name = "SettingsFooter"
	footer.layout_direction = Control.LAYOUT_DIRECTION_RTL
	footer.add_theme_constant_override("separation", UiTheme.SPACE_3)
	_outer.add_child(footer)
	reset_button = UiTheme.make_button("بازنشانی پیش‌فرض‌ها", "SettingsResetButton", false, Vector2(0, UiTheme.TOUCH_MIN), "ghost", "restart")
	reset_button.pressed.connect(_open_confirm)
	footer.add_child(reset_button)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(sp)
	close_button = UiTheme.make_button("بستن", "SettingsCloseButton", false, Vector2(148, UiTheme.TOUCH_MIN), "secondary", "close")
	close_button.pressed.connect(func() -> void:
		flush_pending()
		close_requested.emit())
	footer.add_child(close_button)


# -------------------------------------------------------------------- rows
func _page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.layout_direction = Control.LAYOUT_DIRECTION_RTL
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", UiTheme.SPACE_3)
	_pages_host.add_child(page)
	_tab_pages.append(page)
	return page


func _heading(parent: VBoxContainer, text: String) -> void:
	var h := UiTheme.make_heading(text, "SectionLabel")
	h.name = "Heading"
	parent.add_child(h)


## A setting row: [title (+ description)] [control (+ value)].
## Wide: one line. Compact: the title block sits above the control.
func _row(parent: VBoxContainer, key: String, title: String, desc: String = "") -> Array:
	var row := BoxContainer.new()
	row.name = "Row_" + key
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", UiTheme.SPACE_3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	_rows.append(row)
	var text_col := VBoxContainer.new()
	text_col.name = "RowText"
	text_col.add_theme_constant_override("separation", 2)
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)
	var t := UiTheme.label(title, "LabelStrong")
	t.name = "RowTitle"
	text_col.add_child(t)
	if not desc.is_empty():
		var d := UiTheme.label(desc, "CaptionLabel", true)
		d.name = "RowDesc"
		text_col.add_child(d)
	var ctl := HBoxContainer.new()
	ctl.name = "RowControls"
	ctl.layout_direction = Control.LAYOUT_DIRECTION_RTL
	ctl.add_theme_constant_override("separation", UiTheme.SPACE_3)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ctl)
	return [row, text_col, ctl]


func _slider_row(parent: VBoxContainer, key: String, title: String, min_v: float, max_v: float, step: float, desc: String = "") -> Array:
	var parts := _row(parent, key, title, desc)
	var ctl: HBoxContainer = parts[2]
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(120, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.accessibility_name = title
	slider.accessibility_description = desc
	ctl.add_child(slider)
	var val := UiTheme.label("", "ValueLabel")
	val.name = "Value"
	val.custom_minimum_size = Vector2(84, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctl.add_child(val)
	return [slider, val]


func _toggle_row(parent: VBoxContainer, key: String, title: String, desc: String = "") -> CheckButton:
	var parts := _row(parent, key, title, desc)
	var ctl: HBoxContainer = parts[2]
	var c := CheckButton.new()
	c.name = "Toggle"
	c.focus_mode = Control.FOCUS_ALL
	c.custom_minimum_size = Vector2(76, UiTheme.TOUCH_MIN)
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	c.alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.text = ""
	c.tooltip_text = title
	c.accessibility_name = title
	c.accessibility_description = desc
	ctl.add_child(c)
	# A switch is small: its row stays on one line even when narrow.
	(parts[0] as BoxContainer).set_meta("keep_inline", true)
	return c


func _segmented_row(parent: VBoxContainer, key: String, title: String, items: Array, desc: String = "") -> Segmented:
	var parts := _row(parent, key, title, desc)
	var ctl: HBoxContainer = parts[2]
	var seg := Segmented.new()
	seg.name = "Segmented"
	for it in items:
		seg.add_item(str(it))
	for i in range(seg.item_count):
		seg.get_button(i).accessibility_name = "%s: %s" % [title, str(items[i])]
		seg.get_button(i).accessibility_description = desc
	ctl.add_child(seg)
	return seg


func _option_row(parent: VBoxContainer, key: String, title: String, items: Array, desc: String = "") -> OptionButton:
	var parts := _row(parent, key, title, desc)
	var ctl: HBoxContainer = parts[2]
	var opt := OptionButton.new()
	opt.name = "Option"
	opt.text_direction = Control.TEXT_DIRECTION_RTL
	opt.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for item in items:
		opt.add_item(str(item))
	opt.custom_minimum_size = Vector2(0, UiTheme.TOUCH_MIN)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.focus_mode = Control.FOCUS_ALL
	opt.accessibility_name = title
	opt.accessibility_description = desc
	var popup := opt.get_popup()
	popup.set_layout_direction(Window.LAYOUT_DIRECTION_RTL)
	popup.theme = UiTheme.get_theme()
	ctl.add_child(opt)
	return opt


# ------------------------------------------------------------------- pages
func _build_pages() -> void:
	# 0 — display
	var p0 := _page()
	_heading(p0, "صفحه و گرافیک")
	_fullscreen_check = _toggle_row(p0, "fullscreen", "تمام‌صفحه", "پنجرهٔ بازی کل صفحه‌نمایش را می‌گیرد.")
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		SettingsManager.fullscreen = on
		_changed("display"))
	if OS.has_feature("mobile"):
		_fullscreen_check.get_parent().get_parent().visible = false
	_gfx_option = _segmented_row(p0, "graphics", "کیفیت گرافیک", GFX_NAMES)
	_gfx_hint = UiTheme.label("", "CaptionLabel", true)
	_gfx_hint.name = "GraphicsHint"
	p0.add_child(_gfx_hint)
	_gfx_option.item_selected.connect(func(idx: int) -> void:
		SettingsManager.graphics_tier = idx
		_gfx_hint.text = GFX_HINTS[idx]
		_changed("graphics"))
	_heading(p0, "اطلاعات روی صفحه")
	_perf_check = _toggle_row(p0, "perf", "نمایش آمار فنی", "نرخ فریم و تعداد فراخوانی رسم در نوار بالای رانندگی.")
	_perf_check.toggled.connect(func(on: bool) -> void:
		SettingsManager.show_perf = on
		_changed("hud"))

	# 1 — audio
	var p1 := _page()
	_heading(p1, "میکسر صدا")
	var vol := _slider_row(p1, "master_volume", "صدای اصلی", -40.0, 0.0, 1.0)
	_volume_slider = vol[0]; _volume_value = vol[1]
	_volume_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.master_volume_db = v
		_volume_value.text = UiTheme.fa_percent((v + 40.0) / 40.0)
		_changed("audio"))
	var ev := _slider_row(p1, "engine_volume", "موتور و اگزوز", 0.0, 1.0, 0.05)
	_engine_vol_slider = ev[0]; _engine_vol_value = ev[1]
	_engine_vol_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.engine_volume = v
		_engine_vol_value.text = UiTheme.fa_percent(v)
		_changed("audio"))
	var mv := _slider_row(p1, "music_volume", "موسیقی", 0.0, 1.0, 0.05)
	_music_vol_slider = mv[0]; _music_vol_value = mv[1]
	_music_vol_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.music_volume = v
		_music_vol_value.text = UiTheme.fa_percent(v)
		_changed("audio"))
	var sv := _slider_row(p1, "sfx_volume", "لاستیک، باد و ضربه", 0.0, 1.0, 0.05)
	_sfx_vol_slider = sv[0]; _sfx_vol_value = sv[1]
	_sfx_vol_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.sfx_volume = v
		_sfx_vol_value.text = UiTheme.fa_percent(v)
		_changed("audio"))
	var uv := _slider_row(p1, "ui_volume", "صدای منو", 0.0, 1.0, 0.05)
	_ui_vol_slider = uv[0]; _ui_vol_value = uv[1]
	_ui_vol_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.ui_volume = v
		_ui_vol_value.text = UiTheme.fa_percent(v)
		_changed("audio"))
	_heading(p1, "موسیقی")
	_music_mode_option = _option_row(p1, "music_mode", "حالت موسیقی", [
		"پویا (خودکار)", "انرژیک", "بزرگراه شب", "آرام نمایشگاه", "خاموش",
	])
	_music_mode_option.item_selected.connect(func(idx: int) -> void:
		SettingsManager.music_track_mode = idx
		_changed("audio"))
	_ducking_check = _toggle_row(p1, "ducking", "تنظیم خودکار موسیقی", "هنگام توقف و دور بالای موتور، موسیقی آرام‌تر می‌شود.")
	_ducking_check.toggled.connect(func(on: bool) -> void:
		SettingsManager.dynamic_music_ducking = on
		_changed("audio"))
	var test_btn := UiTheme.make_button("پخش صدای آزمایشی", "AudioTestButton", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary", "volume")
	test_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	test_btn.pressed.connect(func() -> void:
		var am := get_node_or_null("/root/AudioManager")
		if am != null and am.has_method("play_audio_test_cue"):
			am.call("play_audio_test_cue"))
	p1.add_child(test_btn)

	# 2 — camera
	var p2 := _page()
	_heading(p2, "دوربین تعقیب")
	var fov := _slider_row(p2, "fov", "میدان دید", 45.0, 75.0, 1.0)
	_fov_slider = fov[0]; _fov_value = fov[1]
	_fov_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.cam_fov_deg = v
		_fov_value.text = UiTheme.fa_int(int(round(v))) + "°"
		_changed("camera"))
	var sm := _slider_row(p2, "smoothing", "سرعت دنبال‌کردن", 2.0, 20.0, 0.5, "عدد بزرگ‌تر: دوربین سریع‌تر به پشت خودرو برمی‌گردد.")
	_smooth_slider = sm[0]; _smooth_value = sm[1]
	_smooth_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.cam_smoothing = v
		_smooth_value.text = UiTheme.fa_float(v, 1)
		_changed("camera"))
	var dist := _slider_row(p2, "distance", "فاصلهٔ دوربین", 3.5, 8.5, 0.1)
	_dist_slider = dist[0]; _dist_value = dist[1]
	_dist_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.cam_distance_m = v
		_dist_value.text = UiTheme.fa_float(v, 1) + " متر"
		_changed("camera"))
	var shk := _slider_row(p2, "shake", "لرزش هنگام ضربه", 0.0, 1.0, 0.05)
	_shake_slider = shk[0]; _shake_value = shk[1]
	_shake_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.cam_shake = v
		_shake_value.text = UiTheme.fa_percent(v)
		_changed("camera"))

	# 3 — controls
	var p3 := _page()
	_heading(p3, "دستهٔ بازی")
	var dz := _slider_row(p3, "deadzone", "ناحیهٔ مردهٔ آنالوگ", 0.05, 0.35, 0.01, "حرکت‌های کوچک‌تر از این مقدار نادیده گرفته می‌شوند.")
	_deadzone_slider = dz[0]; _deadzone_value = dz[1]
	_deadzone_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.joy_deadzone = v
		_deadzone_value.text = UiTheme.fa_percent(v)
		_changed("controls"))
	var vib := _slider_row(p3, "vibration", "لرزش دسته", 0.0, 1.0, 0.05)
	_vibration_slider = vib[0]; _vibration_value = vib[1]
	_vibration_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.joy_vibration = v
		_vibration_value.text = UiTheme.fa_percent(v)
		_changed("controls"))
	_heading(p3, "کنترل‌های لمسی")
	_touch_check = _toggle_row(p3, "touch", "نمایش کنترل‌های لمسی", "کنار دستهٔ بازی هم قابل استفاده می‌مانند.")
	_touch_check.toggled.connect(func(on: bool) -> void:
		SettingsManager.show_touch_controls = on
		_changed("hud"))
	_steer_option = _segmented_row(p3, "steer_mode", "نوع فرمان لمسی", STEER_NAMES)
	_steer_hint = UiTheme.label("", "CaptionLabel", true)
	_steer_hint.name = "SteerHint"
	p3.add_child(_steer_hint)
	_steer_option.item_selected.connect(func(idx: int) -> void:
		SettingsManager.steer_mode = idx
		_steer_hint.text = STEER_HINTS[idx]
		_changed("hud"))

	# 4 — accessibility
	var p4 := _page()
	_heading(p4, "خوانایی")
	var sc := _slider_row(p4, "ui_scale", "اندازهٔ رابط کاربری", SettingsManager.UI_SCALE_MIN, SettingsManager.UI_SCALE_MAX, 0.05,
		"متن، دکمه‌ها و کنترل‌های لمسی همهٔ صفحه‌ها را بزرگ یا کوچک می‌کند.")
	_scale_slider = sc[0]; _scale_value = sc[1]
	_scale_slider.value_changed.connect(func(v: float) -> void:
		SettingsManager.ui_scale = snappedf(v, 0.05)
		_scale_value.text = UiTheme.fa_percent(v)
		_changed("ui_scale"))
	_scale_slider.drag_ended.connect(func(_c: bool) -> void:
		if _scale_timer != null:
			_scale_timer.stop()
		_apply_ui_scale_now())
	_heading(p4, "حرکت")
	_motion_check = _toggle_row(p4, "reduce_motion", "کاهش حرکت",
		"انیمیشن‌های رابط، چرخش خودکار دوربین نمایشگاه و پرش دکمه‌ها خاموش می‌شوند.")
	_motion_check.toggled.connect(func(on: bool) -> void:
		SettingsManager.reduce_motion = on
		_changed("motion"))


# ----------------------------------------------------------- reset confirm
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.name = "ResetConfirm"
	_confirm.visible = false
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirm)
	var scrim := ColorRect.new()
	scrim.color = Color(UiTheme.COLOR_BG, 0.82)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	_confirm_card = PanelContainer.new()
	_confirm_card.theme_type_variation = "DialogPanel"
	_confirm_card.custom_minimum_size = Vector2(260, 0)
	center.add_child(_confirm_card)
	var v := VBoxContainer.new()
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_confirm_card.add_child(v)
	v.add_child(UiTheme.label("بازنشانی همهٔ تنظیمات؟", "TitleLabel"))
	var body := UiTheme.label("گرافیک، صدا، دوربین، کنترل‌ها و دسترسی به مقدار پیش‌فرض برمی‌گردند. خودروی انتخاب‌شده تغییر نمی‌کند.", "BodyMutedLabel", true)
	body.custom_minimum_size = Vector2(220, 0)
	v.add_child(body)
	var actions := HBoxContainer.new()
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.add_theme_constant_override("separation", UiTheme.SPACE_3)
	v.add_child(actions)
	var cancel := UiTheme.make_button("انصراف", "ResetCancelButton", false, Vector2(0, UiTheme.TOUCH_MIN), "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_confirm)
	actions.add_child(cancel)
	var ok := UiTheme.make_button("بازنشانی", "ResetConfirmButton", false, Vector2(0, UiTheme.TOUCH_MIN), "danger", "restart")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_do_reset)
	actions.add_child(ok)


func _open_confirm() -> void:
	_outer.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	_outer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	_confirm.visible = true
	(_confirm.find_child("ResetCancelButton", true, false) as Button).grab_focus()


func _close_confirm() -> void:
	_confirm.visible = false
	_outer.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_outer.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	if reset_button != null:
		reset_button.grab_focus()


func _do_reset() -> void:
	var old_tier := SettingsManager.graphics_tier
	SettingsManager.reset_to_defaults()
	_sync_controls_from_settings()
	SettingsManager.apply_window_mode()
	SettingsManager.apply_audio()
	SettingsManager.apply_camera(_rig)
	SettingsManager.apply_hud(_hud)
	if SettingsManager.graphics_tier != old_tier:
		_apply_graphics()
	_apply_ui_scale_now()
	_close_confirm()
	_schedule_save()
	settings_changed.emit()


# ---------------------------------------------------------------- behaviour
func _select_tab(idx: int, silent: bool = false) -> void:
	_active_tab = clampi(idx, 0, maxi(0, _tab_pages.size() - 1))
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == _active_tab)
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _active_tab)
	if _scroll != null:
		_scroll.scroll_vertical = 0
	if silent or not is_inside_tree():
		return
	var page := _tab_pages[_active_tab]
	var d := UiTheme.fade_sec(UiTheme.MOTION_FAST_MS + 40.0)
	if d > 0.0:
		page.modulate.a = 0.0
		create_tween().tween_property(page, "modulate:a", 1.0, d)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or (_confirm != null and _confirm.visible):
		return
	# RTL tab row: tab 0 is rightmost, so the LEFT input moves to the next tab.
	if event.is_action_pressed("ui_page_left"):
		_select_tab((_active_tab + 1) % _tab_buttons.size())
		_tab_buttons[_active_tab].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_right"):
		_select_tab((_active_tab - 1 + _tab_buttons.size()) % _tab_buttons.size())
		_tab_buttons[_active_tab].grab_focus()
		get_viewport().set_input_as_handled()


func _update_responsive() -> void:
	var w := size.x
	if w <= 1.0:
		w = get_viewport_rect().size.x
	var compact := w < COMPACT_WIDTH
	if compact == _compact and _rows.size() > 0 and _tab_row.columns == (3 if compact else TAB_DEFS.size()):
		return
	_compact = compact
	_tab_row.columns = 3 if compact else TAB_DEFS.size()
	for r in _rows:
		var inline := bool(r.get_meta("keep_inline", false))
		r.vertical = compact and not inline
		var text_col := r.get_node("RowText") as Control
		var ctl := r.get_node("RowControls") as Control
		if inline:
			text_col.custom_minimum_size = Vector2(0, 0)
			text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ctl.size_flags_horizontal = Control.SIZE_SHRINK_END
		else:
			text_col.custom_minimum_size = Vector2(0, 0) if compact else Vector2(196, 0)
			text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	if _subtitle_label != null:
		_subtitle_label.visible = not compact


func _changed(domain: String) -> void:
	if _syncing:
		return
	match domain:
		"display":
			SettingsManager.apply_window_mode()
		"graphics":
			_apply_graphics()
		"audio":
			SettingsManager.apply_audio()
		"camera":
			SettingsManager.apply_camera(_rig)
		"hud", "controls":
			SettingsManager.apply_hud(_hud)
		"ui_scale":
			# Applied on release (drag_ended) or after a pause for keys/pad,
			# so the layout does not jump under the player's finger.
			_scale_timer.start()
	_schedule_save()
	settings_changed.emit()


func _apply_graphics() -> void:
	if _hud != null:
		_hud.apply_graphics_quality(SettingsManager.graphics_tier)
	else:
		SettingsManager.apply_viewport_graphics(get_viewport())


func _apply_ui_scale_now() -> void:
	SettingsManager.apply_ui_scale()


func _schedule_save() -> void:
	if _save_timer != null and _save_timer.is_inside_tree():
		_save_timer.start()
	else:
		_flush_save()


func _flush_save() -> void:
	var err := SettingsManager.save_settings()
	if err == OK:
		_show_saved_chip()


func _show_saved_chip() -> void:
	if _saved_chip == null or not is_inside_tree():
		return
	_saved_chip.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_saved_chip, "modulate:a", 0.0, UiTheme.fade_sec(UiTheme.MOTION_MEDIUM_MS))


func _sync_controls_from_settings() -> void:
	if _fullscreen_check == null:
		return
	_syncing = true
	_fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
	_gfx_option.select(SettingsManager.graphics_tier)
	_gfx_hint.text = GFX_HINTS[clampi(SettingsManager.graphics_tier, 0, 2)]
	_perf_check.set_pressed_no_signal(SettingsManager.show_perf)
	_volume_slider.set_value_no_signal(SettingsManager.master_volume_db)
	_volume_value.text = UiTheme.fa_percent((SettingsManager.master_volume_db + 40.0) / 40.0)
	_engine_vol_slider.set_value_no_signal(SettingsManager.engine_volume)
	_engine_vol_value.text = UiTheme.fa_percent(SettingsManager.engine_volume)
	_music_vol_slider.set_value_no_signal(SettingsManager.music_volume)
	_music_vol_value.text = UiTheme.fa_percent(SettingsManager.music_volume)
	_sfx_vol_slider.set_value_no_signal(SettingsManager.sfx_volume)
	_sfx_vol_value.text = UiTheme.fa_percent(SettingsManager.sfx_volume)
	_ui_vol_slider.set_value_no_signal(SettingsManager.ui_volume)
	_ui_vol_value.text = UiTheme.fa_percent(SettingsManager.ui_volume)
	_music_mode_option.select(SettingsManager.music_track_mode)
	_ducking_check.set_pressed_no_signal(SettingsManager.dynamic_music_ducking)
	_fov_slider.set_value_no_signal(SettingsManager.cam_fov_deg)
	_fov_value.text = UiTheme.fa_int(int(round(SettingsManager.cam_fov_deg))) + "°"
	_smooth_slider.set_value_no_signal(SettingsManager.cam_smoothing)
	_smooth_value.text = UiTheme.fa_float(SettingsManager.cam_smoothing, 1)
	_dist_slider.set_value_no_signal(SettingsManager.cam_distance_m)
	_dist_value.text = UiTheme.fa_float(SettingsManager.cam_distance_m, 1) + " متر"
	_shake_slider.set_value_no_signal(SettingsManager.cam_shake)
	_shake_value.text = UiTheme.fa_percent(SettingsManager.cam_shake)
	_deadzone_slider.set_value_no_signal(SettingsManager.joy_deadzone)
	_deadzone_value.text = UiTheme.fa_percent(SettingsManager.joy_deadzone)
	_vibration_slider.set_value_no_signal(SettingsManager.joy_vibration)
	_vibration_value.text = UiTheme.fa_percent(SettingsManager.joy_vibration)
	_touch_check.set_pressed_no_signal(SettingsManager.show_touch_controls)
	_steer_option.select(SettingsManager.steer_mode)
	_steer_hint.text = STEER_HINTS[clampi(SettingsManager.steer_mode, 0, 2)]
	_scale_slider.set_value_no_signal(SettingsManager.ui_scale)
	_scale_value.text = UiTheme.fa_percent(SettingsManager.ui_scale)
	_motion_check.set_pressed_no_signal(SettingsManager.reduce_motion)
	_syncing = false
