class_name UiTheme
extends RefCounted

## Kilometer 2 — "Proving Ground" design system (v0.1-b3).
##
## Single source of truth for colour roles, type scale, spacing, shape,
## elevation, motion and component styles. The structure follows Material
## Design 3 (semantic colour roles with on-colours, a named type scale,
## state layers, a shape scale and motion tokens) but the look is the game's
## own: a night-time motorsport proving ground — graphite surfaces, ice-white
## type, one vermilion signal colour, and the telemetry convention
## throttle = green / brake = red / caution = amber.
## Full specification: documentation/DESIGN_SYSTEM.md.
##
## Usage rule: screens style nodes through `theme_type_variation` names
## defined here (PrimaryButton, TitleLabel, GlassPanel, ...). Per-node
## overrides are reserved for genuinely dynamic values (live colours).

# --- Fonts (OFL 1.1, see THIRD_PARTY_ASSETS.md) ------------------------
const FONT_REGULAR_PATH := "res://assets/fonts/Estedad-Regular.ttf"
const FONT_MEDIUM_PATH := "res://assets/fonts/Estedad-Medium.ttf"
const FONT_BOLD_PATH := "res://assets/fonts/Estedad-Bold.ttf"
const FONT_BLACK_PATH := "res://assets/fonts/Estedad-Black.ttf"
## Latin instrument numerals only (speed, rpm, timer). Never Persian text.
const FONT_CHANGA_XB_PATH := "res://assets/fonts/Changa-ExtraBold.ttf"

# --- Colour roles (dark scheme). Contrast pairs are verified by
# tests/test_ui_v3_design_system.gd and documented in DESIGN_SYSTEM.md. ---
const COLOR_BG := Color("#07090D")
const COLOR_SURFACE := Color("#0E131A")
const COLOR_SURFACE_LOW := Color("#121822")
const COLOR_SURFACE_CONTAINER := Color("#171E29")
const COLOR_SURFACE_HIGH := Color("#1E2633")
const COLOR_SURFACE_HIGHEST := Color("#273141")
const COLOR_SURFACE_BRIGHT := Color("#313D50")
const COLOR_GLASS := Color(0.090, 0.118, 0.161, 0.88)
const COLOR_SCRIM := Color(0.012, 0.020, 0.030, 0.72)
const COLOR_ON_SURFACE := Color("#F1F4F8")
const COLOR_ON_SURFACE_VARIANT := Color("#AAB5C5")
const COLOR_ON_SURFACE_DISABLED := Color("#7F8A9B")
const COLOR_OUTLINE := Color("#5E6B7F")
const COLOR_OUTLINE_VARIANT := Color(1.0, 1.0, 1.0, 0.10)
const COLOR_INVERSE_SURFACE := Color("#EEF2F7")
const COLOR_ON_INVERSE_SURFACE := Color("#10151C")

## Vermilion signal: icons/strokes/selection on dark surfaces.
const COLOR_PRIMARY := Color("#FF5A3C")
## Filled call-to-action; white label measures 5.2:1.
const COLOR_PRIMARY_CONTAINER := Color("#D2291A")
const COLOR_PRIMARY_HOVER := Color("#DB2E1C")
const COLOR_PRIMARY_PRESSED := Color("#AE1F12")
const COLOR_ON_PRIMARY := Color.WHITE
const COLOR_PRIMARY_TINT := Color(1.0, 0.353, 0.235, 0.16)

const COLOR_INFO := Color("#56D8F0")
const COLOR_SUCCESS := Color("#2EDB91")
const COLOR_WARNING := Color("#FFB627")
const COLOR_ERROR := Color("#FF5B6E")
const COLOR_ON_SUCCESS := Color("#062615")
const COLOR_ON_WARNING := Color("#2A1A00")
const COLOR_FOCUS := Color.WHITE

## Driving semantics (motorsport telemetry convention). Never colour-only:
## every use also carries an icon, a label or a position.
const COLOR_THROTTLE := COLOR_SUCCESS
const COLOR_BRAKE := COLOR_ERROR
const COLOR_HANDBRAKE := COLOR_WARNING

# Legacy aliases — older call sites and external scripts keep compiling.
const COLOR_SURFACE_ELEVATED := COLOR_SURFACE_HIGH
const COLOR_SURFACE_GLASS := COLOR_GLASS
const COLOR_ACCENT_PRIMARY := COLOR_PRIMARY
const COLOR_ACCENT_HOVER := COLOR_PRIMARY_HOVER
const COLOR_ACCENT_PRESSED := COLOR_PRIMARY_PRESSED
const COLOR_ACCENT_SECONDARY := COLOR_INFO
const COLOR_ACCENT_GOLD := COLOR_WARNING
const COLOR_TEXT_PRIMARY := COLOR_ON_SURFACE
const COLOR_TEXT_SECONDARY := COLOR_ON_SURFACE_VARIANT
const COLOR_LINE := COLOR_OUTLINE_VARIANT
const COLOR_LINE_BRIGHT := Color(1.0, 1.0, 1.0, 0.22)
const COLOR_OK := COLOR_SUCCESS
const COLOR_WARN := COLOR_WARNING
const COLOR_BAD := COLOR_ERROR
const COLOR_ACCENT_ORANGE := COLOR_PRIMARY
const COLOR_ACCENT_ORANGE_HI := COLOR_PRIMARY_HOVER
const COLOR_ACCENT_CYAN := COLOR_INFO
const COLOR_INK := COLOR_ON_SURFACE
const COLOR_TEXT := COLOR_ON_SURFACE
const COLOR_MUTED := COLOR_ON_SURFACE_VARIANT
const COLOR_BORDER := COLOR_OUTLINE_VARIANT
const COLOR_SURFACE_ALT := COLOR_SURFACE_HIGH
const COLOR_SURFACE_HI := COLOR_SURFACE_HIGH
const COLOR_WARNING_LEGACY := COLOR_WARNING
const COLOR_DANGER := COLOR_ERROR

# --- Type scale (canvas px at 100 % UI scale; base canvas 1280x720) ----
# Sized for a landscape phone first (1 canvas px ~ 0.55 pt): with the
# handheld default UI scale (120 %) body text is ~11 pt.
const TYPE_DISPLAY := 44
const TYPE_HEADLINE := 30
const TYPE_TITLE := 22
const TYPE_BODY_LG := 19
const TYPE_BODY := 17
const TYPE_LABEL := 16
const TYPE_CAPTION := 15
const TYPE_NUMERIC_XL := 60
const TYPE_NUMERIC_LG := 34
const TYPE_NUMERIC_MD := 22
const LINE_SPACING_BODY := 6
# Legacy names.
const TYPE_H1 := TYPE_HEADLINE
const TYPE_H2 := TYPE_TITLE
const TYPE_MICRO := TYPE_CAPTION

# --- Spacing (4/8 grid), shape, sizes -----------------------------------
const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32
const SPACE_7 := 48
const SAFE_INSET := 16.0

const RADIUS_XS := 6
const RADIUS_SM := 10
const RADIUS_MD := 14
const RADIUS_LG := 20
const RADIUS_XL := 28
const RADIUS_FULL := 999
const RADIUS_CARD := RADIUS_MD
const RADIUS_BTN := RADIUS_SM
const RADIUS_PILL := RADIUS_FULL

## Minimum interactive height (~37 pt on a phone at the handheld default).
const TOUCH_MIN := 56.0
const CONTROL_HEIGHT := 56.0
const CONTROL_HEIGHT_LG := 64.0
const ICON_SIZE := 22
const FOCUS_RING_WIDTH := 3

# --- Motion (durations in ms; see motion_sec) --------------------------
const MOTION_FAST_MS := 120.0
const MOTION_MEDIUM_MS := 220.0
const MOTION_SLOW_MS := 320.0
const MOTION_FEEDBACK_MS := MOTION_FAST_MS
const MOTION_PANEL_MS := MOTION_MEDIUM_MS
const MOTION_SCENE_MS := MOTION_SLOW_MS

static var _font_regular: Font = null
static var _font_medium: Font = null
static var _font_bold: Font = null
static var _font_black: Font = null
static var _font_changa_xb: Font = null
static var _theme: Theme = null
static var _switch_on_tex: Texture2D = null
static var _switch_off_tex: Texture2D = null
static var _switch_disabled_tex: Texture2D = null
static var _knob_tex: Texture2D = null
static var _knob_hi_tex: Texture2D = null


static func font_regular() -> Font:
	if _font_regular == null and ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH) as Font
	return _font_regular


static func font_medium() -> Font:
	if _font_medium == null and ResourceLoader.exists(FONT_MEDIUM_PATH):
		_font_medium = load(FONT_MEDIUM_PATH) as Font
	return _font_medium


static func font_bold() -> Font:
	if _font_bold == null and ResourceLoader.exists(FONT_BOLD_PATH):
		_font_bold = load(FONT_BOLD_PATH) as Font
	return _font_bold


static func font_black() -> Font:
	if _font_black == null and ResourceLoader.exists(FONT_BLACK_PATH):
		_font_black = load(FONT_BLACK_PATH) as Font
	return _font_black


## Changa ExtraBold — Latin display numerals only.
static func font_changa_xbold() -> Font:
	if _font_changa_xb == null and ResourceLoader.exists(FONT_CHANGA_XB_PATH):
		_font_changa_xb = load(FONT_CHANGA_XB_PATH) as Font
	return _font_changa_xb


# =====================================================================
# Motion helpers
# =====================================================================
static func reduce_motion() -> bool:
	return SettingsManager.reduce_motion


## Duration in seconds for a motion token; 0 when reduced motion is on, so
## tweens jump straight to their (always exact) final values.
static func motion_sec(ms: float) -> float:
	return 0.0 if SettingsManager.reduce_motion else ms / 1000.0


## Opacity-only fades stay (short) under reduced motion: they carry state
## without movement.
static func fade_sec(ms: float) -> float:
	return minf(ms, 90.0) / 1000.0 if SettingsManager.reduce_motion else ms / 1000.0


## Enter = emphasized-decelerate approximation, exit = accelerate.
static func ease_enter(t: Tweener) -> Tweener:
	if t is PropertyTweener:
		(t as PropertyTweener).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return t


static func ease_exit(t: Tweener) -> Tweener:
	if t is PropertyTweener:
		(t as PropertyTweener).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	return t


# =====================================================================
# Safe area (cutouts, rounded corners, system bars)
# =====================================================================
## Extra margins (left, top, right, bottom) in canvas units that keep UI out
## of display cutouts and system insets. Only handheld builds report a real
## safe area; everywhere else (desktop, headless tests) this is zero, so
## desktop layouts are unaffected.
static func safe_insets(vp: Viewport) -> Vector4:
	if vp == null or not OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Rect2(Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size()))
	if safe.size.x <= 0.0 or safe.size.y <= 0.0 or win.size.x <= 0.0 or win.size.y <= 0.0:
		return Vector4.ZERO
	var inner := safe.intersection(win)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return Vector4.ZERO
	var to_ui := vp.get_visible_rect().size / win.size
	return Vector4(
		maxf(0.0, (inner.position.x - win.position.x) * to_ui.x),
		maxf(0.0, (inner.position.y - win.position.y) * to_ui.y),
		maxf(0.0, (win.end.x - inner.end.x) * to_ui.x),
		maxf(0.0, (win.end.y - inner.end.y) * to_ui.y))


# =====================================================================
# Text helpers (Persian / RTL)
# =====================================================================
const _FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]


## Converts ASCII digits to Persian digits; "." becomes the Persian decimal
## separator «٫» and "%" the Persian percent sign «٪». Used for every number
## inside Persian prose; instruments (speed, rpm, timer) stay Latin.
static func fa_digits(s: String) -> String:
	var out := ""
	for ch in s:
		var code := ch.unicode_at(0)
		if code >= 48 and code <= 57:
			out += _FA_DIGITS[code - 48]
		elif ch == ".":
			out += "٫"
		elif ch == "%":
			out += "٪"
		else:
			out += ch
	return out


static func fa_int(n: int) -> String:
	return fa_digits(str(n))


## Integer with Persian thousands separator «٬».
static func fa_int_grouped(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "٬" + out
	return fa_digits(("-" if n < 0 else "") + out)


static func fa_float(x: float, decimals: int = 1) -> String:
	return fa_digits(String.num(x, decimals))


static func fa_percent(x01: float) -> String:
	return fa_digits("%d" % int(round(clampf(x01, 0.0, 1.0) * 100.0))) + "٪"


## Forces an RTL paragraph. Godot's default `auto` direction picks the
## direction of the first strong character, so a Persian sentence that
## starts with a Latin token ("IP …", "Wi-Fi …") was laid out LTR and its
## words/punctuation reordered (audit A-04).
static func rtl(lbl: Control) -> void:
	lbl.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if lbl is Label:
		(lbl as Label).text_direction = Control.TEXT_DIRECTION_RTL
	elif lbl is Button:
		(lbl as Button).text_direction = Control.TEXT_DIRECTION_RTL
	elif lbl is LineEdit:
		(lbl as LineEdit).text_direction = Control.TEXT_DIRECTION_RTL
	elif lbl is RichTextLabel:
		(lbl as RichTextLabel).text_direction = Control.TEXT_DIRECTION_RTL


## Label factory: theme variation + explicit RTL paragraph direction.
static func label(text: String, variation: String = "BodyLabel", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	# Own RTL layout: in Godot, alignment is logical under an RTL layout
	# (LEFT = start = visual right), so the label reads right-aligned no
	# matter which container it ends up in.
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Latin-only runs (IP addresses, version strings, key names) get their own
## LTR label so they never reorder the surrounding Persian.
static func ltr_label(text: String, variation: String = "BodyLabel") -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.layout_direction = Control.LAYOUT_DIRECTION_LTR
	l.text_direction = Control.TEXT_DIRECTION_LTR
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


# =====================================================================
# StyleBox builders (tokens → styles)
# =====================================================================
static func box(bg: Color, radius: int = RADIUS_SM, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad: Vector4 = Vector4(16, 10, 16, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	return sb


static func with_shadow(sb: StyleBoxFlat, size: int, alpha: float, offset_y: float = 6.0) -> StyleBoxFlat:
	sb.shadow_color = Color(0.0, 0.0, 0.0, alpha)
	sb.shadow_size = size
	sb.shadow_offset = Vector2(0.0, offset_y)
	return sb


## Focus indicator: a 3 px ice-white ring drawn outside the control (XAG 113).
## It is distinct from hover (lighter surface) and selection (vermilion).
static func focus_ring(radius: int = RADIUS_SM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = COLOR_FOCUS
	sb.set_border_width_all(FOCUS_RING_WIDTH)
	sb.set_corner_radius_all(radius + FOCUS_RING_WIDTH)
	sb.set_expand_margin_all(FOCUS_RING_WIDTH + 1)
	sb.anti_aliasing = true
	return sb


static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


static func glass_style(radius: int = RADIUS_LG, pad: Vector4 = Vector4(24, 20, 24, 20)) -> StyleBoxFlat:
	return with_shadow(box(COLOR_GLASS, radius, COLOR_OUTLINE_VARIANT, 1, pad), 24, 0.45, 10.0)


static func card_style(alpha: float = 1.0) -> StyleBoxFlat:
	return box(Color(COLOR_SURFACE_CONTAINER, alpha), RADIUS_MD, COLOR_OUTLINE_VARIANT, 1, Vector4(16, 14, 16, 14))


static func sheet_style() -> StyleBoxFlat:
	return with_shadow(box(Color(COLOR_SURFACE, 0.97), RADIUS_LG, COLOR_OUTLINE_VARIANT, 1, Vector4(24, 20, 24, 20)), 32, 0.55, 12.0)


static func dialog_style() -> StyleBoxFlat:
	return with_shadow(box(COLOR_SURFACE_CONTAINER, RADIUS_XL, Color(1, 1, 1, 0.14), 1, Vector4(28, 24, 28, 24)), 40, 0.6, 16.0)


static func chip_style_for(tone: Color, filled: bool = false) -> StyleBoxFlat:
	if filled:
		return box(tone, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(14, 6, 14, 6))
	return box(Color(tone.r, tone.g, tone.b, 0.14), RADIUS_FULL, Color(tone.r, tone.g, tone.b, 0.55), 1, Vector4(14, 6, 14, 6))


## Legacy builders (kept for compatibility; mapped onto the new tokens).
static func panel_style(alpha: float = 0.92) -> StyleBoxFlat:
	return with_shadow(box(Color(COLOR_SURFACE_CONTAINER, alpha), RADIUS_MD, COLOR_OUTLINE_VARIANT, 1, Vector4(16, 14, 16, 14)), 18, 0.42, 8.0)


static func modal_style(_alpha: float = 0.96) -> StyleBoxFlat:
	return dialog_style()


static func drawer_style() -> StyleBoxFlat:
	return sheet_style()


static func hud_island_style(accent: Color = Color(0, 0, 0, 0), alpha: float = 0.86) -> StyleBoxFlat:
	var sb := box(Color(COLOR_SURFACE, alpha), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, Vector4(14, 6, 14, 6))
	if accent.a > 0.05:
		sb.border_width_right = 3
		sb.border_color = accent
	return sb


static func pill_style(bg: Color = Color(COLOR_SURFACE, 0.88), border: Color = COLOR_OUTLINE_VARIANT) -> StyleBoxFlat:
	return box(bg, RADIUS_FULL, border, 1, Vector4(14, 6, 14, 6))


static func chip_style(selected: bool = false) -> StyleBoxFlat:
	if selected:
		return box(COLOR_PRIMARY_TINT, RADIUS_FULL, COLOR_PRIMARY, 2, Vector4(14, 6, 14, 6))
	return pill_style()


static func glass_bar_style() -> StyleBoxFlat:
	return hud_island_style()


static func soft_style() -> StyleBoxFlat:
	return card_style(0.86)


static func button_style(bg: Color, border: Color, border_w: int = 1, radius: int = RADIUS_BTN) -> StyleBoxFlat:
	return box(bg, radius, border, border_w, Vector4(16, 10, 16, 10))


## Softline kit helpers are retired (the kit no longer skins anything); the
## names stay as thin token-based shims for any external caller.
static func softline_panel_style(content: Vector4 = Vector4(24, 20, 24, 20)) -> StyleBox:
	return glass_style(RADIUS_LG, content)


static func softline_inset_style(content: Vector4 = Vector4(12, 10, 12, 10)) -> StyleBox:
	return box(COLOR_SURFACE_LOW, RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, content)


static func softline_pill_style() -> StyleBox:
	return pill_style()


static func softline_bar_track() -> StyleBox:
	return box(COLOR_SURFACE_BRIGHT, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO)


static func softline_bar_fill(_fill_name: String = "") -> StyleBox:
	return box(COLOR_PRIMARY, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO)


static func apply_softline_button(_btn: Button, _kind: String) -> void:
	pass


# =====================================================================
# Drawn textures (switch track, slider knob) — crisp at 2x, tinted by tokens
# =====================================================================
static func _make_switch(on: bool, disabled: bool) -> Texture2D:
	# 2x supersampled; drawn at 48x28 through the theme's icon scale.
	var w := 96
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := COLOR_PRIMARY_CONTAINER if on else COLOR_SURFACE_BRIGHT
	var knob := Color.WHITE if on else COLOR_ON_SURFACE_VARIANT
	var ring := Color(1, 1, 1, 0.0) if on else COLOR_OUTLINE
	if disabled:
		track = COLOR_SURFACE_HIGH
		knob = COLOR_ON_SURFACE_DISABLED
		ring = Color(0, 0, 0, 0)
	var r := h * 0.5
	var knob_c := Vector2(w - r, r) if on else Vector2(r, r)
	var knob_r := r - 8.0
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			var q := Vector2(absf(p.x - w * 0.5) - (w * 0.5 - r), absf(p.y - r))
			var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
			var col := Color(0, 0, 0, 0)
			if d <= 0.0:
				col = track
				if d > -3.0 and ring.a > 0.0:
					col = track.lerp(ring, clampf((d + 3.0) / 3.0, 0.0, 1.0))
			elif d < 1.5:
				col = Color(track.r, track.g, track.b, clampf(1.0 - d / 1.5, 0.0, 1.0))
			var kd := p.distance_to(knob_c)
			if kd <= knob_r:
				col = knob
			elif kd <= knob_r + 1.5:
				col = col.lerp(knob, clampf(1.0 - (kd - knob_r) / 1.5, 0.0, 1.0))
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(48, 28))
	return tex


static func _make_knob(highlight: bool) -> Texture2D:
	var dim := 56
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	var c := Vector2(dim * 0.5, dim * 0.5)
	var outer := 22.0 if not highlight else 25.0
	var ring_w := 5.0
	for y in range(dim):
		for x in range(dim):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= outer - ring_w:
				col = Color.WHITE
			elif d <= outer:
				col = COLOR_PRIMARY
			elif d <= outer + 1.5:
				col = Color(COLOR_PRIMARY.r, COLOR_PRIMARY.g, COLOR_PRIMARY.b, clampf(1.0 - (d - outer) / 1.5, 0.0, 1.0))
			if highlight and d > outer + 1.5 and d <= outer + 4.5:
				col = Color(1, 1, 1, 0.9)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(28, 28))
	return tex


static func switch_icon(on: bool, disabled: bool = false) -> Texture2D:
	if disabled:
		if _switch_disabled_tex == null:
			_switch_disabled_tex = _make_switch(false, true)
		return _switch_disabled_tex
	if on:
		if _switch_on_tex == null:
			_switch_on_tex = _make_switch(true, false)
		return _switch_on_tex
	if _switch_off_tex == null:
		_switch_off_tex = _make_switch(false, false)
	return _switch_off_tex


static func slider_knob(highlight: bool = false) -> Texture2D:
	if highlight:
		if _knob_hi_tex == null:
			_knob_hi_tex = _make_knob(true)
		return _knob_hi_tex
	if _knob_tex == null:
		_knob_tex = _make_knob(false)
	return _knob_tex


# =====================================================================
# The Theme (built once, shared by every screen)
# =====================================================================
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


## Legacy name — returns the shared theme.
static func make_theme() -> Theme:
	return get_theme()


static func _set_button_family(t: Theme, type: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox,
		disabled: StyleBox, font: Font, size: int, fg: Color, fg_hover: Color, fg_pressed: Color, radius: int) -> void:
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus_ring(radius))
	if font != null:
		t.set_font("font", type, font)
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, fg_hover)
	t.set_color("font_pressed_color", type, fg_pressed)
	t.set_color("font_hover_pressed_color", type, fg_pressed)
	t.set_color("font_focus_color", type, fg_hover)
	t.set_color("font_disabled_color", type, COLOR_ON_SURFACE_DISABLED)
	t.set_color("icon_normal_color", type, fg)
	t.set_color("icon_hover_color", type, fg_hover)
	t.set_color("icon_pressed_color", type, fg_pressed)
	t.set_color("icon_hover_pressed_color", type, fg_pressed)
	t.set_color("icon_focus_color", type, fg_hover)
	t.set_color("icon_disabled_color", type, COLOR_ON_SURFACE_DISABLED)
	t.set_constant("h_separation", type, SPACE_2 + 2)
	t.set_constant("icon_max_width", type, ICON_SIZE)


static func _build_theme() -> Theme:
	var t := Theme.new()
	var reg := font_regular()
	var med := font_medium()
	var bold := font_bold()
	var black := font_black()
	if med != null:
		t.default_font = med
	t.default_font_size = TYPE_BODY

	# ---------------------------------------------------------- labels
	t.set_color("font_color", "Label", COLOR_ON_SURFACE)
	t.set_font_size("font_size", "Label", TYPE_BODY)
	t.set_constant("line_spacing", "Label", 3)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	var label_variants := [
		# name, font, size, colour, line spacing
		["DisplayLabel", black, TYPE_DISPLAY, COLOR_ON_SURFACE, 0],
		["HeadlineLabel", black, TYPE_HEADLINE, COLOR_ON_SURFACE, 0],
		["TitleLabel", bold, TYPE_TITLE, COLOR_ON_SURFACE, 2],
		["SectionLabel", bold, TYPE_BODY_LG, COLOR_ON_SURFACE, 2],
		["BodyLargeLabel", med, TYPE_BODY_LG, COLOR_ON_SURFACE, LINE_SPACING_BODY],
		["BodyLabel", med, TYPE_BODY, COLOR_ON_SURFACE, LINE_SPACING_BODY],
		["BodyMutedLabel", med, TYPE_BODY, COLOR_ON_SURFACE_VARIANT, LINE_SPACING_BODY],
		["LabelStrong", bold, TYPE_LABEL, COLOR_ON_SURFACE, 2],
		["CaptionLabel", med, TYPE_CAPTION, COLOR_ON_SURFACE_VARIANT, 3],
		["OverlineLabel", bold, TYPE_CAPTION, COLOR_PRIMARY, 2],
		["ValueLabel", bold, TYPE_LABEL, COLOR_ON_SURFACE, 0],
	]
	for v in label_variants:
		t.set_type_variation(v[0], "Label")
		if v[1] != null:
			t.set_font("font", v[0], v[1])
		t.set_font_size("font_size", v[0], v[2])
		t.set_color("font_color", v[0], v[3])
		t.set_constant("line_spacing", v[0], v[4])
	t.set_type_variation("NumericLabel", "Label")
	if font_changa_xbold() != null:
		t.set_font("font", "NumericLabel", font_changa_xbold())
	t.set_font_size("font_size", "NumericLabel", TYPE_NUMERIC_MD)
	t.set_color("font_color", "NumericLabel", COLOR_ON_SURFACE)

	# --------------------------------------------------------- buttons
	var pad := Vector4(18, 12, 18, 12)
	var n := box(COLOR_SURFACE_HIGH, RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, pad)
	var h := box(COLOR_SURFACE_HIGHEST, RADIUS_SM, Color(1, 1, 1, 0.18), 1, pad)
	var p := box(COLOR_SURFACE_BRIGHT, RADIUS_SM, Color(1, 1, 1, 0.22), 1, pad)
	var d := box(Color(COLOR_SURFACE_LOW, 0.9), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, pad)
	for cls in ["Button", "MenuButton"]:
		_set_button_family(t, cls, n, h, p, d, bold, TYPE_LABEL, COLOR_ON_SURFACE, Color.WHITE, Color.WHITE, RADIUS_SM)

	# Primary: the single filled vermilion call to action per screen.
	t.set_type_variation("PrimaryButton", "Button")
	_set_button_family(t, "PrimaryButton",
		box(COLOR_PRIMARY_CONTAINER, RADIUS_SM, Color(1, 1, 1, 0.12), 1, Vector4(24, 14, 24, 14)),
		box(COLOR_PRIMARY_HOVER, RADIUS_SM, Color(1, 1, 1, 0.30), 1, Vector4(24, 14, 24, 14)),
		box(COLOR_PRIMARY_PRESSED, RADIUS_SM, Color(1, 1, 1, 0.30), 1, Vector4(24, 14, 24, 14)),
		box(COLOR_SURFACE_HIGH, RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, Vector4(24, 14, 24, 14)),
		black, TYPE_BODY_LG, COLOR_ON_PRIMARY, COLOR_ON_PRIMARY, COLOR_ON_PRIMARY, RADIUS_SM)

	# Secondary: outlined, transparent.
	t.set_type_variation("SecondaryButton", "Button")
	_set_button_family(t, "SecondaryButton",
		box(Color(COLOR_SURFACE, 0.55), RADIUS_SM, COLOR_OUTLINE, 1, pad),
		box(COLOR_SURFACE_HIGHEST, RADIUS_SM, COLOR_ON_SURFACE_VARIANT, 1, pad),
		box(COLOR_SURFACE_BRIGHT, RADIUS_SM, COLOR_ON_SURFACE, 1, pad),
		box(Color(COLOR_SURFACE, 0.4), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, pad),
		bold, TYPE_LABEL, COLOR_ON_SURFACE, Color.WHITE, Color.WHITE, RADIUS_SM)

	# Ghost: text-style action (low emphasis, e.g. «انصراف»).
	t.set_type_variation("GhostButton", "Button")
	_set_button_family(t, "GhostButton",
		box(Color(0, 0, 0, 0), RADIUS_SM, Color(0, 0, 0, 0), 0, pad),
		box(Color(COLOR_SURFACE_HIGHEST, 0.85), RADIUS_SM, Color(0, 0, 0, 0), 0, pad),
		box(COLOR_SURFACE_BRIGHT, RADIUS_SM, Color(0, 0, 0, 0), 0, pad),
		box(Color(0, 0, 0, 0), RADIUS_SM, Color(0, 0, 0, 0), 0, pad),
		bold, TYPE_LABEL, COLOR_ON_SURFACE_VARIANT, COLOR_ON_SURFACE, COLOR_ON_SURFACE, RADIUS_SM)

	# Danger: destructive confirmations (outlined error, never the CTA fill).
	t.set_type_variation("DangerButton", "Button")
	_set_button_family(t, "DangerButton",
		box(Color(COLOR_ERROR.r, COLOR_ERROR.g, COLOR_ERROR.b, 0.10), RADIUS_SM, COLOR_ERROR, 2, pad),
		box(Color(COLOR_ERROR.r, COLOR_ERROR.g, COLOR_ERROR.b, 0.22), RADIUS_SM, COLOR_ERROR, 2, pad),
		box(Color(COLOR_ERROR.r, COLOR_ERROR.g, COLOR_ERROR.b, 0.32), RADIUS_SM, COLOR_ERROR, 2, pad),
		d, bold, TYPE_LABEL, COLOR_ERROR, Color.WHITE, Color.WHITE, RADIUS_SM)

	# Icon button: square, used in app bars and sheets.
	t.set_type_variation("IconButton", "Button")
	var ipad := Vector4(12, 12, 12, 12)
	_set_button_family(t, "IconButton",
		box(Color(COLOR_SURFACE, 0.86), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, ipad),
		box(COLOR_SURFACE_HIGHEST, RADIUS_SM, Color(1, 1, 1, 0.18), 1, ipad),
		box(COLOR_SURFACE_BRIGHT, RADIUS_SM, Color(1, 1, 1, 0.22), 1, ipad),
		box(Color(COLOR_SURFACE_LOW, 0.8), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, ipad),
		bold, TYPE_LABEL, COLOR_ON_SURFACE, Color.WHITE, Color.WHITE, RADIUS_SM)

	# Tab / segment / car chip: toggle buttons; "pressed" = selected.
	for vt in ["TabButton", "ChipButton"]:
		t.set_type_variation(vt, "Button")
		var tpad := Vector4(16, 10, 16, 10)
		var sel := box(COLOR_PRIMARY_TINT, RADIUS_SM, COLOR_PRIMARY, 2, tpad)
		_set_button_family(t, vt,
			box(Color(COLOR_SURFACE_HIGH, 0.92), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, tpad),
			box(COLOR_SURFACE_HIGHEST, RADIUS_SM, Color(1, 1, 1, 0.18), 1, tpad),
			sel, d, bold, TYPE_LABEL, COLOR_ON_SURFACE_VARIANT, COLOR_ON_SURFACE, Color.WHITE, RADIUS_SM)
		t.set_color("font_pressed_color", vt, Color.WHITE)
		t.set_color("font_hover_pressed_color", vt, Color.WHITE)

	# ------------------------------------------------------ option button
	_set_button_family(t, "OptionButton", n, h, p, d, med, TYPE_BODY, COLOR_ON_SURFACE, Color.WHITE, Color.WHITE, RADIUS_SM)
	t.set_constant("arrow_margin", "OptionButton", 14)
	t.set_constant("modulate_arrow", "OptionButton", 1)
	t.set_color("font_color", "PopupMenu", COLOR_ON_SURFACE)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", COLOR_ON_SURFACE_DISABLED)
	t.set_color("font_separator_color", "PopupMenu", COLOR_ON_SURFACE_VARIANT)
	if med != null:
		t.set_font("font", "PopupMenu", med)
	t.set_font_size("font_size", "PopupMenu", TYPE_BODY)
	t.set_stylebox("panel", "PopupMenu", with_shadow(box(COLOR_SURFACE_HIGH, RADIUS_SM, Color(1, 1, 1, 0.14), 1, Vector4(6, 6, 6, 6)), 16, 0.5, 6.0))
	t.set_stylebox("hover", "PopupMenu", box(COLOR_PRIMARY_TINT, RADIUS_XS, COLOR_PRIMARY, 1, Vector4(8, 4, 8, 4)))
	t.set_constant("v_separation", "PopupMenu", 18)
	t.set_constant("h_separation", "PopupMenu", 12)
	t.set_constant("item_start_padding", "PopupMenu", 14)
	t.set_constant("item_end_padding", "PopupMenu", 14)

	# ---------------------------------------------------------- panels
	t.set_stylebox("panel", "PanelContainer", card_style())
	t.set_stylebox("panel", "Panel", card_style())
	var panel_variants := {
		"GlassPanel": glass_style(),
		"CardPanel": card_style(),
		"InsetPanel": box(COLOR_SURFACE_LOW, RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, Vector4(14, 12, 14, 12)),
		"SheetPanel": sheet_style(),
		"DialogPanel": dialog_style(),
		"HudPanel": box(Color(COLOR_SURFACE, 0.84), RADIUS_SM, COLOR_OUTLINE_VARIANT, 1, Vector4(14, 8, 14, 8)),
		"ChipPanel": pill_style(),
		"ToastPanel": with_shadow(box(COLOR_INVERSE_SURFACE, RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(18, 12, 18, 12)), 18, 0.45, 6.0),
		"ClearPanel": box(Color(0, 0, 0, 0), 0, Color(0, 0, 0, 0), 0, Vector4.ZERO),
	}
	for k in panel_variants.keys():
		t.set_type_variation(k, "PanelContainer")
		t.set_stylebox("panel", k, panel_variants[k])

	# ---------------------------------------------------------- slider
	t.set_stylebox("slider", "HSlider", box(COLOR_SURFACE_BRIGHT, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber_area", "HSlider", box(COLOR_PRIMARY, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(COLOR_PRIMARY, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(0, 3, 0, 3)))
	t.set_icon("grabber", "HSlider", slider_knob(false))
	t.set_icon("grabber_highlight", "HSlider", slider_knob(true))
	t.set_icon("grabber_disabled", "HSlider", slider_knob(false))
	t.set_constant("center_grabber", "HSlider", 1)

	# --------------------------------------------------- toggles / checks
	for cls in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", cls, box(Color(0, 0, 0, 0), RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
		t.set_stylebox("hover", cls, box(Color(COLOR_SURFACE_HIGHEST, 0.6), RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
		t.set_stylebox("pressed", cls, box(Color(0, 0, 0, 0), RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
		t.set_stylebox("hover_pressed", cls, box(Color(COLOR_SURFACE_HIGHEST, 0.6), RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
		t.set_stylebox("disabled", cls, box(Color(0, 0, 0, 0), RADIUS_SM, Color(0, 0, 0, 0), 0, Vector4(12, 8, 12, 8)))
		t.set_stylebox("focus", cls, focus_ring(RADIUS_SM))
		if med != null:
			t.set_font("font", cls, med)
		t.set_font_size("font_size", cls, TYPE_BODY)
		t.set_color("font_color", cls, COLOR_ON_SURFACE)
		t.set_color("font_hover_color", cls, Color.WHITE)
		t.set_color("font_pressed_color", cls, COLOR_ON_SURFACE)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
		t.set_color("font_focus_color", cls, Color.WHITE)
		t.set_color("font_disabled_color", cls, COLOR_ON_SURFACE_DISABLED)
		t.set_constant("h_separation", cls, SPACE_3)
	t.set_icon("checked", "CheckButton", switch_icon(true))
	t.set_icon("unchecked", "CheckButton", switch_icon(false))
	t.set_icon("checked_disabled", "CheckButton", switch_icon(false, true))
	t.set_icon("unchecked_disabled", "CheckButton", switch_icon(false, true))
	t.set_icon("checked_mirrored", "CheckButton", switch_icon(true))
	t.set_icon("unchecked_mirrored", "CheckButton", switch_icon(false))

	# --------------------------------------------------------- line edit
	var le := box(COLOR_SURFACE_LOW, RADIUS_SM, COLOR_OUTLINE, 1, Vector4(14, 10, 14, 10))
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", focus_ring(RADIUS_SM))
	if med != null:
		t.set_font("font", "LineEdit", med)
	t.set_font_size("font_size", "LineEdit", TYPE_BODY)
	t.set_color("font_color", "LineEdit", COLOR_ON_SURFACE)
	t.set_color("font_placeholder_color", "LineEdit", COLOR_ON_SURFACE_VARIANT)
	t.set_color("caret_color", "LineEdit", COLOR_PRIMARY)
	t.set_color("selection_color", "LineEdit", Color(COLOR_PRIMARY, 0.35))
	t.set_type_variation("ErrorLineEdit", "LineEdit")
	t.set_stylebox("normal", "ErrorLineEdit", box(COLOR_SURFACE_LOW, RADIUS_SM, COLOR_ERROR, 2, Vector4(14, 10, 14, 10)))

	# ------------------------------------------------------ progress bar
	t.set_stylebox("background", "ProgressBar", box(COLOR_SURFACE_BRIGHT, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", box(COLOR_PRIMARY, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	t.set_type_variation("StatBar", "ProgressBar")
	t.set_stylebox("background", "StatBar", box(Color(1, 1, 1, 0.10), RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO))
	t.set_stylebox("fill", "StatBar", box(COLOR_ON_SURFACE, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4.ZERO))

	# -------------------------------------------------------- scrollbars
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, box(Color(1, 1, 1, 0.05), RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber", cls, box(Color(COLOR_ON_SURFACE_VARIANT, 0.55), RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_highlight", cls, box(Color(COLOR_ON_SURFACE_VARIANT, 0.85), RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(3, 3, 3, 3)))
		t.set_stylebox("grabber_pressed", cls, box(COLOR_ON_SURFACE, RADIUS_FULL, Color(0, 0, 0, 0), 0, Vector4(3, 3, 3, 3)))
	t.set_stylebox("focus", "ScrollContainer", empty_box())
	t.set_stylebox("panel", "ScrollContainer", empty_box())

	# ----------------------------------------------- separators / tooltip
	var sep := StyleBoxLine.new()
	sep.color = COLOR_OUTLINE_VARIANT
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", SPACE_3)
	t.set_stylebox("panel", "TooltipPanel", box(COLOR_INVERSE_SURFACE, RADIUS_XS, Color(0, 0, 0, 0), 0, Vector4(10, 6, 10, 6)))
	t.set_color("font_color", "TooltipLabel", COLOR_ON_INVERSE_SURFACE)
	t.set_font_size("font_size", "TooltipLabel", TYPE_CAPTION)
	if reg != null:
		t.set_font("font", "TooltipLabel", reg)
	return t


# =====================================================================
# Component factories
# =====================================================================
## variant: "default" | "primary" | "secondary" | "ghost" | "danger" | "icon" | "tab" | "chip"
static func make_button(label_text: String, btn_name: String = "", primary: bool = false, min_size: Vector2 = Vector2(0, TOUCH_MIN), variant: String = "", icon_kind: String = "") -> Button:
	var b := Button.new()
	if not btn_name.is_empty():
		b.name = btn_name
	b.text = label_text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.text_direction = Control.TEXT_DIRECTION_RTL
	var v := variant
	if v.is_empty():
		v = "primary" if primary else "default"
	match v:
		"primary":
			b.theme_type_variation = "PrimaryButton"
		"secondary":
			b.theme_type_variation = "SecondaryButton"
		"ghost":
			b.theme_type_variation = "GhostButton"
		"danger":
			b.theme_type_variation = "DangerButton"
		"icon":
			b.theme_type_variation = "IconButton"
		"tab":
			b.theme_type_variation = "TabButton"
			b.toggle_mode = true
		"chip":
			b.theme_type_variation = "ChipButton"
			b.toggle_mode = true
	if not icon_kind.is_empty():
		b.icon = UiIcon.texture(icon_kind)
		b.expand_icon = false
	add_button_motion(b)
	return b


## Press/hover micro-interaction through Control.offset_transform (Godot 4.7):
## containers never overwrite it, layout and hit areas stay untouched, and the
## resting scale is always exactly 1. Disabled under reduced motion.
static func add_button_motion(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("k2_btn_motion"):
		return
	btn.set_meta("k2_btn_motion", true)
	btn.mouse_entered.connect(func() -> void: _tween_button_scale(btn, 1.02))
	btn.mouse_exited.connect(func() -> void: _tween_button_scale(btn, 1.0))
	btn.button_down.connect(func() -> void: _tween_button_scale(btn, 0.97))
	btn.button_up.connect(func() -> void: _tween_button_scale(btn, 1.02 if btn.is_hovered() else 1.0))


static func _tween_button_scale(btn: BaseButton, target: float) -> void:
	if not is_instance_valid(btn) or not btn.is_inside_tree():
		return
	if btn.has_meta("k2_btn_motion_tween"):
		var old: Variant = btn.get_meta("k2_btn_motion_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	btn.offset_transform_enabled = true
	btn.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	if SettingsManager.reduce_motion:
		btn.offset_transform_scale = Vector2.ONE
		return
	var tw := btn.create_tween()
	btn.set_meta("k2_btn_motion_tween", tw)
	tw.tween_property(btn, "offset_transform_scale", Vector2.ONE * target, MOTION_FAST_MS / 1000.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Section heading with the K2 "speed slash" motif (two slanted vermilion
## bars) — the game's own heading mark instead of a generic rail.
static func make_heading(text: String, variation: String = "TitleLabel") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", SPACE_3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := SpeedSlash.new()
	mark.custom_minimum_size = Vector2(18, 18)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var l := label(text, variation)
	l.name = "HeadingText"
	row.add_child(l)
	return row


## Two slanted bars "//" — brand motif from the K2 badge.
class SpeedSlash extends Control:
	var color: Color = UiTheme.COLOR_PRIMARY

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var w := maxf(4.0, h * 0.26)
		for i in range(2):
			var x0 := float(i) * (w + h * 0.16)
			var pts := PackedVector2Array([
				Vector2(x0 + h * 0.34, 0.0), Vector2(x0 + h * 0.34 + w, 0.0),
				Vector2(x0 + w, h), Vector2(x0, h)])
			draw_colored_polygon(pts, Color(color, 1.0 if i == 0 else 0.55))


## Legacy helpers — map old call sites onto variations.
static func style_primary_button(btn: Button, _radius: int = 8) -> void:
	btn.theme_type_variation = "PrimaryButton"
	add_button_motion(btn)


static func style_nav_tab(btn: Button, active: bool = false) -> void:
	btn.theme_type_variation = "TabButton"
	btn.toggle_mode = true
	btn.set_pressed_no_signal(active)
	add_button_motion(btn)


static func style_carousel_card(btn: Button, active: bool = false) -> void:
	btn.theme_type_variation = "ChipButton"
	btn.toggle_mode = true
	btn.set_pressed_no_signal(active)
	add_button_motion(btn)


static func style_selected_chip(btn: Button, selected: bool) -> void:
	style_carousel_card(btn, selected)


static func style_title(lbl: Label, size: int = TYPE_TITLE) -> void:
	lbl.theme_type_variation = "HeadlineLabel" if size >= TYPE_HEADLINE else "TitleLabel"
	lbl.add_theme_font_size_override("font_size", size)
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.layout_direction = Control.LAYOUT_DIRECTION_RTL


static func style_muted(lbl: Label, size: int = TYPE_CAPTION) -> void:
	lbl.theme_type_variation = "CaptionLabel"
	lbl.add_theme_font_size_override("font_size", maxi(size, TYPE_CAPTION))
	lbl.text_direction = Control.TEXT_DIRECTION_RTL
	lbl.layout_direction = Control.LAYOUT_DIRECTION_RTL
