class_name MainMenu
extends Node3D

## Kilometer 2 — main menu / 3D showroom (v0.1-b3, "Proving Ground" UI).
## The player chooses one of six cars on a lit turntable, then drives it.
## RTL layout (reading starts at the right):
##   - app bar: brand (start) · version · settings · help · quit (end)
##   - hero card (start side): counter, name, model, honest spec bars
##   - bottom dock: «شروع رانندگی» CTA + LAN, car selector, device hints
## Settings, help and the quit confirmation run on a UiModalStack: focus is
## trapped in the top overlay and returns to where it was when it closes
## (audit A-01). Anchored containers stay LTR so their anchors are literal;
## only text containers are RTL (audit A-10).
## The 3D stage builder (_build_showroom_stage) is unchanged from v0.1-b1.

const DRIVING_SCENE_PATH := "res://scenes/main/main_driving_template.tscn"
const LAN_LOBBY_SCENE_PATH := "res://scenes/multiplayer/lan_lobby.tscn"
## v0.1-b4: desert garage diorama used as the showroom stage. The glTF is
## authored 16 x 16 m (interior) with the turntable circle centred at the
## origin and the entrance canopy toward +Z, so it needs no rescaling.
## v0.1-b5: the diorama ships optimised (one merged mesh, 4 892 tris, textures
## capped at 384 px, roof/canopy culled offline): 744 KB instead of 6.0 MB.
## The full-resolution conversion stays next to it as a fallback for captures.
const GARAGE_SCENE_PATH := "res://assets/environment/garage/garage_desert_lite.glb"
const GARAGE_SCENE_FALLBACK := "res://assets/environment/garage/garage_desert.glb"
const GARAGE_ROOT_NAME := "ShowroomGarage"
## Vertical offset of the car above the diorama floor: the model's turntable
## is a raised wooden platform whose top face sits at ~0.16 m.
## Wheels rest on the turntable disc surface; this is only the anti-z-fighting
## epsilon (a few millimetres), never a "hover" gap.
const GARAGE_COMFORT_M := 0.004
## Tuning for the diorama stage. The camera stays exactly like v0.1-b3
## (orbit around the origin at car height) so the layout/framing math and
## every existing UI check keep their meaning.
const GARAGE_CAM_MARGIN_M := 1.45
const GARAGE_LOOK_Y := 0.95

## Showroom specs: honest fractions of the fleet maximum (B8 rule), using the
## physics values the cars actually drive with.
const SPEC_DEFS := [
	["top_speed_kmh", "حداکثر سرعت", "speed"],
	["engine_force_n", "نیروی موتور", "engine"],
	["mass_kg", "وزن", "weight"],
]

var _car_holder: Node3D = null
var _car_instance: Node3D = null
var _camera: Camera3D = null
var _sweep_light: SpotLight3D = null
## v0.1-b4 garage stage
var _garage_root: Node3D = null
var _garage_loaded: bool = false
## Height of the diorama's turntable top face (measured at stage build).
var _turntable_offset: float = 0.035
var _hangar_nodes: Array[Node] = []
var _selected_index: int = 0
var _idle_time: float = 0.0
var _orbit_phase: float = 0.0
var _dragging_car: bool = false
var _leaving: bool = false

# UI nodes
var _ui_root: Control = null
var _chrome: Control = null
var _vignette: Control = null
var _top_bar: MarginContainer = null
var _brand_sub: Label = null
var _ver_pill: PanelContainer = null
var _nav_buttons: Array[Button] = []
var _panel: Control = null            # hero block (name kept for layout tests)
var _spec_card: PanelContainer = null
var _vehicle_counter_label: Label = null
var _vehicle_name_label: Label = null
var _vehicle_model_label: Label = null
var _spec_bars: Dictionary = {}
var _spec_values: Dictionary = {}
var _spec_tweens: Dictionary = {}
var _dock: MarginContainer = null
var _dock_row: BoxContainer = null
var _cta_box: HBoxContainer = null
var _start_btn: Button = null
var _lan_btn: Button = null
var _pager: Control = null
var _pager_grid: GridContainer = null
var _thumb_buttons: Array[Button] = []
var _thumb_group := ButtonGroup.new()
var _hint_row: HBoxContainer = null
var _settings_box: Control = null
var _settings_margin: MarginContainer = null
var _settings_panel: SettingsPanel = null
var _settings_back_btn: Button = null
var _info_panel: Control = null
var _info_card: PanelContainer = null
var _help_device: SettingsPanel.Segmented = null
var _help_list: VBoxContainer = null
var _quit_box: Control = null
var _quit_card: PanelContainer = null
var _modals: UiModalStack = null

# Responsive layout state
var layout_mode: String = "LANDSCAPE"
var _vp_size := Vector2.ZERO
var _last_real_vp_size := Vector2.ZERO
var _orbit_radius: float = 7.2
var _current_orbit_radius: float = 7.2
var _look_y: float = 0.72
var _tour_blend: float = 0.0
var _hero_rect := Rect2()


## Atmospheric framing: soft gradients behind the app bar, the dock and the
## hero card so text keeps its contrast over the bright car (XAG 102).
class StudioVignette extends Control:
	var hero_from_x: float = -1.0
	var portrait_band := Vector2(-1.0, -1.0)

	func _draw() -> void:
		var s := size
		var steps := 14
		var ink := Color(0.027, 0.035, 0.050)
		var top_h := minf(150.0, s.y * 0.24)
		for i in range(steps):
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			draw_rect(Rect2(0.0, t0 * top_h, s.x, (t1 - t0) * top_h + 1.0), Color(ink, pow(1.0 - t0, 1.6) * 0.82))
		var bot_h := minf(260.0, s.y * 0.40)
		var bot_y := s.y - bot_h
		for i in range(steps):
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			draw_rect(Rect2(0.0, bot_y + t0 * bot_h, s.x, (t1 - t0) * bot_h + 1.0), Color(ink, pow(t1, 1.5) * 0.9))
		if hero_from_x >= 0.0:
			var w := s.x - hero_from_x
			for i in range(steps):
				var t0 := float(i) / float(steps)
				var t1 := float(i + 1) / float(steps)
				draw_rect(Rect2(hero_from_x + t0 * w, 0.0, (t1 - t0) * w + 1.0, s.y), Color(ink, pow(t1, 1.4) * 0.66))
		if portrait_band.x >= 0.0:
			for i in range(steps):
				var t0 := float(i) / float(steps)
				var t1 := float(i + 1) / float(steps)
				draw_rect(Rect2(0.0, portrait_band.x + t0 * portrait_band.y, s.x, (t1 - t0) * portrait_band.y + 1.0), Color(ink, sin(t0 * PI) * 0.55))


func _ready() -> void:
	SettingsManager.load_settings()
	SettingsManager.apply_display_and_audio()
	SettingsManager.apply_viewport_graphics(get_viewport())
	_selected_index = SettingsManager.selected_vehicle_index
	_build_showroom_stage()
	_build_ui()
	_show_vehicle(_selected_index, false)
	_apply_layout_if_needed(true)
	_play_menu_intro()
	var am := get_node_or_null("/root/AudioManager")
	if am != null:
		if am.has_method("attach_ui_sounds"):
			am.call("attach_ui_sounds", self)
		if am.has_method("play_menu_music"):
			am.call("play_menu_music")
	if _start_btn != null:
		_start_btn.grab_focus()


# =========================================================================
# 3D ARCHITECTURAL HANGAR SHOWROOM (Assetto Corsa Evo × Porsche Studio)
# =========================================================================
func _build_showroom_stage() -> void:
	# v0.1-b4: the procedural graphite hangar of v0.1-b3 is replaced by the
	# "Car Garage | Desert Garage Environment" diorama (see
	# assets/environment/garage/). The previous hangar is kept behind
	# `--hangar-stage` for comparison captures and as a graceful fallback
	# if the model cannot be loaded.
	if _garage_stage_requested() and (ResourceLoader.exists(GARAGE_SCENE_PATH) or ResourceLoader.exists(GARAGE_SCENE_FALLBACK)):
		_build_garage_stage()
	else:
		_build_procedural_hangar()

	_car_holder = Node3D.new()
	_car_holder.name = "ShowroomCar"
	# The diorama's turntable is a raised platform (its top face sits at
	# ~0.16 m); the car is parked on it, not sunk into it.
	_car_holder.position = Vector3(0.0, _turntable_offset if _garage_loaded else 0.03, 0.0)
	add_child(_car_holder)

	_camera = Camera3D.new()
	_camera.name = "ShowroomCamera"
	_camera.fov = 34.0
	_camera.near = 0.1
	_camera.far = 160.0
	add_child(_camera)
	_camera.make_current()


## The garage stage is the default; `--hangar-stage` (or a missing model)
## falls back to the v0.1-b3 procedural hangar.
func _garage_stage_requested() -> bool:
	return not _has_cli_flag("--hangar-stage")


## Shared, moody environment for both stages (graphite UI family, filmic).
func _make_stage_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.040, 0.048, 0.066)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.52, 0.60, 0.74)
	env.ambient_light_energy = 0.30
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.94
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.035, 0.043, 0.060)
	env.fog_density = 0.010
	return env


# =========================================================================
# v0.1-b4 GARAGE STAGE (desert garage diorama replaces the hangar)
# =========================================================================
## Instantiates the garage diorama, drops the model's own ceiling/roof slabs
## so the orbit camera stays inside the workshop, re-seats the whole stage
## on y = 0 and centres the turntable circle on the car.
func _build_garage_stage() -> void:
	var we := WorldEnvironment.new()
	we.name = "ShowroomEnvironment"
	we.environment = _make_stage_environment()
	add_child(we)

	var src := GARAGE_SCENE_PATH if ResourceLoader.exists(GARAGE_SCENE_PATH) else GARAGE_SCENE_FALLBACK
	var packed := load(src) as PackedScene
	_garage_root = Node3D.new() if packed == null else packed.instantiate() as Node3D
	if _garage_root == null:
		_garage_root = Node3D.new()
	_garage_root.name = GARAGE_ROOT_NAME
	add_child(_garage_root)
	_garage_loaded = packed != null

	# The diorama is authored bottom at y ~ 0 and ~12 m tall; the ceiling and
	# roof slabs would sit right on top of the camera (which orbits at
	# 1-3 m), so they are removed. The interior stays: floor, brick walls,
	# pillars, workbench, door, lockers, sign.
	# Only the horizontal slabs that sit above 6 m and span the whole
	# footprint are removed (roof deck, parapet and its wire trim). Every
	# interior element — brick walls, pillars, bench, door, lockers, sign —
	# stays.
	for mi in _garage_meshes(_garage_root):
		var ab: AABB = mi.global_transform * mi.get_aabb()
		var high := ab.position.y > 6.3
		var slab := high and ab.size.y <= 2.2 and ab.size.x > 12.0 and ab.size.z > 12.0
		var deck := high and ab.size.x >= 14.0 and ab.size.z >= 14.0
		if slab or deck:
			mi.get_parent().remove_child(mi)
			mi.queue_free()

	# Collapse the whole diorama into few draw calls: one mesh per material
	# (49 authored meshes / 16 materials). Keeps the menu cheap on Android.
	_garage_merge_by_material(_garage_root)
	# Grade it into the graphite "Proving Ground" family: the source is a
	# bright daylight diorama, the menu wants a dark studio where the car is
	# the only bright object.
	_grade_garage_materials()

	# Re-seat the stage on y = 0 (the model's floor sits at y ~ -0.03).
	var floor_y := _garage_floor_y()
	if absf(floor_y) > 0.001:
		_garage_root.position.y -= floor_y

	# Key/fill/rim lighting tuned for the diorama's brick + steel palette.
	var key := DirectionalLight3D.new()
	key.name = "ShowroomKeyLight"
	key.rotation_degrees = Vector3(-76.0, -28.0, 0.0)
	key.light_color = Color(1.0, 0.94, 0.86)
	key.light_energy = 0.80
	key.shadow_enabled = true
	key.shadow_bias = 0.04
	key.shadow_enabled = _garage_shadows_requested()
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "ShowroomCoolFill"
	fill.rotation_degrees = Vector3(-22.0, 148.0, 0.0)
	fill.light_color = Color(0.74, 0.86, 1.0)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	add_child(fill)

	# Soft luminous pool over the turntable — the car stays the hero.
	_sweep_light = SpotLight3D.new()
	_sweep_light.name = "ShowroomSweep"
	_sweep_light.position = Vector3(0.0, 5.9, 0.0)
	_sweep_light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_sweep_light.light_color = Color(1.0, 0.95, 0.86)
	_sweep_light.light_energy = 1.35
	_sweep_light.spot_range = 11.0
	_sweep_light.spot_angle = 38.0
	_sweep_light.spot_attenuation = 1.4
	add_child(_sweep_light)

	# Seat the wheels on the diorama's turntable disc: the surface height is
	# measured from the mesh (0.144 m in the delivered model) instead of a
	# magic constant, so a re-export of the model cannot reintroduce a gap.
	var disc_top := _garage_turntable_surface_y()
	if disc_top >= 0.0:
		_turntable_offset = disc_top + GARAGE_COMFORT_M

	# The diorama has no ceiling of its own; a wide dark ceiling plane keeps
	# the daylit sky out of the orbit camera's view from below.
	var lid := MeshInstance3D.new()
	lid.name = "GarageCeiling"
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(17.0, 0.3, 17.0)
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 6.55, 0.0)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.055, 0.062, 0.080)
	lid_mat.roughness = 0.9
	lid.material_override = lid_mat
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lid)

	# Emissive workshop light bars under the ceiling (matches the UI family).
	var bar_tool := SurfaceTool.new()
	bar_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(7.4, 0.06, 0.20)
	for idx in range(3):
		var z_off := -4.2 + float(idx) * 4.2
		bar_tool.append_from(bar_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 6.34, z_off)))
	var bars := MeshInstance3D.new()
	bars.name = "GarageLightBars"
	bars.mesh = bar_tool.commit()
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.78, 0.84, 0.94)
	bar_mat.emission_enabled = true
	bar_mat.emission = Color(0.66, 0.74, 0.90)
	bar_mat.emission_energy_multiplier = 1.15
	bars.material_override = bar_mat
	bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bars)


## Dims and warms the diorama's PBR materials so the desert garage reads as a
## dark studio at night, matching UiTheme's graphite family, and turns its
## fluorescent tubes into real emissive strips.
func _grade_garage_materials() -> void:
	var merged := _garage_root.find_child("GarageMerged", true, false) as MeshInstance3D
	var meshes: Array[MeshInstance3D] = []
	if merged != null:
		meshes.append(merged)
	else:
		meshes = _garage_meshes(_garage_root)
	for mi in meshes:
		var mesh := mi.mesh
		if mesh == null:
			continue
		for sidx in range(mesh.get_surface_count()):
			var mat := mesh.surface_get_material(sidx)
			if mat is BaseMaterial3D:
				_grade_one_material(mat as BaseMaterial3D, mesh.surface_get_name(sidx))


func _grade_one_material(mat: BaseMaterial3D, surface_name: String) -> void:
	var lit := surface_name.to_lower().contains("light")
	if lit:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.96, 0.86)
		mat.emission_energy_multiplier = 2.4
		mat.albedo_color = Color(1.0, 0.98, 0.92)
		return
	# ~0.42 keeps the texture detail while dropping the daylight exposure to a
	# night-workshop level: surfaces stay readable, the car stays brightest.
	mat.albedo_color = Color(
		mat.albedo_color.r * 0.42,
		mat.albedo_color.g * 0.41,
		mat.albedo_color.b * 0.45,
		1.0)
	# Night-workshop surfaces are matte: the source floor is glossy enough to
	# blow out under the overhead pool light.
	mat.metallic = 0.0
	mat.roughness = maxf(mat.roughness, 0.82)


func _garage_shadows_requested() -> bool:
	return not _has_cli_flag("--no-shadows")


## True when the flag is on the command line, either as a normal argument or
## after the `--` user-argument separator (`godot --path . -- --hangar-stage`).
func _has_cli_flag(flag: String) -> bool:
	for a in OS.get_cmdline_args():
		if a == flag:
			return true
	for a in OS.get_cmdline_user_args():
		if a == flag:
			return true
	return false


func _garage_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_garage_meshes(c))
	return out


## Height of the turntable surface the car is displayed on.
## The diorama is merged into one mesh, so per-surface AABBs span the whole
## room; the disc is found from raw vertices instead: the highest surface
## below knee height inside the central 2 m radius (0.144 m in the delivered
## model — the raised wooden rim sits further out at ~0.18 m and is skipped on
## purpose, because parking the wheels on the rim is what made them look sunk
## into the turntable).
## Height of the surface the showroom car is seated on (public for tests).
func get_turntable_height() -> float:
	return _turntable_offset


func _garage_turntable_surface_y() -> float:
	var best := -1.0
	# 2.8 m: the car's own footprint. The optimised (decimated) model keeps the
	# disc's surface triangles but drops the dense inner vertices, so a tighter
	# radius would miss the surface and seat the car on the floor. Any surface
	# that passes through the footprint and sits below knee height is a valid
	# display surface (floor plane = 0, disc = ~0.15).
	var radius := 2.8
	for mi in _garage_meshes(_garage_root):
		var mesh := mi.mesh
		if mesh == null:
			continue
		var xf := mi.global_transform
		for si in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(si)
			if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
				continue
			for v in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var w := xf * v
				if w.y > 0.5 or w.y < 0.02:
					continue
				if Vector2(w.x, w.z).length() > radius:
					continue
				best = maxf(best, w.y)
	return best


## Bottom of the diorama's own floor surface (used to seat the stage on y = 0).
func _garage_floor_y() -> float:
	var best := 0.0
	var found := false
	for mi in _garage_meshes(_garage_root):
		var ab: AABB = mi.global_transform * mi.get_aabb()
		if ab.size.x >= 12.0 and ab.size.z >= 12.0 and (not found or ab.position.y < best):
			best = ab.position.y
			found = true
	return best


## Merges every MeshInstance3D of the diorama into one mesh per material
## (49 authored meshes / 16 materials -> <=16 surfaces), which keeps the menu
## stage cheap on Android. GDScript packed arrays are copy-on-write values, so
## the accumulation happens in plain Arrays and is packed once at the end.
## If anything goes wrong the original nodes are kept untouched.
func _garage_merge_by_material(root: Node3D) -> void:
	var groups: Dictionary = {}
	var sources := _garage_meshes(root)
	for mi in sources:
		var mesh := mi.mesh
		if mesh == null:
			continue
		var xf := mi.global_transform
		var normal_basis := xf.basis.inverse().transposed()
		for sidx in range(mesh.get_surface_count()):
			var mat: Material = mesh.surface_get_material(sidx)
			if mat == null:
				mat = mi.material_override
			var arrays := mesh.surface_get_arrays(sidx)
			if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
				continue
			var key := str(mat.get_instance_id()) if mat != null else "__none"
			if not groups.has(key):
				groups[key] = {"mat": mat, "verts": [], "normals": [], "uvs": [], "uv2s": [], "indices": []}
			var g: Dictionary = groups[key]
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
			var idxs: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base: int = (g["verts"] as Array).size()
			var gv: Array = g["verts"]
			var gn: Array = g["normals"]
			var gu: Array = g["uvs"]
			var gu2: Array = g["uv2s"]
			var gi: Array = g["indices"]
			for i in range(verts.size()):
				gv.append(xf * verts[i])
				var nrm := Vector3.UP
				if normals.size() > i:
					nrm = (normal_basis * normals[i]).normalized()
				gn.append(nrm)
				var uv := Vector2.ZERO
				if uvs.size() > i:
					uv = uvs[i]
				gu.append(uv)
				gu2.append(uv2s[i] if uv2s.size() > i else uv)
			if idxs.size() > 0:
				for i in range(idxs.size()):
					gi.append(base + idxs[i])
			else:
				for i in range(verts.size()):
					gi.append(base + i)
			g["verts"] = gv
			g["normals"] = gn
			g["uvs"] = gu
			g["uv2s"] = gu2
			g["indices"] = gi

	var merged := ArrayMesh.new()
	merged.resource_name = "GarageDioramaMerged"
	for key in groups:
		var g: Dictionary = groups[key]
		var gv: Array = g["verts"]
		if gv.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(gv)
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(g["normals"])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(g["uvs"])
		arr[Mesh.ARRAY_TEX_UV2] = PackedVector2Array(g["uv2s"])
		arr[Mesh.ARRAY_INDEX] = PackedInt32Array(g["indices"])
		var before := merged.get_surface_count()
		merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if g["mat"] != null and merged.get_surface_count() > before:
			merged.surface_set_material(before, g["mat"])
	if merged.get_surface_count() == 0:
		return # keep the authored nodes; never leave the stage empty

	for mi in sources:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	var holder := MeshInstance3D.new()
	holder.name = "GarageMerged"
	holder.mesh = merged
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(holder)


# =========================================================================
# v0.1-b3 PROCEDURAL HANGAR (fallback / comparison stage)
# =========================================================================
func _build_procedural_hangar() -> void:
	var env := _make_stage_environment()
	env.fog_density = 0.017
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 1. Warm overhead studio key light (sculpts bodywork curves)
	var key := DirectionalLight3D.new()
	key.name = "ShowroomKeyLight"
	key.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key.light_color = Color(1.0, 0.97, 0.93)
	key.light_energy = 1.50 # B8 DARK: kept strong — the car stays lit and readable against the dark hangar
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	add_child(key)

	# 2. Cool titanium fill from the opposite flank
	var fill := DirectionalLight3D.new()
	fill.name = "ShowroomCoolFill"
	fill.rotation_degrees = Vector3(-26.0, 145.0, 0.0)
	fill.light_color = Color(0.72, 0.86, 1.0)
	fill.light_energy = 0.42 # B8 DARK: dimmed so the hangar falls off into graphite
	fill.shadow_enabled = false
	add_child(fill)

	# 3. Clean rear silhouette rim light (separates dark/white cars cleanly from hangar wall)
	var rim_l := SpotLight3D.new()
	rim_l.name = "ShowroomRimLeft"
	rim_l.position = Vector3(-5.8, 3.6, -5.6)
	rim_l.look_at_from_position(Vector3(-5.8, 3.6, -5.6), Vector3(0.0, 1.1, 0.0), Vector3.UP)
	rim_l.light_color = Color(0.86, 0.93, 1.0)
	rim_l.light_energy = 0.66
	rim_l.spot_range = 18.0
	rim_l.spot_angle = 32.0
	add_child(rim_l)
	_hangar_nodes.append(rim_l)

	var rim_r := SpotLight3D.new()
	rim_r.name = "ShowroomRimRight"
	rim_r.position = Vector3(5.8, 3.4, -5.4)
	rim_r.light_color = Color(0.82, 0.94, 1.0)
	rim_r.light_energy = 0.60
	rim_r.spot_range = 18.0
	rim_r.spot_angle = 32.0
	add_child(rim_r)
	_hangar_nodes.append(rim_r)

	_sweep_light = SpotLight3D.new()
	_sweep_light.name = "ShowroomSweep"
	_sweep_light.position = Vector3(0.0, 6.2, -3.2)
	_sweep_light.rotation_degrees = Vector3(-58.0, 180.0, 0.0)
	_sweep_light.light_color = Color(0.96, 0.98, 1.0)
	_sweep_light.light_energy = 0.55 # B8 DARK: gentler moving highlight pool on the darker floor
	_sweep_light.spot_range = 22.0
	_sweep_light.spot_angle = 36.0
	add_child(_sweep_light)

	# Architectural hangar ceiling light trusses (5 crisp luminous ribs)
	var light_bar_mat := StandardMaterial3D.new()
	light_bar_mat.albedo_color = Color(0.72, 0.78, 0.88) # B8 DARK: ribs stay, but softer — no stark white bands
	light_bar_mat.emission_enabled = true
	light_bar_mat.emission = Color(0.62, 0.70, 0.85)
	light_bar_mat.emission_energy_multiplier = 0.85
	# B8 UI-SOFTLINE (mobile lightening): the five ceiling ribs share one
	# material, so they are merged into a single MeshInstance3D — one
	# draw call instead of five, same pixels on screen.
	var bar_tool := SurfaceTool.new()
	bar_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(11.5, 0.07, 0.24)
	for idx in range(5):
		var z_off := -7.5 + float(idx) * 3.6
		bar_tool.append_from(bar_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.4, z_off)))
	var light_bars := MeshInstance3D.new()
	light_bars.name = "CeilingLightBars"
	light_bars.mesh = bar_tool.commit()
	light_bars.material_override = light_bar_mat
	light_bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(light_bars)
	_hangar_nodes.append(light_bars)

	# Rear architectural horizon backdrop wall + sleek horizontal racing light stripe
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.040, 0.048, 0.066) # B8 DARK: graphite ~#0A0C11
	wall_mat.roughness = 0.68
	wall_mat.metallic = 0.15
	var back_wall := MeshInstance3D.new()
	var bwm := BoxMesh.new()
	bwm.size = Vector3(44.0, 12.0, 0.4)
	back_wall.mesh = bwm
	back_wall.position = Vector3(0.0, 5.5, -13.5)
	back_wall.material_override = wall_mat
	# B8 UI-SOFTLINE: the rear wall is the backmost surface — its shadow
	# can never land on anything visible. Receive-only from here on.
	back_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(back_wall)
	_hangar_nodes.append(back_wall)

	# Subtle architectural vertical steel pilasters along the rear hangar wall
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.058, 0.070, 0.094) # B8 DARK: graphite ~#0F1218
	pillar_mat.metallic = 0.45
	pillar_mat.roughness = 0.38
	# B8 UI-SOFTLINE: the five pilasters share one material — merged
	# into a single mesh (1 draw + 1 shadow draw instead of 5 + 5).
	# They still cast: their soft shadows on the rear wall stay.
	var pillar_tool := SurfaceTool.new()
	pillar_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.32, 11.5, 0.55)
	for px in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		pillar_tool.append_from(pillar_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(px, 5.4, -13.1)))
	var pilasters := MeshInstance3D.new()
	pilasters.name = "HangarPilasters"
	pilasters.mesh = pillar_tool.commit()
	pilasters.material_override = pillar_mat
	add_child(pilasters)
	_hangar_nodes.append(pilasters)

	# Sleek architectural horizontal LED accent bar high on the rear hangar wall (above car & typography!)
	var horizon_stripe := MeshInstance3D.new()
	var hsm := BoxMesh.new()
	hsm.size = Vector3(26.0, 0.07, 0.08)
	horizon_stripe.mesh = hsm
	horizon_stripe.position = Vector3(0.0, 3.65, -12.9)
	var hsm_mat := StandardMaterial3D.new()
	hsm_mat.albedo_color = Color(0.75, 0.82, 0.92)
	hsm_mat.emission_enabled = true
	hsm_mat.emission = Color(0.55, 0.68, 0.85)
	hsm_mat.emission_energy_multiplier = 0.7 # B8 DARK: dimmer horizon line
	horizon_stripe.material_override = hsm_mat
	# B8 UI-SOFTLINE: thin emissive decals flush with the wall — their
	# cast shadow can never be seen. Receive only.
	horizon_stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(horizon_stripe)
	_hangar_nodes.append(horizon_stripe)

	var red_accent_bar := MeshInstance3D.new()
	var ram := BoxMesh.new()
	ram.size = Vector3(5.6, 0.09, 0.10)
	red_accent_bar.mesh = ram
	red_accent_bar.position = Vector3(-4.2, 3.65, -12.82)
	var ram_mat := StandardMaterial3D.new()
	ram_mat.albedo_color = UiTheme.COLOR_ACCENT_PRIMARY
	ram_mat.emission_enabled = true
	ram_mat.emission = UiTheme.COLOR_ACCENT_PRIMARY
	ram_mat.emission_energy_multiplier = 1.45
	red_accent_bar.material_override = ram_mat
	red_accent_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # B8 UI-SOFTLINE: wall decal, see stripe above
	add_child(red_accent_bar)
	_hangar_nodes.append(red_accent_bar)

	# Satin architectural concrete studio floor (smooth matte sheen — zero harsh specular hotspots!)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "ShowroomFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 120.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.046, 0.055, 0.074) # B8 DARK: graphite ~#0C0E13
	floor_mat.metallic = 0.08
	floor_mat.roughness = 0.58
	floor_mesh.material_override = floor_mat
	# B8 UI-SOFTLINE: the ground plane receives every shadow in the room;
	# casting from it is meaningless (nothing sits below it).
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	_hangar_nodes.append(floor_mesh)

	# Low-profile brushed-titanium motorsport turntable
	var disc := MeshInstance3D.new()
	disc.name = "HighlightDisc"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.55
	cyl.bottom_radius = 3.72
	cyl.height = 0.04
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.position = Vector3(0.0, 0.01, 0.0)
	var disc_mat := StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.086, 0.102, 0.133) # B8 DARK: ~#161A22 — still reads as the lit stage under the car
	disc_mat.metallic = 0.42
	disc_mat.roughness = 0.26
	disc.material_override = disc_mat
	# B8 UI-SOFTLINE: the turntable disc lies flat on the floor; only the
	# car casts a visible shadow onto it. Receive only.
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_hangar_nodes.append(disc)

	# Subtle telemetry floor rings (white primary + faint cyan outer dial)
	for i in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "GridRing%d" % i
		var torus := TorusMesh.new()
		var r := 3.74 if i == 0 else 5.25
		torus.inner_radius = r
		torus.outer_radius = r + (0.040 if i == 0 else 0.022)
		torus.rings = 64
		ring.mesh = torus
		ring.position = Vector3(0.0, 0.02, 0.0)
		var rm := StandardMaterial3D.new()
		var col := Color(0.90, 0.95, 1.0) if i == 0 else UiTheme.COLOR_ACCENT_SECONDARY
		var e := 0.60 if i == 0 else 0.30 # B8 DARK: white dial ring softened (cyan accent ring unchanged)
		rm.albedo_color = Color(col, e * 0.65)
		rm.emission_enabled = true
		rm.emission = col
		rm.emission_energy_multiplier = e
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rm
		# B8 UI-SOFTLINE: flat emissive rings flush with the floor —
		# receive only, like the disc under them.
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_hangar_nodes.append(ring)


## Fraction of the fleet maximum for one spec key.
func _spec_pct(key: String, val: float) -> float:
	var fleet_max := 0.0
	for i in range(VehicleCatalog.get_count()):
		fleet_max = maxf(fleet_max, float(VehicleCatalog.get_entry(i).get(key, 0.0)))
	return clampf(val / maxf(fleet_max, 0.001), 0.0, 1.0)


func _spec_text(key: String, val: float) -> String:
	match key:
		"top_speed_kmh":
			return UiTheme.fa_int(int(round(val))) + " کیلومتر بر ساعت"
		"engine_force_n":
			return UiTheme.fa_int_grouped(int(round(val))) + " نیوتن"
		"mass_kg":
			return UiTheme.fa_int_grouped(int(round(val))) + " کیلوگرم"
	return UiTheme.fa_float(val, 2)


func _show_vehicle(index: int, animate: bool = true) -> void:
	var count := VehicleCatalog.get_count()
	if count <= 0:
		return
	_selected_index = ((index % count) + count) % count
	SettingsManager.set_selected_vehicle(_selected_index)

	if _car_instance != null and is_instance_valid(_car_instance):
		_car_instance.queue_free()
		_car_instance = null

	var entry := VehicleCatalog.get_entry(_selected_index)
	var scene_path := str(entry.get("showcase_scene", entry.get("visual_scene", "")))
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var packed := load(scene_path) as PackedScene
		if packed != null:
			_car_instance = packed.instantiate() as Node3D
			_car_instance.name = "ShowroomVehicle"
			_car_holder.add_child(_car_instance)
			_car_holder.rotation.y = deg_to_rad(32.0)
			var pop_d := UiTheme.motion_sec(300.0) if animate else 0.0
			if pop_d > 0.0:
				_car_holder.scale = Vector3.ONE * 0.94
				create_tween().tween_property(_car_holder, "scale", Vector3.ONE, pop_d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			else:
				_car_holder.scale = Vector3.ONE

	if _vehicle_name_label != null:
		_vehicle_name_label.text = str(entry["name_fa"])
		var fd := UiTheme.fade_sec(220.0) if animate else 0.0
		if fd > 0.0:
			_vehicle_name_label.modulate.a = 0.0
			create_tween().tween_property(_vehicle_name_label, "modulate:a", 1.0, fd)
		else:
			_vehicle_name_label.modulate.a = 1.0
	if _vehicle_model_label != null:
		_vehicle_model_label.text = str(entry["name_en"]).to_upper()
	if _vehicle_counter_label != null:
		_vehicle_counter_label.text = "خودرو %s از %s" % [UiTheme.fa_int(_selected_index + 1), UiTheme.fa_int(count)]

	for sd in SPEC_DEFS:
		var key: String = sd[0]
		var val := float(entry.get(key, 0.0))
		var bar: ProgressBar = _spec_bars.get(key, null)
		if bar != null:
			var old_tw: Variant = _spec_tweens.get(key, null)
			if old_tw is Tween and (old_tw as Tween).is_valid():
				(old_tw as Tween).kill()
			var target := _spec_pct(key, val) * 100.0
			var bd := UiTheme.motion_sec(350.0) if animate else 0.0
			if bd > 0.0:
				var bar_tw := create_tween()
				_spec_tweens[key] = bar_tw
				bar_tw.tween_property(bar, "value", target, bd).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			else:
				bar.value = target
		var lbl: Label = _spec_values.get(key, null)
		if lbl != null:
			lbl.text = _spec_text(key, val)

	for i in range(_thumb_buttons.size()):
		_thumb_buttons[i].set_pressed_no_signal(i == _selected_index)
	_fit_camera_to_car()


## dir = +1 → next car (to the LEFT in the RTL row), -1 → previous.
func _step_car(dir: int) -> void:
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_ui_car_switch"):
		am.call("play_ui_car_switch")
	_show_vehicle(_selected_index + dir)
	_idle_time = 0.0


func compute_layout_mode(aspect: float) -> String:
	if aspect >= 1.25:
		return "LANDSCAPE"
	if aspect >= 0.85:
		return "SQUARE"
	return "PORTRAIT"


func get_layout_mode() -> String:
	return layout_mode


func _apply_layout_if_needed(force: bool = false) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var s := vp.get_visible_rect().size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	if not force and s.is_equal_approx(_last_real_vp_size):
		return
	_last_real_vp_size = s
	apply_layout(s)


## Lays the chrome out for a logical canvas size (already divided by the
## UI scale). Every value is derived from the canvas, nothing is fixed to
## the 1280x720 design size.
func apply_layout(vp_size: Vector2) -> void:
	_vp_size = vp_size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	layout_mode = compute_layout_mode(vp_size.x / vp_size.y)
	if _panel == null or _dock == null or _pager_grid == null:
		return
	var portrait := layout_mode == "PORTRAIT"
	var narrow := vp_size.x < 980.0
	var short := vp_size.y < 600.0
	var inset := 20.0 if vp_size.x >= 900.0 else 14.0
	# Handheld safe area (cutouts / system bars): the chrome is inset, the
	# vignette and the overlay scrims stay full-bleed. Zero on desktop.
	var ins := UiTheme.safe_insets(get_viewport())
	if _chrome != null:
		_chrome.offset_left = ins.x
		_chrome.offset_top = ins.y
		_chrome.offset_right = -ins.z
		_chrome.offset_bottom = -ins.w
	vp_size = Vector2(vp_size.x - ins.x - ins.z, vp_size.y - ins.y - ins.w)

	# App bar: icon-only buttons when narrow; subtitle hides when narrow.
	_top_bar.offset_left = inset
	_top_bar.offset_right = -inset
	_top_bar.offset_top = 12.0
	_top_bar.offset_bottom = 12.0 + UiTheme.TOUCH_MIN
	for b in _nav_buttons:
		var full: String = str(b.get_meta("full_text", ""))
		b.text = "" if narrow else full
		b.tooltip_text = full
		b.custom_minimum_size = Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN)
	if _brand_sub != null:
		_brand_sub.visible = not narrow
	if _ver_pill != null:
		_ver_pill.visible = not portrait and vp_size.x >= 760.0

	# Dock: one row (CTA + selector) or, in portrait, CTA above a 3x2 grid.
	_dock.offset_left = inset
	_dock.offset_right = -inset
	_dock.offset_bottom = -14.0
	_dock_row.vertical = portrait
	_pager_grid.columns = 3 if portrait else 6
	var cta_w := clampf(vp_size.x * 0.20, 220.0, 300.0)
	_start_btn.custom_minimum_size = Vector2(cta_w if not portrait else 0.0, UiTheme.CONTROL_HEIGHT_LG)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_FILL
	_lan_btn.custom_minimum_size = Vector2(UiTheme.CONTROL_HEIGHT_LG if narrow else 0.0, UiTheme.CONTROL_HEIGHT_LG)
	_lan_btn.text = "" if narrow else str(_lan_btn.get_meta("full_text", ""))
	_cta_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL if portrait else Control.SIZE_SHRINK_BEGIN
	var lan_w := UiTheme.CONTROL_HEIGHT_LG if narrow else 190.0
	var pager_w := vp_size.x - inset * 2.0 if portrait else vp_size.x - inset * 2.0 - cta_w - lan_w - 24.0
	var per_card := (pager_w - 8.0 * float(_pager_grid.columns - 1)) / float(_pager_grid.columns)
	# One label format for all six cards (the longest that fits every card):
	# "۰۲  تارا" → "تارا" → "۰۲".
	var f := UiTheme.font_bold()
	var fmt := "short_text"
	for key in ["full_text", "name_text"]:
		var fits := true
		for tb in _thumb_buttons:
			if f != null and f.get_string_size(str(tb.get_meta(key)), HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.TYPE_LABEL).x + 36.0 > per_card:
				fits = false
				break
		if fits:
			fmt = key
			break
	var card_h := UiTheme.TOUCH_MIN if short else UiTheme.CONTROL_HEIGHT_LG - 4.0
	for i in range(_thumb_buttons.size()):
		var tb := _thumb_buttons[i]
		tb.text = str(tb.get_meta(fmt))
		tb.custom_minimum_size = Vector2(0, card_h)
	# Size the selector for its row count now (not one layout pass later),
	# so the dock height below already includes the second row in portrait.
	var rows := int(ceil(float(_thumb_buttons.size()) / float(_pager_grid.columns)))
	_pager.custom_minimum_size = Vector2(0, float(rows) * card_h + float(rows - 1) * UiTheme.SPACE_2)
	var dock_h := _dock.get_combined_minimum_size().y
	_dock.offset_top = -14.0 - dock_h

	# Hero card on the start (right) side; full-width band in portrait.
	var top_y := 12.0 + UiTheme.TOUCH_MIN + (16.0 if short else 28.0)
	var bottom_gap := dock_h + 14.0 + (12.0 if short else 24.0)
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	(_panel as VBoxContainer).alignment = BoxContainer.ALIGNMENT_END if portrait else BoxContainer.ALIGNMENT_BEGIN
	if portrait:
		# Full-width card sitting right above the dock; the car gets the
		# space above it (no empty band between card and dock).
		_panel.anchor_left = 0.0
		_panel.anchor_right = 1.0
		_panel.offset_left = inset
		_panel.offset_right = -inset
		var hero_h := _panel.get_combined_minimum_size().y
		_panel.offset_top = maxf(top_y, vp_size.y - bottom_gap - hero_h)
		_panel.offset_bottom = -bottom_gap
	else:
		var hero_w := clampf(vp_size.x * (0.34 if layout_mode == "LANDSCAPE" else 0.44), 320.0, 470.0)
		_panel.anchor_left = 1.0
		_panel.anchor_right = 1.0
		_panel.offset_left = -inset - hero_w
		_panel.offset_right = -inset
		_panel.offset_top = top_y
		_panel.offset_bottom = -bottom_gap
	_vehicle_name_label.add_theme_font_size_override("font_size", 34 if (short or portrait) else UiTheme.TYPE_DISPLAY)
	# Short canvases (high UI scale): shed secondary hero content in order —
	# the bar note, then the model line, then the counter — until it fits.
	var shed := [_spec_card.find_child("SpecNote", true, false), _vehicle_model_label.get_parent(), _vehicle_counter_label]
	for n in shed:
		(n as Control).visible = true
	if not portrait:
		var avail := (vp_size.y - bottom_gap) - top_y
		for n in shed:
			if _panel.get_combined_minimum_size().y <= avail:
				break
			(n as Control).visible = false
	_hero_rect = Rect2(Vector2(_panel.offset_left + (0.0 if portrait else vp_size.x), _panel.offset_top), Vector2.ZERO)

	if _vignette != null:
		var vg := _vignette as StudioVignette
		vg.hero_from_x = -1.0 if portrait else maxf(0.0, vp_size.x + _panel.offset_left - 120.0)
		vg.portrait_band = Vector2(_panel.offset_top - 60.0, vp_size.y - _panel.offset_top) if portrait else Vector2(-1.0, -1.0)
		vg.queue_redraw()

	_update_settings_overlay_layout()
	_fit_camera_to_car()


## Settings card: centred, at most 720x660, always inside the canvas.
func _update_settings_overlay_layout() -> void:
	if _settings_margin == null:
		return
	var vp := _vp_size
	if vp.x <= 0.0 or vp.y <= 0.0:
		vp = get_viewport().get_visible_rect().size
	var mx := maxf(12.0, (vp.x - 720.0) * 0.5)
	var my := maxf(24.0, (vp.y - 660.0) * 0.5)
	_settings_margin.add_theme_constant_override("margin_left", int(mx))
	_settings_margin.add_theme_constant_override("margin_right", int(mx))
	_settings_margin.add_theme_constant_override("margin_top", int(my))
	_settings_margin.add_theme_constant_override("margin_bottom", int(my))


## Fits the car into the free part of the screen (between app bar, dock and
## hero card) and centres it there with the camera's view offsets.
## (v0.1-b1 used frustum_offset, which a perspective camera ignores.)
func _fit_camera_to_car() -> void:
	if _camera == null:
		return
	var vp_size := _vp_size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720)
	var portrait := layout_mode == "PORTRAIT"
	var top := 12.0 + UiTheme.TOUCH_MIN + 8.0
	var bottom := vp_size.y - (_dock.get_combined_minimum_size().y + 28.0 if _dock != null else 120.0)
	var left := 0.0
	var right := vp_size.x
	if _panel != null:
		if portrait:
			bottom = minf(bottom, _panel.offset_top - 8.0)
		else:
			right = vp_size.x + _panel.offset_left - 16.0
	var free := Rect2(left, top, maxf(right - left, 120.0), maxf(bottom - top, 120.0))
	var v_fov := deg_to_rad(_camera.fov)
	var aspect := vp_size.x / maxf(1.0, vp_size.y)
	var tan_v := tan(v_fov * 0.5)
	var car_w := 4.9
	var car_h := 2.4
	var r_w := car_w / maxf(0.05, 2.0 * tan_v * aspect * (free.size.x / vp_size.x) * 0.70)
	var r_h := car_h / maxf(0.05, 2.0 * tan_v * (free.size.y / vp_size.y) * 0.70)
	_orbit_radius = clampf(maxf(r_w, r_h), 6.0, 24.0)
	_look_y = GARAGE_LOOK_Y if _garage_loaded else 0.72
	var vis_h := 2.0 * _orbit_radius * tan_v
	var vis_w := vis_h * aspect
	var cx := free.get_center().x / vp_size.x - 0.5
	var cy := free.get_center().y / vp_size.y - 0.5
	_camera.h_offset = -cx * vis_w
	_camera.v_offset = cy * vis_h
	_camera.frustum_offset = Vector2.ZERO
	_current_orbit_radius = _orbit_radius
	_update_camera_transform()


func _update_camera_transform() -> void:
	if _camera == null:
		return
	var elev := deg_to_rad(13.5 + 3.5 * sin(_orbit_phase * 0.65) * _tour_blend)
	var az := deg_to_rad(-16.0 + 18.0 * sin(_orbit_phase) * _tour_blend)
	var r := _current_orbit_radius
	var cam_pos := Vector3(sin(az) * cos(elev) * r, 0.85 + sin(elev) * r, cos(az) * cos(elev) * r)
	_camera.look_at_from_position(cam_pos, Vector3(0.0, _look_y, 0.0), Vector3.UP)


# =========================================================================
# UI
# =========================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MenuLayer"
	add_child(layer)
	_ui_root = Control.new()
	_ui_root.name = "MenuRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.theme = UiTheme.get_theme()
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui_root)

	_vignette = StudioVignette.new()
	_vignette.name = "StudioVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_vignette)

	_chrome = Control.new()
	_chrome.name = "MenuChrome"
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_root.add_child(_chrome)
	_modals = UiModalStack.new(_chrome)

	_build_app_bar()
	_build_hero()
	_build_dock()
	_build_settings_overlay()
	_build_help_overlay()
	_build_quit_overlay()


func _build_app_bar() -> void:
	_top_bar = MarginContainer.new()
	_top_bar.name = "ShowroomTopNav"
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(_top_bar)
	var row := HBoxContainer.new()
	row.name = "TopRow"
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", UiTheme.SPACE_3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_bar.add_child(row)

	# Brand lockup (start side): K2 badge + game title + subtitle.
	var brand := HBoxContainer.new()
	brand.name = "Brand"
	brand.layout_direction = Control.LAYOUT_DIRECTION_RTL
	brand.add_theme_constant_override("separation", UiTheme.SPACE_3)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(brand)
	# Brand mark: the K2 monogram from the brand kit (v0.3). It replaces the lettered
	# "K2 //" chip so the app bar, the boot splash and the loading screen all show one
	# piece of artwork. The mark is decorative, so it stays out of the focus order.
	var mark := TextureRect.new()
	mark.name = "BrandMark"
	mark.texture = load("res://assets/ui/brand/k2_mark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(56, 32)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.accessibility_name = "K2"
	brand.add_child(mark)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(titles)
	var game_title := UiTheme.label("کیلومتر ۲", "TitleLabel")
	game_title.add_theme_font_override("font", UiTheme.font_black())
	titles.add_child(game_title)
	_brand_sub = UiTheme.label("نمایشگاه و پیست آزمون خودروهای ایرانی", "CaptionLabel")
	titles.add_child(_brand_sub)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	_ver_pill = PanelContainer.new()
	_ver_pill.name = "VersionPill"
	_ver_pill.theme_type_variation = "ChipPanel"
	_ver_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ver_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ver_pill.add_child(UiTheme.ltr_label(VersionInfo.DISPLAY, "CaptionLabel"))
	row.add_child(_ver_pill)

	var settings_btn := _make_nav_button("تنظیمات", "settings", "MenuSettingsButton")
	settings_btn.pressed.connect(_on_settings_pressed)
	row.add_child(settings_btn)
	var help_btn := _make_nav_button("راهنما", "help", "HelpButton")
	help_btn.pressed.connect(_open_help)
	row.add_child(help_btn)
	var quit_btn := _make_nav_button("خروج", "power", "QuitButton")
	quit_btn.pressed.connect(request_quit)
	row.add_child(quit_btn)


func _make_nav_button(text: String, icon: String, btn_name: String) -> Button:
	var b := UiTheme.make_button(text, btn_name, false, Vector2(UiTheme.TOUCH_MIN, UiTheme.TOUCH_MIN), "icon", icon)
	b.set_meta("full_text", text)
	b.tooltip_text = text
	b.accessibility_name = text
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_nav_buttons.append(b)
	return b


func _build_hero() -> void:
	_panel = VBoxContainer.new()
	_panel.name = "HeroTelemetryBlock"
	_panel.add_theme_constant_override("separation", UiTheme.SPACE_2)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(_panel)

	var text_box := VBoxContainer.new()
	text_box.name = "HeroText"
	text_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	text_box.add_theme_constant_override("separation", 0)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(text_box)
	_vehicle_counter_label = UiTheme.label("", "OverlineLabel")
	_vehicle_counter_label.name = "VehicleCounter"
	text_box.add_child(_vehicle_counter_label)
	_vehicle_name_label = UiTheme.label("", "DisplayLabel")
	_vehicle_name_label.name = "VehicleName"
	_vehicle_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_vehicle_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_vehicle_name_label.clip_text = true
	_vehicle_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_box.add_child(_vehicle_name_label)
	var model_row := HBoxContainer.new()
	model_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	model_row.add_theme_constant_override("separation", UiTheme.SPACE_2)
	model_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(model_row)
	model_row.add_child(UiTheme.label("دیفرانسیل جلو", "CaptionLabel"))
	model_row.add_child(UiTheme.label("·", "CaptionLabel"))
	_vehicle_model_label = UiTheme.ltr_label("", "CaptionLabel")
	_vehicle_model_label.name = "VehicleModel"
	model_row.add_child(_vehicle_model_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UiTheme.SPACE_2)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(gap)

	_spec_card = PanelContainer.new()
	_spec_card.name = "SpecCard"
	_spec_card.theme_type_variation = "GlassPanel"
	_spec_card.add_theme_stylebox_override("panel", UiTheme.glass_style(UiTheme.RADIUS_LG, Vector4(20, 16, 20, 16)))
	_spec_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_spec_card)
	var specs := VBoxContainer.new()
	specs.layout_direction = Control.LAYOUT_DIRECTION_RTL
	specs.add_theme_constant_override("separation", UiTheme.SPACE_3)
	specs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spec_card.add_child(specs)
	for sd in SPEC_DEFS:
		var item := VBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.layout_direction = Control.LAYOUT_DIRECTION_RTL
		row.add_theme_constant_override("separation", UiTheme.SPACE_2)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiIcon.make(sd[2], 20, UiTheme.COLOR_ON_SURFACE_VARIANT))
		var k_lbl := UiTheme.label(sd[1], "BodyMutedLabel")
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k_lbl)
		var v_lbl := UiTheme.label("", "ValueLabel")
		v_lbl.name = "SpecValue_" + str(sd[0])
		row.add_child(v_lbl)
		item.add_child(row)
		var pb := ProgressBar.new()
		pb.name = "SpecBar_" + str(sd[0])
		pb.theme_type_variation = "StatBar"
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 6)
		pb.max_value = 100.0
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(pb)
		specs.add_child(item)
		_spec_bars[sd[0]] = pb
		_spec_values[sd[0]] = v_lbl
	var note := UiTheme.label("طول هر نوار نسبت به بیشترین مقدار در نمایشگاه است.", "CaptionLabel", true)
	note.name = "SpecNote"
	specs.add_child(note)


func _build_dock() -> void:
	_dock = MarginContainer.new()
	_dock.name = "BottomCinemaDock"
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.add_child(_dock)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTheme.SPACE_3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_child(col)

	_hint_row = HBoxContainer.new()
	_hint_row.name = "GamepadHint"
	_hint_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_hint_row.add_theme_constant_override("separation", UiTheme.SPACE_5)
	_hint_row.alignment = BoxContainer.ALIGNMENT_END
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_hint_row)
	_hint_row.add_child(InputPrompts.PromptChip.new("switch_car", "تغییر خودرو", "برای چرخاندن خودرو روی صحنه بکشید"))
	_hint_row.add_child(InputPrompts.PromptChip.new("accept", "شروع رانندگی"))

	_dock_row = BoxContainer.new()
	_dock_row.name = "DockRow"
	_dock_row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_dock_row.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_dock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_dock_row)

	_cta_box = HBoxContainer.new()
	_cta_box.name = "CtaBox"
	_cta_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_cta_box.add_theme_constant_override("separation", UiTheme.SPACE_3)
	_cta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_row.add_child(_cta_box)
	_start_btn = UiTheme.make_button("شروع رانندگی", "StartDriveButton", true, Vector2(260, UiTheme.CONTROL_HEIGHT_LG), "primary", "play")
	_start_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_start_btn.pressed.connect(_on_start_drive)
	_cta_box.add_child(_start_btn)
	_lan_btn = UiTheme.make_button("بازی شبکه‌ای", "LanButton", false, Vector2(0, UiTheme.CONTROL_HEIGHT_LG), "secondary", "lan")
	_lan_btn.set_meta("full_text", "بازی شبکه‌ای")
	_lan_btn.tooltip_text = "بازی شبکه‌ای محلی (LAN) با دو دستگاه"
	_lan_btn.accessibility_name = "بازی شبکه‌ای محلی"
	_lan_btn.pressed.connect(_on_lan_pressed)
	_cta_box.add_child(_lan_btn)

	_pager = Control.new()
	_pager.name = "VehiclePager"
	_pager.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock_row.add_child(_pager)
	_pager_grid = GridContainer.new()
	_pager_grid.name = "VehicleGrid"
	_pager_grid.columns = 6
	_pager_grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_pager_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pager_grid.add_theme_constant_override("h_separation", UiTheme.SPACE_2)
	_pager_grid.add_theme_constant_override("v_separation", UiTheme.SPACE_2)
	_pager_grid.resized.connect(func() -> void: _pager.custom_minimum_size = Vector2(0, _pager_grid.get_combined_minimum_size().y))
	_pager.add_child(_pager_grid)
	for i in range(VehicleCatalog.get_count()):
		var e := VehicleCatalog.get_entry(i)
		var num := UiTheme.fa_digits("%02d" % (i + 1))
		var tb := UiTheme.make_button("%s  %s" % [num, str(e["short_fa"])], "VehicleThumb%d" % i, false, Vector2(0, UiTheme.CONTROL_HEIGHT_LG - 4.0), "chip")
		tb.set_meta("full_text", "%s  %s" % [num, str(e["short_fa"])])
		tb.set_meta("short_text", num)
		tb.set_meta("name_text", str(e["short_fa"]))
		tb.tooltip_text = str(e["name_fa"])
		tb.accessibility_name = "خودرو %s: %s" % [UiTheme.fa_int(i + 1), str(e["name_fa"])]
		tb.button_group = _thumb_group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.clip_text = true
		var idx := i
		tb.pressed.connect(func() -> void:
			if idx != _selected_index:
				_step_car(idx - _selected_index))
		# Selection follows focus for keyboard/gamepad browsing.
		tb.focus_entered.connect(func() -> void:
			if idx != _selected_index and not _modals_open() and InputDeviceManager.current_mode != InputDeviceManager.Mode.TOUCH:
				_step_car(idx - _selected_index))
		_pager_grid.add_child(tb)
		_thumb_buttons.append(tb)
	_pager.custom_minimum_size = Vector2(0, UiTheme.CONTROL_HEIGHT_LG)


func _make_overlay(overlay_name: String) -> Control:
	var o := Control.new()
	o.name = overlay_name
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(o)
	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiTheme.COLOR_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(scrim)
	return o


func _build_settings_overlay() -> void:
	_settings_box = _make_overlay("MenuSettingsOverlay")
	_settings_margin = MarginContainer.new()
	_settings_margin.name = "MenuSettingsMargin"
	_settings_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_box.add_child(_settings_margin)
	var settings_scene := load("res://scenes/ui/settings_panel.tscn") as PackedScene
	if settings_scene != null:
		_settings_panel = settings_scene.instantiate() as SettingsPanel
		_settings_panel.name = "MenuSettingsPanel"
		_settings_margin.add_child(_settings_panel)
		_settings_back_btn = _settings_panel.close_button
		_settings_back_btn.name = "MenuSettingsBackButton"
		_settings_panel.close_requested.connect(_on_settings_back)


func _build_help_overlay() -> void:
	_info_panel = _make_overlay("InfoOverlay")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.add_child(center)
	_info_card = PanelContainer.new()
	_info_card.name = "InfoPanel"
	_info_card.theme_type_variation = "DialogPanel"
	center.add_child(_info_card)
	var box := VBoxContainer.new()
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_info_card.add_child(box)
	box.add_child(UiTheme.make_heading("راهنما", "HeadlineLabel"))
	_help_device = SettingsPanel.Segmented.new()
	_help_device.name = "HelpDeviceTabs"
	for t in ["صفحه‌کلید", "دستهٔ بازی", "لمسی"]:
		_help_device.add_item(t)
	_help_device.item_selected.connect(func(i: int) -> void: _fill_help(i))
	box.add_child(_help_device)
	var scroll := ScrollContainer.new()
	scroll.name = "HelpScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.layout_direction = Control.LAYOUT_DIRECTION_RTL
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UiTheme.SPACE_4)
	scroll.add_child(inner)
	_help_list = VBoxContainer.new()
	_help_list.name = "HelpControls"
	_help_list.add_theme_constant_override("separation", UiTheme.SPACE_2)
	inner.add_child(_help_list)
	inner.add_child(HSeparator.new())
	inner.add_child(UiTheme.make_heading("دربارهٔ بازی و مجوزها", "SectionLabel"))
	var about := VBoxContainer.new()
	about.name = "Credits"
	about.add_theme_constant_override("separation", UiTheme.SPACE_1)
	inner.add_child(about)
	about.add_child(UiTheme.ltr_label(VersionInfo.DISPLAY, "LabelStrong"))
	for line in [
		"ساخته‌شده با موتور Godot ۴٫۷ و Jolt Physics (هر دو با مجوز MIT).",
		"قلم‌ها: استعداد (امین عابدی) و Changa — مجوز SIL Open Font License 1.1.",
		"مدل‌های خودرو را سفارش‌دهندهٔ پروژه فراهم کرده است؛ نام‌ها و نشان‌های تجاری متعلق به صاحبانشان است.",
	]:
		about.add_child(UiTheme.label(line, "CaptionLabel", true))
	# v0.1-b4 — the garage stage model is CC BY-NC 4.0: attribution is a licence
	# requirement, so it lives in the in-game credits, not only in the docs.
	var garage_credit := "محیط گاراژ: «Car Garage | Desert Garage Environment» اثر DevPoly3D (Sketchfab) — مجوز CC BY-NC 4.0."
	about.add_child(UiTheme.label(garage_credit, "CaptionLabel", true))
	var credit_link := UiTheme.ltr_label("sketchfab.com/DevPoly3D", "CaptionLabel")
	about.add_child(credit_link)
	# v0.2-b2-racetrack-obj — the circuit is Ville Seppanen's racetrack.obj (CC BY 3.0) and the
	# desert terrain is josevega's (CC BY 4.0). Both licences require the credit to be visible
	# in the application, not only in the docs.
	var track_credit := "پیست: مدل مسابقه اثر Ville Seppanen — مجوز CC BY 3.0."
	about.add_child(UiTheme.label(track_credit, "CaptionLabel", true))
	about.add_child(UiTheme.ltr_label("Ville Seppanen — creativecommons.org/licenses/by/3.0", "CaptionLabel"))
	var terrain_credit := "زمین بیابان: «FREE - Dry Sand Terrain» اثر josevega (Sketchfab) — مجوز CC BY 4.0."
	about.add_child(UiTheme.label(terrain_credit, "CaptionLabel", true))
	about.add_child(UiTheme.ltr_label("sketchfab.com/josevega", "CaptionLabel"))
	var close_info := UiTheme.make_button("بستن", "CloseInfoButton", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary", "close")
	close_info.pressed.connect(_close_help)
	box.add_child(close_info)


## Rebuilds the controls list for one device tab (0 kb, 1 pad, 2 touch).
func _fill_help(device_tab: int) -> void:
	if _help_list == null:
		return
	for c in _help_list.get_children():
		_help_list.remove_child(c)
		c.queue_free()
	if device_tab == 2:
		for row_def in [
			["throttle", "پدال سبز (راست): گاز"],
			["brake", "پدال قرمز: ترمز؛ در حالت توقف نگه دارید تا دنده عقب بگیرد"],
			["handbrake", "نوار کهربایی: ترمز دستی"],
			["wheel", "فرمان سمت چپ: دکمه‌ها، غربیلک یا نوار — از «تنظیمات › کنترل‌ها»"],
			["tools", "دکمهٔ ابزار: چراغ، بازنشانی خودرو، حالت عکس، بازپخش و تنظیم سریع"],
			["pause", "دکمهٔ توقف: منوی توقف و تنظیمات"],
		]:
			var r := HBoxContainer.new()
			r.layout_direction = Control.LAYOUT_DIRECTION_RTL
			r.add_theme_constant_override("separation", UiTheme.SPACE_3)
			r.add_child(UiIcon.make(row_def[0], 22, UiTheme.COLOR_ON_SURFACE_VARIANT))
			var l := UiTheme.label(row_def[1], "BodyLabel", true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			_help_list.add_child(r)
		return
	var dev := InputPrompts.Device.KEYBOARD if device_tab == 0 else InputPrompts.Device.GAMEPAD
	for row_def in [
		["throttle", "گاز"],
		["brake_reverse", "ترمز / دنده عقب (در حالت توقف)"],
		["steer", "فرمان"],
		["handbrake", "ترمز دستی"],
		["toggle_headlights", "چراغ‌ها"],
		["reset_vehicle", "بازنشانی خودرو روی پیست"],
		["camera_reset", "مرکز کردن دوربین"],
		["photo_mode", "حالت عکس"],
		["pause_game", "توقف بازی"],
		["page", "زبانهٔ قبلی / بعدی در تنظیمات"],
	]:
		var gl := InputPrompts.glyphs(row_def[0], dev)
		var r := HBoxContainer.new()
		r.layout_direction = Control.LAYOUT_DIRECTION_RTL
		r.add_theme_constant_override("separation", UiTheme.SPACE_3)
		var l := UiTheme.label(row_def[1], "BodyLabel")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(l)
		if gl.is_empty():
			r.add_child(UiTheme.label("از منوی توقف", "CaptionLabel"))
		var keys := HBoxContainer.new()
		keys.layout_direction = Control.LAYOUT_DIRECTION_LTR
		keys.add_theme_constant_override("separation", 4)
		for g in gl:
			keys.add_child(InputPrompts.Glyph.new(str(g), dev))
		r.add_child(keys)
		_help_list.add_child(r)


func _build_quit_overlay() -> void:
	_quit_box = _make_overlay("QuitConfirmOverlay")
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quit_box.add_child(center)
	_quit_card = PanelContainer.new()
	_quit_card.name = "QuitDialog"
	_quit_card.theme_type_variation = "DialogPanel"
	center.add_child(_quit_card)
	var v := VBoxContainer.new()
	v.layout_direction = Control.LAYOUT_DIRECTION_RTL
	v.add_theme_constant_override("separation", UiTheme.SPACE_4)
	_quit_card.add_child(v)
	v.add_child(UiTheme.label("از بازی خارج می‌شوید؟", "TitleLabel"))
	var body := UiTheme.label("خودروی انتخاب‌شده و تنظیمات شما ذخیره شده‌اند.", "BodyMutedLabel", true)
	body.custom_minimum_size = Vector2(300, 0)
	v.add_child(body)
	var actions := HBoxContainer.new()
	actions.layout_direction = Control.LAYOUT_DIRECTION_RTL
	actions.add_theme_constant_override("separation", UiTheme.SPACE_3)
	v.add_child(actions)
	var cancel := UiTheme.make_button("ماندن در بازی", "QuitCancelButton", false, Vector2(0, UiTheme.TOUCH_MIN), "secondary")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void: _modals.close(_quit_box))
	actions.add_child(cancel)
	var ok := UiTheme.make_button("خروج از بازی", "QuitConfirmButton", false, Vector2(0, UiTheme.TOUCH_MIN), "danger", "power")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func() -> void: get_tree().quit())
	actions.add_child(ok)


func _modals_open() -> bool:
	return _modals != null and not _modals.is_empty()


## Short open animation for an overlay: scrim fade + card rise. Ends at
## exactly modulate 1 / offset 0; instant under reduced motion.
func _animate_overlay_open(overlay: Control, card: Control) -> void:
	if overlay == null:
		return
	var d := UiTheme.fade_sec(UiTheme.MOTION_FAST_MS + 60.0)
	if d <= 0.0:
		overlay.modulate.a = 1.0
		return
	overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, d)
	if card != null and UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS) > 0.0:
		card.offset_transform_enabled = true
		card.offset_transform_position = Vector2(0, 18)
		UiTheme.ease_enter(tw.tween_property(card, "offset_transform_position", Vector2.ZERO, UiTheme.motion_sec(UiTheme.MOTION_MEDIUM_MS)))


func _on_settings_pressed() -> void:
	if _settings_panel != null:
		_settings_panel.refresh_from_settings()
	_update_settings_overlay_layout()
	_modals.push(_settings_box, _settings_panel.default_focus() if _settings_panel != null else null, func() -> void:
		if _settings_panel == null or not _settings_panel.handle_cancel():
			_on_settings_back())
	_animate_overlay_open(_settings_box, _settings_panel)


func _on_settings_back() -> void:
	if _settings_panel != null:
		_settings_panel.flush_pending()
	_modals.close(_settings_box)


func _open_help() -> void:
	var dev_tab := 0
	match InputPrompts.current_device():
		InputPrompts.Device.GAMEPAD:
			dev_tab = 1
		InputPrompts.Device.TOUCH:
			dev_tab = 2
	_help_device.select(dev_tab)
	_fill_help(dev_tab)
	var vp := get_viewport().get_visible_rect().size
	_info_card.custom_minimum_size = Vector2(minf(620.0, vp.x - 32.0), minf(560.0, vp.y - 40.0))
	_modals.push(_info_panel, _help_device.get_button(dev_tab))
	_animate_overlay_open(_info_panel, _info_card)


func _close_help() -> void:
	_modals.close(_info_panel)


## Opens the quit confirmation (focus on the safe choice).
func request_quit() -> void:
	_modals.push(_quit_box, _quit_box.find_child("QuitCancelButton", true, false) as Control)
	_animate_overlay_open(_quit_box, _quit_card)


## Legacy entry point kept for older callers (shows the help dialog).
func _show_info(_msg: String = "") -> void:
	_open_help()


## One-shot entrance: app bar drops in, hero fades in from the start side,
## dock rises. ≤ 380 ms; every property ends at its exact layout value.
func _play_menu_intro() -> void:
	var dur := UiTheme.motion_sec(UiTheme.MOTION_SLOW_MS)
	if dur <= 0.0:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for pair in [[_top_bar, Vector2(0, -24), 0.0], [_panel, Vector2(28, 0), 0.05], [_dock, Vector2(0, 24), 0.10]]:
		var c := pair[0] as Control
		if c == null:
			continue
		c.offset_transform_enabled = true
		c.offset_transform_position = pair[1]
		c.modulate.a = 0.0
		UiTheme.ease_enter(tw.tween_property(c, "offset_transform_position", Vector2.ZERO, dur).set_delay(pair[2]))
		tw.tween_property(c, "modulate:a", 1.0, dur * 0.85).set_delay(pair[2])


func _on_lan_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	SettingsManager.set_selected_vehicle(_selected_index)
	SettingsManager.save_settings()
	SceneTransitionLayer.go(get_tree(), LAN_LOBBY_SCENE_PATH, "در حال آماده‌سازی بازی شبکه‌ای…")


func _on_start_drive() -> void:
	if _leaving:
		return
	_leaving = true
	var am := get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_ui_start_drive"):
		am.call("play_ui_start_drive")
	SettingsManager.set_selected_vehicle(_selected_index)
	SettingsManager.save_settings()
	if _start_btn != null:
		_start_btn.disabled = true
	var car_name := str(VehicleCatalog.get_entry(_selected_index)["name_fa"])
	SceneTransitionLayer.go(get_tree(), DRIVING_SCENE_PATH, "در حال آماده‌سازی پیست — %s" % car_name)


## ← / → from the CTA browse cars without leaving it (RTL: ← = next car,
## which sits to the left in the selector).
func _input(event: InputEvent) -> void:
	if _modals_open() or _leaving:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == _start_btn and focus != null:
		if event.is_action_pressed("ui_left"):
			_step_car(1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_step_car(-1)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _modals_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_back"):
			_modals.handle_cancel()
			get_viewport().set_input_as_handled()
		return
	if _leaving:
		return
	if event.is_action_pressed("ui_page_left"):
		_step_car(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_page_right"):
		_step_car(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		request_quit()
		get_viewport().set_input_as_handled()
		return
	# Turntable drag (mouse, and touch through emulate_mouse_from_touch).
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_car = mb.pressed
	elif event is InputEventMouseMotion and _dragging_car:
		var mm := event as InputEventMouseMotion
		if _car_holder != null:
			_car_holder.rotate_y(mm.relative.x * 0.008)
			_idle_time = 0.0
	if event.is_action_pressed("ui_left"):
		_step_car(1)
	elif event.is_action_pressed("ui_right"):
		_step_car(-1)
	elif event.is_action_pressed("ui_accept"):
		_on_start_drive()


func _process(delta: float) -> void:
	_apply_layout_if_needed(false)
	_idle_time += delta
	var still := SettingsManager.reduce_motion
	if _car_holder != null and not _dragging_car and not still:
		_car_holder.rotate_y(delta * 0.24)
	_tour_blend = lerpf(_tour_blend, 1.0 if (_idle_time > 3.5 and not still) else 0.0, clampf(delta * 1.4, 0.0, 1.0))
	if _tour_blend > 0.01:
		_orbit_phase += delta * 0.30
	_update_camera_transform()
	if _sweep_light != null and not still:
		_sweep_light.position.x = sin(_idle_time * 0.45) * 3.8
