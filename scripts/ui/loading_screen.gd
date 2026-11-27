class_name LoadingScreen
extends CanvasLayer

## Kilometer 2 — loading screen module, identity v2 (v0.1-b6).
##
## Art direction (v0.4): the studio car renders are back — the loading screen shows the
## selected vehicle's plate again, lit on brand black — and the only type on screen is the
## KILOMETER logotype (no K2 monogram here: the monogram belongs to the launcher icon and the
## engine splash, the wordmark carries the loading screen). No Persian titles, no status
## sentences, no version strings. Progress is a single vermilion rule (pure geometry, no
## numerals).
##
## `present(kind, vehicle_id)` picks the plate: `vehicle_id` when the caller knows the car,
## otherwise the map plate for the track load and the intro plate for everything else, with
## the portrait crops on tall viewports.
##
## Public API (unchanged from b5):
##   present(kind: String, vehicle_id: String = "", status: String = "") -> void
##   set_progress(value: float, instant: bool = false) -> void
##   dismiss() -> void
##   signal finished_loading
##
## `kind` is "intro" or "map"; `status` is accepted for source compatibility and ignored.

signal finished_loading

const PLATE_DIR := "res://assets/ui/loading/"
const BRAND_DIR := "res://assets/ui/brand/"
const LOGO_DIR := "res://assets/ui/loading/logo/"
const FADE_IN := 0.28
const FADE_OUT := 0.32
## Dwell the module guarantees on its own, independent of SceneTransition: the brief asks for a
## ~3 s loading screen, and the module is also presented directly by tools and tests.
const MIN_SHOW := 3.0

var _root: Control
var _plate: TextureRect
var _mark: TextureRect          # retired in v0.4; kept so old references do not break
var _logo: TextureRect
var _scrim: TextureRect
var _rule_bg: ColorRect
var _rule: ColorRect
var _shown_at := 0.0
var _target := 0.0
var _value := 0.0
var _dismissing := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	add_child(_root)

	var bg := ColorRect.new()
	bg.name = "Stage"
	bg.color = Color("#050608")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	_plate = TextureRect.new()
	_plate.name = "HeroPlate"
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plate)

	_scrim = TextureRect.new()
	_scrim.name = "BottomScrim"
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scrim)

	_logo = TextureRect.new()
	_logo.name = "Logotype"
	_logo.texture = _load_tex(LOGO_DIR + "kilometer_logotype_white.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_logo)

	_rule_bg = ColorRect.new()
	_rule_bg.name = "ProgressTrack"
	_rule_bg.color = Color(1, 1, 1, 0.12)
	_rule_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_rule_bg)

	_rule = ColorRect.new()
	_rule.name = "ProgressRule"
	_rule.color = Color("#FF4B2E")
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_rule)

	get_viewport().size_changed.connect(_layout)
	_layout()


## Responsive layout: the logotype is sized from the smaller viewport edge and always keeps
## one cap height of clear space; the rule keeps the same optical margin as the logotype.
func _layout() -> void:
	if _root == null:
		return
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 1.0 or vs.y <= 1.0:
		return
	var wide := vs.x >= vs.y
	var logo_h := clampf(minf(vs.x, vs.y) * (0.062 if wide else 0.085), 22.0, 150.0)
	var margin := clampf(vs.x * 0.055, 18.0, 110.0)
	var logo_w := logo_h * 7.4
	var top := clampf(vs.y * 0.075, 24.0, 150.0)

	#  The wordmark is the only type on screen; it is centred horizontally and keeps one cap
	#  height of clear space (brand guide §2). The car plate fills the frame behind it.
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = Vector2((vs.x - logo_w) * 0.5, top)

	var rule_y := vs.y - clampf(vs.y * 0.075, 26.0, 90.0)
	var thick := clampf(vs.y * 0.0035, 2.0, 5.0)
	_rule_bg.position = Vector2(margin, rule_y)
	_rule_bg.size = Vector2(maxf(1.0, vs.x - margin * 2.0), thick)
	_rule.position = Vector2(margin, rule_y)
	_rule.size = Vector2(maxf(0.0, (vs.x - margin * 2.0) * _value), thick)

	# bottom scrim so the progress rule never sits on a bright part of the car
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.024, 0.031, 0.0))
	g.set_color(1, Color(0.02, 0.024, 0.031, 0.92))
	g.add_point(0.62, Color(0.02, 0.024, 0.031, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var sb := StyleBoxTexture.new()
	sb.texture = gt
	_scrim.add_theme_stylebox_override("panel", sb)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _plate_for(kind: String, vehicle_id: String) -> Texture2D:
	# portrait viewports get their own cropped plate so the car is not blown up by a cover fit
	var vs := get_viewport().get_visible_rect().size
	var portrait := vs.y > vs.x
	if portrait and vehicle_id != "":
		var tp := _load_tex(PLATE_DIR + "plate_" + vehicle_id + "_portrait.png")
		if tp != null:
			return tp
	if portrait:
		var ti := _load_tex(PLATE_DIR + "plate_intro_portrait.png")
		if ti != null:
			return ti
	if vehicle_id != "":
		var t := _load_tex(PLATE_DIR + "plate_" + vehicle_id + ".png")
		if t != null:
			return t
	if kind == "map":
		var t2 := _load_tex(PLATE_DIR + "plate_map.png")
		if t2 != null:
			return t2
	return _load_tex(PLATE_DIR + "plate_intro.png")


## Show the loading screen. `status` is kept for API compatibility and ignored.
func present(kind: String, vehicle_id: String = "", _status: String = "") -> void:
	# v0.4: the studio plate is back, chosen by the caller's vehicle (falls back to the map /
	# intro plate), with the portrait crop on tall viewports.
	_plate.texture = _plate_for(kind, vehicle_id)
	_plate.visible = _plate.texture != null
	_value = 0.0
	_target = 0.0
	_dismissing = false
	visible = true
	_shown_at = Time.get_ticks_msec() / 1000.0
	_layout()
	_rule.size.x = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN)


## Progress is geometry only: the rule grows, nothing is written.
func set_progress(value: float, instant: bool = false) -> void:
	_target = clampf(value, 0.0, 1.0)
	if instant:
		_set_value(_target)
	elif not _dismissing:
		var tw := create_tween()
		tw.tween_method(_set_value, _value, _target, 0.22)


func _set_value(v: float) -> void:
	_value = clampf(v, 0.0, 1.0)
	var vs := get_viewport().get_visible_rect().size
	var margin := clampf(vs.x * 0.055, 18.0, 110.0)
	_rule.size.x = maxf(0.0, (vs.x - margin * 2.0) * _value)


func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	var elapsed := Time.get_ticks_msec() / 1000.0 - _shown_at
	var wait := maxf(0.0, MIN_SHOW - elapsed)
	var tw := create_tween()
	if wait > 0.0:
		tw.tween_interval(wait)
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(func() -> void:
		visible = false
		finished_loading.emit())
