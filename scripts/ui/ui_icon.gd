class_name UiIcon
extends Control

## Kilometer 2 icon set — one family: 24 px grid, 2 px round strokes,
## rendered from inline SVG into cached white textures (3x raster with
## mipmaps, so icons stay crisp from 720p phones to 4K). Buttons tint them
## through the theme's icon_*_color items; standalone icons use `color`.
##
## RTL rules (Persian UI): "back" points right and "forward" points left;
## media "play" is never mirrored; chevron_left/right are absolute.

const _STROKE := "fill='none' stroke='#fff' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'"

const SHAPES := {
	"play": "<path d='M8 5.2v13.6l10.6-6.8z' fill='#fff' stroke='#fff' stroke-width='1.6' stroke-linejoin='round'/>",
	"back": "<path d='M5 12h14M13 6l6 6-6 6' %s/>",
	"forward": "<path d='M19 12H5M11 6l-6 6 6 6' %s/>",
	"chevron_left": "<path d='M15 5l-7 7 7 7' %s/>",
	"chevron_right": "<path d='M9 5l7 7-7 7' %s/>",
	"close": "<path d='M6 6l12 12M18 6L6 18' %s/>",
	"check": "<path d='M5 12.5l4.5 4.5L19 7.5' %s/>",
	"settings": "<path d='M12 8.6a3.4 3.4 0 1 0 0 6.8 3.4 3.4 0 0 0 0-6.8z' %s/><path d='M19.4 13.5l1.6 1.2-2 3.4-1.9-.7a7.6 7.6 0 0 1-2.1 1.2l-.3 2h-4l-.3-2a7.6 7.6 0 0 1-2.1-1.2l-1.9.7-2-3.4 1.6-1.2a7.4 7.4 0 0 1 0-3l-1.6-1.2 2-3.4 1.9.7a7.6 7.6 0 0 1 2.1-1.2l.3-2h4l.3 2a7.6 7.6 0 0 1 2.1 1.2l1.9-.7 2 3.4-1.6 1.2a7.4 7.4 0 0 1 0 3z' %s/>",
	"help": "<circle cx='12' cy='12' r='9' %s/><path d='M9.6 9.4a2.5 2.5 0 1 1 3.6 2.3c-.8.4-1.2 1-1.2 1.8v.5' %s/><circle cx='12' cy='17' r='1.1' fill='#fff'/>",
	"info": "<circle cx='12' cy='12' r='9' %s/><path d='M12 11v6' %s/><circle cx='12' cy='7.6' r='1.1' fill='#fff'/>",
	"alert": "<path d='M12 3.8l9.2 16H2.8z' %s/><path d='M12 10v4.6' %s/><circle cx='12' cy='17.4' r='1.1' fill='#fff'/>",
	"power": "<path d='M12 3.5v8' %s/><path d='M7.2 6.6a7.5 7.5 0 1 0 9.6 0' %s/>",
	"search": "<circle cx='11' cy='11' r='6.2' %s/><path d='M15.6 15.6L20.5 20.5' %s/>",
	"lan": "<path d='M2.8 9.2a13 13 0 0 1 18.4 0M5.8 12.4a8.6 8.6 0 0 1 12.4 0M8.8 15.6a4.2 4.2 0 0 1 6.4 0' %s/><circle cx='12' cy='19' r='1.4' fill='#fff'/>",
	"car": "<path d='M4 15.5V12l2-5h12l2 5v3.5' %s/><path d='M3 15.5h18v2.5H3z' %s/><circle cx='7.5' cy='18.5' r='1.6' fill='#fff'/><circle cx='16.5' cy='18.5' r='1.6' fill='#fff'/><path d='M6.5 11.5h11' %s/>",
	"pause": "<path d='M8.5 5v14M15.5 5v14' fill='none' stroke='#fff' stroke-width='3' stroke-linecap='round'/>",
	"tools": "<path d='M14.7 6.3a4 4 0 0 0-5.2 5.2L4 17l3 3 5.5-5.5a4 4 0 0 0 5.2-5.2l-2.5 2.5-2.4-.6-.6-2.4z' %s/>",
	"headlight": "<path d='M10 6.5c-3.3 0-6 2.5-6 5.5s2.7 5.5 6 5.5z' %s/><path d='M13.5 8h6.5M13.5 12h6.5M13.5 16h6.5' %s/>",
	"reset": "<path d='M4.5 12a7.5 7.5 0 1 0 2.2-5.3' %s/><path d='M4 4.5v4h4' %s/>",
	"camera": "<path d='M3.5 8.5h3.2l1.6-2.5h7.4l1.6 2.5h3.2v10h-17z' %s/><circle cx='12' cy='13.2' r='3.3' %s/>",
	"replay": "<path d='M12 4.5a7.5 7.5 0 1 1-7.1 5.1' %s/><path d='M4 5v4.6h4.6' %s/><path d='M10.5 9.5v5l4-2.5z' fill='#fff' stroke='#fff' stroke-width='1.2' stroke-linejoin='round'/>",
	"ghost": "<path d='M6 20V11a6 6 0 0 1 12 0v9l-2-1.5-2 1.5-2-1.5-2 1.5-2-1.5z' %s/><circle cx='10' cy='11' r='1.1' fill='#fff'/><circle cx='14' cy='11' r='1.1' fill='#fff'/>",
	"tune": "<path d='M4 7h9M17 7h3M4 17h3M11 17h9' %s/><circle cx='15' cy='7' r='2' %s/><circle cx='9' cy='17' r='2' %s/>",
	"home": "<path d='M4 11.5L12 5l8 6.5' %s/><path d='M6.5 10v9h11v-9' %s/>",
	"restart": "<path d='M19.5 12a7.5 7.5 0 1 1-2.2-5.3' %s/><path d='M20 4.5v4h-4' %s/>",
	"gamepad": "<path d='M7.5 7.5h9a4.5 4.5 0 0 1 4.4 5.5l-.9 3.9a2.2 2.2 0 0 1-3.9.9L14.5 15h-5l-1.6 2.8a2.2 2.2 0 0 1-3.9-.9L3.1 13a4.5 4.5 0 0 1 4.4-5.5z' %s/><path d='M8 10v3.4M6.3 11.7h3.4' %s/><circle cx='15.8' cy='10.6' r='1' fill='#fff'/><circle cx='17.8' cy='12.6' r='1' fill='#fff'/>",
	"keyboard": "<path d='M3 6.5h18v11H3z' %s/><path d='M6.5 10h1M10 10h1M13.5 10h1M17 10h.5M7.5 14h9' %s/>",
	"touch": "<path d='M9.5 11V5.8a1.6 1.6 0 0 1 3.2 0V10l4.6 1a2 2 0 0 1 1.6 2.3l-.9 5.2a2.4 2.4 0 0 1-2.4 2H11a2.4 2.4 0 0 1-1.9-.9l-3.6-4.5a1.5 1.5 0 0 1 2.2-2z' %s/>",
	"wheel": "<circle cx='12' cy='12' r='8.5' %s/><circle cx='12' cy='12' r='2.4' %s/><path d='M3.8 11.2l5.8.8M20.2 11.2l-5.8.8M12 14.4V20.4' %s/>",
	"speed": "<path d='M4.2 17.5a8.5 8.5 0 1 1 15.6 0' %s/><path d='M12 13.5l4.2-4.2' %s/><circle cx='12' cy='13.6' r='1.4' fill='#fff'/>",
	"weight": "<path d='M8.6 8.2a3.4 3.4 0 1 1 6.8 0' %s/><path d='M6.6 8.2h10.8l2.3 11.3H4.3z' %s/>",
	"engine": "<path d='M13 3.5L6 13.2h5.2L10.4 20.5 18 10.6h-5.4z' %s/>",
	"volume": "<path d='M4 9.5h3.5L12 5.5v13l-4.5-4H4z' %s/><path d='M15.5 9a4.2 4.2 0 0 1 0 6M18 6.5a8 8 0 0 1 0 11' %s/>",
	"display": "<path d='M3.5 5h17v11h-17z' %s/><path d='M9 20h6M12 16v4' %s/>",
	"access": "<circle cx='12' cy='4.8' r='1.8' fill='#fff'/><path d='M4.5 8.5l7.5 1.6 7.5-1.6M12 10.1v4.4M12 14.5l-3 6M12 14.5l3 6' %s/>",
	"cameraview": "<path d='M3.5 7.5h11v9h-11z' %s/><path d='M14.5 10.5l6-3v9l-6-3z' %s/>",
	"lock": "<path d='M6 11h12v9H6z' %s/><path d='M8.5 11V8a3.5 3.5 0 0 1 7 0v3' %s/>",
	"user": "<circle cx='12' cy='8' r='3.6' %s/><path d='M4.8 20a7.2 7.2 0 0 1 14.4 0' %s/>",
	"wifi_off": "<path d='M3 3l18 18' %s/><path d='M5.8 12.4a8.6 8.6 0 0 1 4.3-2.2M2.8 9.2a13 13 0 0 1 4.4-2.8M14.5 10.6a8.6 8.6 0 0 1 3.7 1.8M8.8 15.6a4.2 4.2 0 0 1 6.4 0' %s/><circle cx='12' cy='19' r='1.4' fill='#fff'/>",
	"brake": "<circle cx='12' cy='12' r='6' %s/><circle cx='12' cy='12' r='1.8' fill='#fff'/><path d='M4.3 8.6a8.8 8.8 0 0 0 0 6.8M19.7 8.6a8.8 8.8 0 0 1 0 6.8' %s/>",
	"throttle": "<path d='M6 14.5l6-6 6 6M7.5 19l4.5-4.5 4.5 4.5' %s/>",
	"handbrake": "<circle cx='12' cy='12' r='8.5' %s/><path d='M10 16.5v-9h3a2.6 2.6 0 0 1 0 5.2h-3' %s/>",
	"steer_left": "<path d='M14.5 5.5L8 12l6.5 6.5M19 8l-4 4 4 4' %s/>",
	"steer_right": "<path d='M9.5 5.5L16 12l-6.5 6.5M5 8l4 4-4 4' %s/>",
}

static var _cache: Dictionary = {}

@export var kind: String = "info":
	set(v):
		kind = v
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()


static func has_icon(k: String) -> bool:
	return SHAPES.has(k)


static func svg_for(k: String) -> String:
	var body: String = SHAPES.get(k, SHAPES["info"])
	var n := body.count("%s")
	var args := []
	for _i in range(n):
		args.append(_STROKE)
	if n > 0:
		body = body % args
	return "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='24' height='24'>%s</svg>" % body


## Cached white icon texture, logical size `px` (rasterized at 3x).
static func texture(k: String, px: int = 24) -> Texture2D:
	var key := "%s@%d" % [k, px]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var err := img.load_svg_from_string(svg_for(k), 3.0 * float(px) / 24.0)
	var tex: ImageTexture = null
	if err == OK:
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
		tex.set_size_override(Vector2i(px, px))
	_cache[key] = tex
	return tex


static func make(k: String, px: int = 24, c: Color = Color.WHITE) -> UiIcon:
	var ic := UiIcon.new()
	ic.kind = k
	ic.color = c
	ic.custom_minimum_size = Vector2(px, px)
	return ic


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(24, 24)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var tex := texture(kind, 48)
	if tex == null:
		return
	var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	draw_texture_rect(tex, r, false, color)
