class_name PersianGaugeCluster
extends Control

## Kilometer 2 — instrument cluster (v0.1-b3, vector).
## Same composition the player approved in B8/B9.1 — two analog dials
## (tachometer left, speedometer right = RTL primary) with a gear column in
## the middle, borderless on the scene, ≥ 29 % of the canvas width — but
## drawn in code from the design tokens so every number is true:
##   - speedometer scale is km/h (the old kit face printed «MPH»), with a
##     large digital readout for at-a-glance reading;
##   - tachometer shows the real engine rpm (idle 950 → redline 6 300 from
##     SaipaVehicleController) and its red zone starts at the real redline
##     (the old face printed 9 000 and the needle used norm × 7000);
##   - the gear column shows D/N/R (letter + colour) plus the automatic gear;
##   - lamps change shape when on (filled disc) — colour is never the only cue;
##   - throttle/brake input bars follow the telemetry convention (green/red).
## Public API is unchanged (update_telemetry / set_telemetry).

@export var max_speed_kmh: float = 200.0
@export var max_rpm: float = 7000.0
@export var redline_rpm: float = SaipaVehicleController.ENGINE_REDLINE_RPM

## 240° sweep: the open bottom of the dial holds the digital readout, and the
## end labels sit on the sides instead of under the numbers.
const DIAL_SWEEP_DEG := 240.0
const DIAL_START_DEG := 150.0 # Godot angles: 0 = +x, clockwise; 150° = lower-left
const SPEED_SCALE_MAX := 220.0

var speed_kmh: float = 0.0
var rpm: float = SaipaVehicleController.ENGINE_IDLE_RPM
var gear_text: String = "خلاص"
var gear_code: String = "N"
var gear_index: int = 0
var braking: bool = false
var handbrake: bool = false
var headlights: bool = false
var throttle_ratio: float = 0.0
var brake_ratio: float = 0.0

var _font_num: Font = null
var _font_bold: Font = null
var _font_med: Font = null
## B9.1 guard (tests): the cluster never draws a boxed plate.
var _plate_sb: StyleBoxFlat = null
## Real Label nodes for the readouts (crisp text, testable, readable by
## screen readers): digital speed, its unit, and the gear caption.
var speed_label: Label = null
var unit_label: Label = null
var gear_caption: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font_num = UiTheme.font_changa_xbold()
	_font_bold = UiTheme.font_bold()
	_font_med = UiTheme.font_medium()
	if _font_bold == null:
		_font_bold = ThemeDB.fallback_font
	if _font_num == null:
		_font_num = _font_bold
	if _font_med == null:
		_font_med = _font_bold
	_plate_sb = null
	speed_label = Label.new()
	speed_label.name = "SpeedValueLabel"
	speed_label.theme_type_variation = "NumericLabel"
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_label.text = "0"
	add_child(speed_label)
	unit_label = UiTheme.label("کیلومتر/ساعت", "CaptionLabel")
	unit_label.name = "SpeedUnitLabel"
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(unit_label)
	gear_caption = UiTheme.label("حرکت", "LabelStrong")
	gear_caption.name = "GearCaptionLabel"
	gear_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gear_caption)
	resized.connect(_layout_labels)
	_layout_labels()
	_update_label_texts()


## p_rpm_norm is the controller's normalized rpm (idle → redline).
func update_telemetry(
	p_speed_kmh: float,
	p_rpm_norm: float,
	p_gear_code: String,
	p_braking: bool,
	p_handbrake: bool,
	p_headlights: bool,
	p_throttle: float = -1.0,
	p_brake: float = -1.0,
	p_gear_index: int = 0
) -> void:
	var idle := SaipaVehicleController.ENGINE_IDLE_RPM
	var red := SaipaVehicleController.ENGINE_REDLINE_RPM
	var real_rpm := idle + clampf(p_rpm_norm, 0.0, 1.0) * (red - idle)
	var g_fa := "دنده %s" % UiTheme.fa_int(p_gear_index) if p_gear_index > 0 else "دنده D"
	match p_gear_code:
		"N":
			g_fa = "خلاص"
		"R":
			g_fa = "دنده عقب"
	gear_index = p_gear_index
	set_telemetry(p_speed_kmh, real_rpm, g_fa, p_braking, p_handbrake, p_headlights, p_throttle, p_brake, p_gear_code)


func set_telemetry(
	p_speed_kmh: float,
	p_rpm: float,
	p_gear_text: String,
	p_braking: bool,
	p_handbrake: bool,
	p_headlights: bool,
	p_throttle: float = -1.0,
	p_brake: float = -1.0,
	p_gear_code: String = ""
) -> void:
	var new_speed := maxf(0.0, p_speed_kmh)
	var new_rpm := clampf(p_rpm, 0.0, max_rpm)
	var new_thr := clampf(p_throttle, 0.0, 1.0) if p_throttle >= 0.0 else clampf((new_rpm - 950.0) / 5200.0, 0.0, 1.0)
	var new_brk := clampf(p_brake, 0.0, 1.0) if p_brake >= 0.0 else (1.0 if p_braking else 0.0)
	var new_code := p_gear_code if not p_gear_code.is_empty() else _extract_gear_code(p_gear_text)
	var dirty := absf(new_speed - speed_kmh) > 0.25 \
		or absf(new_rpm - rpm) > 15.0 \
		or p_gear_text != gear_text \
		or new_code != gear_code \
		or p_braking != braking \
		or p_handbrake != handbrake \
		or p_headlights != headlights \
		or absf(new_thr - throttle_ratio) > 0.03 \
		or absf(new_brk - brake_ratio) > 0.03
	if not dirty:
		return
	speed_kmh = new_speed
	rpm = new_rpm
	gear_text = p_gear_text
	gear_code = new_code
	braking = p_braking
	handbrake = p_handbrake
	headlights = p_headlights
	throttle_ratio = new_thr
	brake_ratio = new_brk
	_update_label_texts()
	queue_redraw()


func _update_label_texts() -> void:
	if speed_label != null:
		speed_label.text = str(int(round(speed_kmh)))
	if gear_caption != null:
		gear_caption.text = gear_text


## Dial geometry shared by _draw and the label layout.
func _geom() -> Dictionary:
	var w := size.x
	var h := size.y
	var center_w := clampf(w * 0.16, 54.0, 92.0)
	var dial := minf(h - 6.0, (w - center_w - 12.0) * 0.5)
	var r := dial * 0.5
	var cy := h - r - 3.0
	return {"w": w, "h": h, "center_w": center_w, "r": r, "cy": cy,
		"tach": Vector2(r + 3.0, cy), "speed": Vector2(w - r - 3.0, cy)}


func _layout_labels() -> void:
	if speed_label == null or size.x < 10.0:
		return
	var g := _geom()
	var r: float = g["r"]
	var sc: Vector2 = g["speed"]
	var big := int(maxf(18.0, r * 0.42))
	speed_label.add_theme_font_size_override("font_size", big)
	speed_label.size = Vector2(r * 1.0, big * 1.2)
	speed_label.position = Vector2(sc.x - r * 0.5, sc.y + r * 0.30 - big * 0.6)
	var usz := int(maxf(12.0, r * 0.13))
	unit_label.add_theme_font_size_override("font_size", usz)
	unit_label.size = Vector2(r * 1.4, usz * 1.6)
	unit_label.position = Vector2(sc.x - r * 0.7, sc.y + r * 0.56)
	var badge_h := minf(g["h"] * 0.42, 62.0)
	var badge_bottom: float = g["cy"] - badge_h * 0.75 + badge_h
	gear_caption.size = Vector2(g["center_w"] + 24.0, 22.0)
	gear_caption.position = Vector2(g["w"] * 0.5 - gear_caption.size.x * 0.5, badge_bottom + 2.0)


func _extract_gear_code(txt: String) -> String:
	if txt.contains("R") or txt.contains("عقب"):
		return "R"
	if txt.contains("N") or txt.contains("خلاص"):
		return "N"
	return "D"


## Needle/arc angle (radians, Godot screen space) for a value in [0, vmax].
func _angle(v: float, vmax: float) -> float:
	return deg_to_rad(DIAL_START_DEG + DIAL_SWEEP_DEG * clampf(v / maxf(vmax, 0.001), 0.0, 1.0))


func _draw_dial(c: Vector2, r: float, value: float, vmax: float, major_step: float, minor_step: float,
		label_div: float, red_from: float, caption: String, digital: bool) -> void:
	# Face: dark translucent disc for contrast over the track (round, so no
	# boxed plate — B9.1), with a hairline rim.
	draw_circle(c, r, Color(UiTheme.COLOR_SURFACE, 0.78))
	draw_arc(c, r - 1.0, 0.0, TAU, 72, Color(1, 1, 1, 0.14), 1.5, true)
	var arc_r := r * 0.86
	var a0 := deg_to_rad(DIAL_START_DEG)
	var a1 := deg_to_rad(DIAL_START_DEG + DIAL_SWEEP_DEG)
	var track_w := maxf(3.0, r * 0.07)
	draw_arc(c, arc_r, a0, a1, 64, Color(1, 1, 1, 0.10), track_w, true)
	if red_from > 0.0 and red_from < vmax:
		draw_arc(c, arc_r, _angle(red_from, vmax), a1, 24, Color(UiTheme.COLOR_ERROR, 0.85), track_w, true)
	# Live value arc (the "fill" reads faster than the needle alone).
	var va := _angle(value, vmax)
	var live_col := UiTheme.COLOR_ERROR if (red_from > 0.0 and value >= red_from) else UiTheme.COLOR_ON_SURFACE
	if value > vmax * 0.004:
		draw_arc(c, arc_r, a0, va, 48, Color(live_col, 0.92), track_w, true)
	# Ticks + numerals (Latin instrument numerals).
	var steps := int(round(vmax / minor_step))
	var fsz := int(maxf(10.0, r * 0.15))
	for i in range(steps + 1):
		var v := float(i) * minor_step
		var a := _angle(v, vmax)
		var dir := Vector2(cos(a), sin(a))
		var is_major := absf(fmod(v, major_step)) < 0.001 or absf(fmod(v, major_step) - major_step) < 0.001
		var t_in := arc_r - track_w * 0.5 - (r * 0.12 if is_major else r * 0.06)
		var t_out := arc_r - track_w * 0.5 - 2.0
		var tick_col := Color(UiTheme.COLOR_ERROR, 0.95) if (red_from > 0.0 and v >= red_from) else Color(1, 1, 1, 0.75 if is_major else 0.35)
		draw_line(c + dir * t_in, c + dir * t_out, tick_col, 2.0 if is_major else 1.2, true)
		if is_major and _font_num != null:
			var txt := str(int(round(v / label_div)))
			var ts := _font_num.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz)
			var p := c + dir * (t_in - r * 0.13) - Vector2(ts.x * 0.5, -ts.y * 0.32)
			draw_string(_font_num, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(1, 1, 1, 0.85))
	# Digital readout / caption inside the dial.
	if digital and _font_num != null:
		var spd := str(int(round(value)))
		var big := int(maxf(18.0, r * 0.46))
		var ss := _font_num.get_string_size(spd, HORIZONTAL_ALIGNMENT_LEFT, -1, big)
		draw_string(_font_num, Vector2(c.x - ss.x * 0.5, c.y + r * 0.40), spd, HORIZONTAL_ALIGNMENT_LEFT, -1, big, UiTheme.COLOR_ON_SURFACE)
	if _font_med != null and not caption.is_empty():
		var csz := int(maxf(10.0, r * 0.13))
		var cs := _font_med.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, csz)
		draw_string(_font_med, Vector2(c.x - cs.x * 0.5, c.y + r * (0.62 if digital else 0.50)), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, csz, UiTheme.COLOR_ON_SURFACE_VARIANT)
	# Needle: tapered vermilion blade + hub.
	var nd := Vector2(cos(va), sin(va))
	var nn := Vector2(-nd.y, nd.x)
	var tip := c + nd * (arc_r - track_w)
	var base := c - nd * r * 0.14
	var w := maxf(2.5, r * 0.045)
	draw_colored_polygon(PackedVector2Array([base + nn * w, tip + nn * 0.8, tip - nn * 0.8, base - nn * w]), UiTheme.COLOR_PRIMARY)
	draw_circle(c, maxf(5.0, r * 0.09), UiTheme.COLOR_SURFACE_BRIGHT)
	draw_circle(c, maxf(2.5, r * 0.045), UiTheme.COLOR_PRIMARY)


func _draw_lamp(center: Vector2, rad: float, icon: String, on: bool, col: Color) -> void:
	if on:
		draw_circle(center, rad, Color(col, 0.95))
	else:
		# Dark base so an inactive lamp still reads over a bright car body.
		draw_circle(center, rad, Color(UiTheme.COLOR_SURFACE, 0.78))
		draw_arc(center, rad - 1.0, 0.0, TAU, 28, Color(1, 1, 1, 0.30), 1.5, true)
	var tex := UiIcon.texture(icon, 48)
	if tex != null:
		var s := rad * 1.3
		draw_texture_rect(tex, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false,
			Color(0.05, 0.06, 0.08, 1.0) if on else Color(1, 1, 1, 0.38))


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 200.0 or h < 84.0:
		return
	var center_w := clampf(w * 0.16, 54.0, 92.0)
	var dial := minf(h - 6.0, (w - center_w - 12.0) * 0.5)
	var r := dial * 0.5
	var cy := h - r - 3.0
	var tach_c := Vector2(r + 3.0, cy)
	var speed_c := Vector2(w - r - 3.0, cy)

	_draw_dial(tach_c, r, rpm, max_rpm, 1000.0, 500.0, 1000.0, redline_rpm, "دور ×۱۰۰۰", false)
	_draw_dial(speed_c, r, minf(speed_kmh, SPEED_SCALE_MAX), SPEED_SCALE_MAX, 40.0, 20.0, 1.0, -1.0, "", false)

	# --- Gear column -------------------------------------------------------
	var gx := w * 0.5
	var gear_col := UiTheme.COLOR_SUCCESS
	if gear_code == "R":
		gear_col = UiTheme.COLOR_ERROR
	elif gear_code == "N":
		gear_col = UiTheme.COLOR_WARNING
	var badge := Vector2(minf(center_w - 6.0, 64.0), minf(h * 0.42, 62.0))
	var badge_rect := Rect2(Vector2(gx - badge.x * 0.5, cy - badge.y * 0.75), badge)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.COLOR_SURFACE, 0.86)
	sb.border_color = gear_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.anti_aliasing = true
	draw_style_box(sb, badge_rect)
	var gsz := int(badge.y * 0.62)
	var letter := gear_code
	var ls := _font_num.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz)
	var sub := ""
	if gear_code == "D" and gear_index > 0:
		sub = str(gear_index)
	var sub_sz := int(gsz * 0.45)
	var subs := _font_num.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_sz) if not sub.is_empty() else Vector2.ZERO
	var lx := gx - (ls.x + subs.x) * 0.5
	var ly := badge_rect.position.y + badge.y * 0.5 + ls.y * 0.30
	draw_string(_font_num, Vector2(lx, ly), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz, gear_col)
	if not sub.is_empty():
		draw_string(_font_num, Vector2(lx + ls.x + 1.0, ly), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_sz, Color(gear_col, 0.85))

	# Backplate under the gear caption: it sits over the car/track, so it
	# gets its own dark pill (XAG 102: text on non-solid backgrounds).
	if gear_caption != null and _font_bold != null and not gear_caption.text.is_empty():
		var cap_w := _font_bold.get_string_size(gear_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TYPE_LABEL).x + 18.0
		var cap_r := Rect2(Vector2(gx - cap_w * 0.5, gear_caption.position.y + 1.0), Vector2(cap_w, gear_caption.size.y))
		var cap_sb := StyleBoxFlat.new()
		cap_sb.bg_color = Color(UiTheme.COLOR_SURFACE, 0.86)
		cap_sb.set_corner_radius_all(int(cap_r.size.y * 0.5))
		cap_sb.anti_aliasing = true
		draw_style_box(cap_sb, cap_r)

	# --- Lamps: headlights / brake / handbrake --------------------------------
	var lamp_r := clampf(center_w * 0.17, 8.0, 12.0)
	var ly2 := badge_rect.position.y - lamp_r - 8.0
	var gap := lamp_r * 2.4
	_draw_lamp(Vector2(gx + gap, ly2), lamp_r, "headlight", headlights, UiTheme.COLOR_INFO)
	_draw_lamp(Vector2(gx, ly2), lamp_r, "brake", braking, UiTheme.COLOR_BRAKE)
	_draw_lamp(Vector2(gx - gap, ly2), lamp_r, "handbrake", handbrake, UiTheme.COLOR_HANDBRAKE)

	# --- Pedal input bars (telemetry convention) ---------------------------
	var bar_w := badge.x * 0.42
	var bar_h := 4.0
	var by := badge_rect.end.y + 26.0
	if by + bar_h < h:
		var thr_rect := Rect2(Vector2(gx + 2.0, by), Vector2(bar_w, bar_h))
		var brk_rect := Rect2(Vector2(gx - 2.0 - bar_w, by), Vector2(bar_w, bar_h))
		draw_rect(thr_rect, Color(1, 1, 1, 0.12))
		draw_rect(brk_rect, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(thr_rect.position, Vector2(bar_w * throttle_ratio, bar_h)), UiTheme.COLOR_THROTTLE)
		draw_rect(Rect2(Vector2(brk_rect.end.x - bar_w * brake_ratio, by), Vector2(bar_w * brake_ratio, bar_h)), UiTheme.COLOR_BRAKE)
